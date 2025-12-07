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
    -- проверка: резиденция существует
    PERFORM 1 FROM residence_details rd WHERE rd.id = p_residence_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Residence id % does not exist', p_residence_id USING ERRCODE = 'P0001';
    END IF;

    -- проверка прав: пользователь должен быть владельцем резиденции (residence_details.user_id)
    SELECT user_id INTO v_residence_owner FROM residence_details WHERE id = p_residence_id;
    IF v_residence_owner IS DISTINCT FROM p_creator_user_id THEN
        RAISE EXCEPTION 'User % is not owner of residence %', p_creator_user_id, p_residence_id USING ERRCODE = 'P0002';
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
