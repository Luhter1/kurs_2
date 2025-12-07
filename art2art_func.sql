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

----------------------------------------------------------------------
-- художник подтверждает участие после approved
-- пайплайн заявки: 
--      1) Отправлена на рассмотрение 
--      2) Рассмотрена 
--      3) Одобрена 
--      4) В резерве
--      5) Отклонена
--      6) Подтверждена художником
--      7) Отклонена художником
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION confirm_participation(
    p_application_id BIGINT,
    p_artist_user_id BIGINT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_app RECORD;
BEGIN
    SELECT * INTO v_app FROM application_requests WHERE id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % not found', p_application_id;
    END IF;

    IF v_app.artist_id <> p_artist_user_id THEN
        RAISE EXCEPTION 'Artist % is not owner of application %', p_artist_user_id, p_application_id;
    END IF;

    IF v_app.status <> 'approved' THEN
        RAISE EXCEPTION 'Application must have status = approved to confirm; current = %', v_app.status;
    END IF;

    UPDATE application_requests
    SET status = 'confirmed',
        updated_at = now()
    WHERE id = p_application_id;

    -- уведомить админа резиденции
    PERFORM create_notification(
        (SELECT rd.user_id FROM residence_details rd JOIN programs p ON p.residence_id = rd.id WHERE p.id = v_app.program_id LIMIT 1),
        format('Artist %s confirmed participation for application %s', p_artist_user_id, p_application_id),
        'status',
        NULL
    );
END;
$$;

----------------------------------------------------------------------
-- 5) DECLINE PARTICIPATION (художник отклоняет приглашение)
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION decline_participation(
    p_application_id BIGINT,
    p_artist_user_id BIGINT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_app RECORD;
BEGIN
    SELECT * INTO v_app FROM application_requests WHERE id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % not found', p_application_id;
    END IF;

    IF v_app.artist_id <> p_artist_user_id THEN
        RAISE EXCEPTION 'Artist % is not owner of application %', p_artist_user_id, p_application_id;
    END IF;

    IF v_app.status <> 'approved' THEN
        RAISE EXCEPTION 'Only approved applications can be declined by artist; current status = %', v_app.status;
    END IF;

    UPDATE application_requests
    SET status = 'declined_by_artist',
        updated_at = now()
    WHERE id = p_application_id;

    -- уведомить админа резиденции
    PERFORM create_notification(
        (SELECT rd.user_id FROM residence_details rd JOIN programs p ON p.residence_id = rd.id WHERE p.id = v_app.program_id LIMIT 1),
        format('Artist %s declined participation for application %s', p_artist_user_id, p_application_id),
        'status',
        NULL
    );

END;
$$;

----------------------------------------------------------------------
-- назначение эксперта на программу (админом или суперадмином)
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION assign_expert_to_program(
    p_program_id BIGINT,
    p_expert_user_id BIGINT,
    p_assigner_user_id BIGINT
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_program RECORD;
    v_existing BIGINT;
    v_owner BIGINT;
    v_id BIGINT;
BEGIN
    SELECT * INTO v_program FROM programs WHERE id = p_program_id FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Program % not found', p_program_id;
    END IF;

    -- проверка роли
    PERFORM 1 FROM users WHERE id = p_expert_user_id AND role = 'ROLE_EXPERT';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % is not an expert', p_expert_user_id;
    END IF;

    -- проверка прав назначающего
    SELECT rd.user_id INTO v_owner FROM residence_details rd WHERE rd.id = v_program.residence_id;
    IF p_assigner_user_id <> v_owner THEN
        PERFORM 1 FROM users WHERE id = p_assigner_user_id AND role = 'ROLE_SUPERADMIN';
        IF NOT FOUND THEN
            RAISE EXCEPTION 'User % not authorized to assign expert to program %', p_assigner_user_id;
        END IF;
    END IF;

    -- проверка уникальности для читаемой ошибки
    SELECT id INTO v_existing FROM program_experts WHERE program_id = p_program_id AND user_id = p_expert_user_id;
    IF FOUND THEN
        RAISE EXCEPTION 'Expert % already assigned to program % (application id=%)', p_expert_user_id, p_program_id, v_existing;
    END IF;

    -- вставка, с проверкой уникальности
    INSERT INTO program_experts (program_id, user_id, assigned_at, created_at)
    VALUES (p_program_id, p_expert_user_id, now(), now())
    RETURNING id INTO v_id;


    -- уведомление эксперта
    PERFORM create_notification(p_expert_user_id,
        format('You have been assigned as expert to program %s', p_program_id),
        'invite',
        NULL
    );

    RETURN v_id;
END;
$$;

----------------------------------------------------------------------
-- эксперт отказывается от программы
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION unassign_expert(
    p_program_id BIGINT,
    p_expert_user_id BIGINT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner BIGINT;
    v_eval_count INT;
BEGIN
    -- проверить, есть ли у эксперта оценки для этой программы
    SELECT count(*) INTO v_eval_count
    FROM application_evaluations ae
    JOIN application_requests ar ON ar.id = ae.application_id
    WHERE ae.expert_id = p_expert_user_id AND ar.program_id = p_program_id;

    IF v_eval_count > 0 THEN
        RAISE EXCEPTION 'Cannot unassign expert % from program %: expert already has % evaluation(s)', p_expert_user_id, p_program_id, v_eval_count;
    END IF;

    DELETE FROM program_experts WHERE program_id = p_program_id AND user_id = p_expert_user_id;
    PERFORM create_notification(p_expert_user_id, format('You have been unassigned from program %s', p_program_id), 'system', NULL);
END;
$$;

----------------------------------------------------------------------
-- оценка заявки художника экспертом
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION add_evaluation(
    p_application_id BIGINT,
    p_expert_user_id BIGINT,
    p_score INT,
    p_comment TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_app RECORD;
    v_assigned BOOLEAN;
    v_eval_id BIGINT;
    v_remaining INT;
BEGIN
    -- проверка существования заявки
    SELECT * INTO v_app FROM application_requests WHERE id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % not found', p_application_id;
    END IF;

    -- проверка, что эксперт назначен на программу
    SELECT EXISTS (
        SELECT 1 FROM program_experts pe WHERE pe.program_id = v_app.program_id AND pe.user_id = p_expert_user_id
    ) INTO v_assigned;
    IF NOT v_assigned THEN
        RAISE EXCEPTION 'Expert % is not assigned to program %', p_expert_user_id, v_app.program_id;
    END IF;

    -- проверка, что эксперт ещё не оценивал заявку
    SELECT id INTO v_eval_id FROM application_evaluations WHERE application_id = p_application_id AND expert_id = p_expert_user_id;
    IF FOUND THEN
        RAISE EXCEPTION 'Expert % already evaluated application % (evaluation id %)', p_expert_user_id, p_application_id, v_eval_id;
    END IF;

    -- вставка оценки
    INSERT INTO application_evaluations (application_id, expert_id, score, comment, created_at)
    VALUES (p_application_id, p_expert_user_id, p_score, p_comment, now())
    RETURNING id INTO v_eval_id;

    -- проверить, все ли эксперты оценили (и если да — поменять статус заявки на 'reviewed')
    SELECT count(*) INTO v_remaining
    FROM program_experts pe
    WHERE pe.program_id = v_app.program_id
      AND NOT EXISTS (
          SELECT 1 FROM application_evaluations ae WHERE ae.application_id = p_application_id AND ae.expert_id = pe.user_id
      );

    IF v_remaining = 0 THEN
        UPDATE application_requests SET status = 'reviewed', updated_at = now() WHERE id = p_application_id;
        -- уведомить администратора
        PERFORM create_notification(
            (SELECT rd.user_id FROM residence_details rd JOIN programs p ON p.residence_id = rd.id WHERE p.id = v_app.program_id LIMIT 1),
            format('Application %s has been fully reviewed', p_application_id),
            'status',
            NULL
        );
    END IF;

    -- уведомить художника
    PERFORM create_notification(v_app.artist_id,
        format('Your application %s received a new evaluation by expert %s', p_application_id, p_expert_user_id),
        'review',
        NULL
    );

    RETURN v_eval_id;
END;
$$;

----------------------------------------------------------------------
-- подсчет среднего былла
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_application_rating(
    p_application_id BIGINT
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg NUMERIC;
BEGIN
    SELECT avg(score::numeric) INTO v_avg FROM application_evaluations WHERE application_id = p_application_id;
    IF v_avg IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN round(v_avg::numeric, 2);
END;
$$;
