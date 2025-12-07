----------------------------------------------------------------------
-- Создаем уведомление
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id BIGINT,
    p_message TEXT,
    p_category VARCHAR,
    p_link TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO notifications (user_id, message, category, link, created_at)
    VALUES (p_user_id, p_message, p_category, p_link, now())
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

----------------------------------------------------------------------
-- помечаем уведомление как прочитанное
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_notification_read(
    p_notification_id BIGINT,
    p_user_id BIGINT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_row notifications%ROWTYPE;
BEGIN
    SELECT * INTO v_row FROM notifications WHERE id = p_notification_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification % not found', p_notification_id;
    END IF;
    IF v_row.user_id <> p_user_id THEN
        RAISE EXCEPTION 'User % not owner of notification %', p_user_id, p_notification_id;
    END IF;
    UPDATE notifications SET read_at = now() WHERE id = p_notification_id;
END;
$$;

----------------------------------------------------------------------
-- вставка в program_views_log (триггер увеличит счетчик)
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_program_view(p_program_id BIGINT, p_user_id BIGINT DEFAULT NULL) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO program_views_log (program_id, viewed_at) VALUES (p_program_id, now());
END;
$$;

----------------------------------------------------------------------
-- вставка в residence_views_log (триггер увеличит счетчик)
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_residence_view(p_residence_id BIGINT, p_user_id BIGINT DEFAULT NULL) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO residence_views_log (residence_id, viewed_at) VALUES (p_residence_id, now());
END;
$$;

----------------------------------------------------------------------
-- создаёт запись в programs и program_stats
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_program(
    p_residence_id BIGINT,
    p_title TEXT,
    p_description TEXT,
    p_goals JSONB,
    p_deadline_apply DATE,
    p_deadline_review DATE,
    p_deadline_notify DATE,
    p_duration_days INT,
    p_budget_quota INT,
    p_people_quota INT,
    p_creator_user_id BIGINT
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_residence_owner BIGINT;
    v_program_id BIGINT;
BEGIN
    -- проверка, что резиденция существует
    PERFORM 1 FROM residence_details rd WHERE rd.id = p_residence_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Residence id % does not exist', p_residence_id;
    END IF;

    -- проверка, что пользователь владелей резиденции
    SELECT user_id INTO v_residence_owner FROM residence_details WHERE id = p_residence_id;
    IF v_residence_owner IS DISTINCT FROM p_creator_user_id THEN
        RAISE EXCEPTION 'User % is not owner of residence %', p_creator_user_id, p_residence_id;
    END IF;

    -- базовые валидации дедлайнов
    IF p_deadline_apply IS NULL OR p_deadline_review IS NULL OR p_deadline_notify IS NULL THEN
        RAISE EXCEPTION 'Deadlines must be provided';
    END IF;
    IF p_deadline_apply > p_deadline_review THEN
        RAISE EXCEPTION 'deadline_apply must be <= deadline_review';
    END IF;
    IF p_deadline_review > p_deadline_notify THEN
        RAISE EXCEPTION 'deadline_review must be <= deadline_notify';
    END IF;

    -- вставляем программу
    INSERT INTO programs (
        residence_id, title, description, goals,
        deadline_apply, deadline_review, deadline_notify,
        duration_days, budget_quota, people_quota,
        created_at, updated_at
    )
    VALUES (
        p_residence_id, p_title, p_description, p_goals,
        p_deadline_apply, p_deadline_review, p_deadline_notify,
        p_duration_days, p_budget_quota, p_people_quota,
        now(), now()
    )
    RETURNING id INTO v_program_id;

    -- создаём строку статистики (если ещё нет)
    INSERT INTO program_stats (program_id, views_count, applications_count, created_at, updated_at)
    VALUES (v_program_id, 0, 0, now(), now())
    ON CONFLICT (program_id) DO NOTHING;

    RETURN v_program_id;
END;
$$;

----------------------------------------------------------------------
-- подача заявки художником
----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION submit_application(
    p_artist_user_id BIGINT,
    p_program_id BIGINT,
    p_motivation TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_program RECORD;
    v_existing BIGINT;
    v_application_id BIGINT;
BEGIN
    -- проверка, что программа существует и дедлайн не прошёл
    SELECT * INTO v_program FROM programs WHERE id = p_program_id FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Program % not found', p_program_id;
    END IF;

    IF now()::date > v_program.deadline_apply THEN
        RAISE EXCEPTION 'Application deadline % has passed', v_program.deadline_apply;
    END IF;

    -- проверка роли художника
    PERFORM 1 FROM users WHERE id = p_artist_user_id AND role = 'ROLE_ARTIST';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % is not an artist', p_artist_user_id;
    END IF;

    -- проверка уникальности для читаемой ошибки
    SELECT id INTO v_existing FROM application_requests WHERE artist_id = p_artist_user_id AND program_id = p_program_id;
    IF FOUND THEN
        RAISE EXCEPTION 'Artist % already applied to program % (application id=%)', p_artist_user_id, p_program_id, v_existing;
    END IF;

    -- вставляем заявку
    INSERT INTO application_requests (program_id, artist_id, status, submitted_at, created_at)
    VALUES (p_program_id, p_artist_user_id, p_motivation, 'sent', now(), now())
    RETURNING id INTO v_application_id;

    -- уведомляем админа резиденции (на уровне бизнес логики будет использоваться ws для показания того, что появилось новое сообщение)
    PERFORM create_notification(
        (SELECT rd.user_id FROM residence_details rd JOIN programs p ON p.residence_id = rd.id WHERE p.id = p_program_id LIMIT 1),
        format('New application %s from artist %s', v_application_id, p_artist_user_id),
        'review',
        NULL
    );

    RETURN v_application_id;
END;
$$;