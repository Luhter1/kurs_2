
-- enums
CREATE TYPE art_direction_enum AS ENUM (
    'painting',
    'sculpture',
    'performance',
    'multimedia',
    'digital_art',
    'photo',
    'other'
);

-- таблица пользователей
CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    name            TEXT NOT NULL,
    surname         TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
      role            VARCHAR(50) NOT NULL CHECK (role IN ('ROLE_ARTIST', 'ROLE_EXPERT', 'ROLE_RESIDENCE_ADMIN', 'ROLE_SUPERADMIN')),
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

-- таблица профиля художника
CREATE TABLE artist_details (
    id          BIGSERIAL PRIMARY KEY,
    -- профиль художника - расширение записи пользователя. Если пользователь удаляется, то и данные профиля
    user_id     BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location    VARCHAR(255),
    created_at  TIMESTAMP DEFAULT now(),
    updated_at  TIMESTAMP DEFAULT now()
);

-- таблица резиденций
CREATE TABLE residence_details (
    id              BIGSERIAL PRIMARY KEY,
    -- удаление администратора резиденции не должно автоматически удалять саму резиденцию
    user_id         BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    location        VARCHAR(255),
    is_published    BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

-- таблица заявок на валидацию резиденции
CREATE TABLE validation_requests (
    id               BIGSERIAL PRIMARY KEY,
    -- если удаляют резиденцию, то все её заявки на валидацию теряют смысл
    residence_id     BIGINT NOT NULL REFERENCES residence_details(id) ON DELETE CASCADE,
    status           VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    comment          TEXT,
    submitted_at     TIMESTAMP,
    processed_at     TIMESTAMP,
    updated_at       TIMESTAMP,
    created_at       TIMESTAMP DEFAULT now()
);

-- таблица программ
CREATE TABLE programs (
    id                          BIGSERIAL PRIMARY KEY,
    -- программа не может существовать без резиденции
    residence_id                BIGINT NOT NULL REFERENCES residence_details(id) ON DELETE CASCADE,
    title                       VARCHAR(255) NOT NULL,
    description                 TEXT,
    goals                       TEXT,
    deadline_apply              DATE NOT NULL,
    deadline_review             DATE NOT NULL,
    deadline_notify             DATE NOT NULL,
    duration_days               INT CHECK (duration_days >= 0),
    budget_quota                INT CHECK (budget_quota >= 0),
    people_quota                INT CHECK (people_quota >= 0),
    futher_actions_sent_at      TIMESTAMP,
    created_at                  TIMESTAMP DEFAULT now(),
    updated_at                  TIMESTAMP DEFAULT now()
);

-- таблица назначения экспертов
CREATE TABLE program_experts (
    id                              BIGSERIAL PRIMARY KEY,
    -- если программа удалена, то все назначения экспертов должны быть удалены.
    program_id                      BIGINT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    -- нельзя удалять эксперта, если он назначен на действующие программы
    user_id                         BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_at                     TIMESTAMP DEFAULT now(),
    created_at                      TIMESTAMP DEFAULT now(),
    -- требование, чтобы эксперт мог быть назначен на программу только 1 раз
    UNIQUE(program_id, user_id)
);

-- таблица заявок художников
CREATE TABLE application_requests (
    id               BIGSERIAL PRIMARY KEY,
    -- без программы заявки не имеют смысла
    program_id       BIGINT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    -- если художник участвовал в программе, его нельзя удалять
    artist_id        BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status           VARCHAR(50) NOT NULL CHECK (status IN (
                        'sent', 'reviewed', 'approved', 'reserve',
                        'rejected', 'confirmed', 'declined_by_artist')),
    submitted_at     TIMESTAMP DEFAULT now(),
    created_at       TIMESTAMP DEFAULT now(),
    -- требование, чтобы художник мог подать заявку только 1 раз
    UNIQUE(artist_id, program_id)
);

-- таблица оценок заявок ходожников экспертами
CREATE TABLE application_evaluations (
    id              BIGSERIAL PRIMARY KEY,
    -- оценка без заявки бессмыслена
    application_id  BIGINT NOT NULL REFERENCES application_requests(id) ON DELETE CASCADE,
    -- эксперт удалит аккаунт, оценки не должны исчезнуть
    expert_id       BIGINT NOT NULL REFERENCES program_experts(id) ON DELETE RESTRICT,
    score           INT CHECK (score >= 0 AND score <= 10),
    comment         TEXT,
    created_at      TIMESTAMP DEFAULT now(),
    -- требование, чтобы эксперт мог оценить заявку только 1 раз
    UNIQUE(application_id, expert_id)
);

-- таблица портфолио художников
CREATE TABLE portfolio_works (
    id               BIGSERIAL PRIMARY KEY,
    -- работы из портфолио бессмыслены без художника
    artist_id        BIGINT NOT NULL REFERENCES artist_details(id) ON DELETE CASCADE,
    title            VARCHAR(255) NOT NULL,
    description      TEXT,
    link             TEXT,
    art_direction    art_direction_enum NOT NULL,
    date             DATE CHECK (date > '1950-01-01' AND date <= now()),
    created_at       TIMESTAMP DEFAULT now(),
    updated_at       TIMESTAMP DEFAULT now()
);

-- таблица с данными работ из портфолио, которые хранятся в MinIO
CREATE TABLE media (
    id              BIGSERIAL PRIMARY KEY,
    -- если удалены работы, то и медиа тоже надо
    work_id         BIGINT NOT NULL REFERENCES portfolio_works(id) ON DELETE CASCADE,
    uri             TEXT NOT NULL,
    media_type      VARCHAR(50) CHECK (media_type IN ('image', 'video')),
    metadata        JSONB,
    created_at      TIMESTAMP DEFAULT now()
);

-- таблица с достижениями художников
CREATE TABLE achievements (
    id             BIGSERIAL PRIMARY KEY,
    -- достижения без художника бессмыслены
    artist_id      BIGINT NOT NULL REFERENCES artist_details(id) ON DELETE CASCADE,
    title          VARCHAR(255) NOT NULL,
    description    TEXT,
    link           TEXT,
    created_at     TIMESTAMP DEFAULT now()
);

-- таблица с отзывами художников о резиденциях
CREATE TABLE reviews (
    id           BIGSERIAL PRIMARY KEY,
    -- отзывы без программы ненужны
    program_id   BIGINT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    -- сохраняем исторические данные
    artist_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    score        INT CHECK (score >= 1 AND score <= 10),
    comment      TEXT,
    created_at   TIMESTAMP DEFAULT now(),

    UNIQUE(program_id, artist_id)
);

-- таблица с уведомлениями пользователям
CREATE TABLE notifications (
    id            BIGSERIAL PRIMARY KEY,
    -- уведомления для пользователя без пользователя ненужны
    user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message       TEXT NOT NULL,
    link          TEXT,
    category      VARCHAR(50) CHECK (category IN ('system', 'invite', 'review', 'status')),
    read_at       TIMESTAMP,
    created_at    TIMESTAMP DEFAULT now()
);

-- таблица со статистикой программ
CREATE TABLE program_stats (
    id                  BIGSERIAL PRIMARY KEY,
    -- статистика существует только вместе с программой
    program_id          BIGINT NOT NULL UNIQUE REFERENCES programs(id) ON DELETE CASCADE,
    views_count         INT DEFAULT 0,
    applications_count  INT DEFAULT 0,
    created_at          TIMESTAMP DEFAULT now(),
    updated_at          TIMESTAMP DEFAULT now()
);

-- таблица со статистикой резиденций
CREATE TABLE residence_stats (
    id              BIGSERIAL PRIMARY KEY,
    -- статистика существует только вместе с резиденцией
    residence_id    BIGINT NOT NULL UNIQUE REFERENCES residence_details(id) ON DELETE CASCADE,
    views_count     INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

-- таблица для просмотров программ
CREATE TABLE program_views_log (
    id BIGSERIAL PRIMARY KEY,
    -- просмотры без программы бессмыслены
    program_id BIGINT REFERENCES programs(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT now()
);

-- таблица для просмотров резиденций
CREATE TABLE residence_views_log (
    id BIGSERIAL PRIMARY KEY,
    -- просмотры без резиденции бессмыслены
    residence_id BIGINT REFERENCES residence_details(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT now()
);

--------------------------------------------------------------------------
-- ФУНКЦИИ И ТРИГГЕРЫ
--------------------------------------------------------------------------
-- и при при просмотре таблицы создавать запись в таблице для логов, что автоматом увеличит значение
CREATE OR REPLACE FUNCTION increment_program_view()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE program_stats
    SET views_count = views_count + 1,
        updated_at = now()
    WHERE program_id = NEW.program_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_program_view
AFTER INSERT ON program_views_log
FOR EACH ROW
EXECUTE FUNCTION increment_program_view();

-- и при при просмотре таблицы создавать запись в таблице для логов, что автоматом увеличит значение
CREATE OR REPLACE FUNCTION increment_residence_view()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE residence_stats
    SET views_count = views_count + 1,
        updated_at = now()
    WHERE residence_id = NEW.residence_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_residence_view
AFTER INSERT ON residence_views_log
FOR EACH ROW
EXECUTE FUNCTION increment_residence_view();


-- автоматическое увеличение количества заявок для программы
CREATE OR REPLACE FUNCTION increment_applications_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE program_stats
    SET applications_count = applications_count + 1,
        updated_at = now()
    WHERE program_id = NEW.program_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_program_application
AFTER INSERT ON application_requests
FOR EACH ROW
EXECUTE FUNCTION increment_applications_count();

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
    p_goals TEXT,
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
    VALUES (p_program_id, p_artist_user_id, 'sent', now(), now())
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
    v_program_expert_id BIGINT;
    v_assigned BOOLEAN;
    v_eval_id BIGINT;
    v_remaining INT;
BEGIN
    -- проверка существования заявки
    SELECT * INTO v_app FROM application_requests WHERE id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % not found', p_application_id;
    END IF;

    -- найти program_experts.id для данного эксперта и программы
    SELECT pe.id INTO v_program_expert_id
    FROM program_experts pe
    WHERE pe.program_id = v_app.program_id AND pe.user_id = p_expert_user_id;

    IF v_program_expert_id IS NULL THEN
        RAISE EXCEPTION 'Expert % is not assigned to program %', p_expert_user_id, v_app.program_id;
    END IF;

    -- проверка, что эксперт ещё не оценивал заявку
    SELECT id INTO v_eval_id
    FROM application_evaluations
    WHERE application_id = p_application_id AND expert_id = v_program_expert_id;

    IF FOUND THEN
        RAISE EXCEPTION 'Expert % already evaluated application % (evaluation id %)', p_expert_user_id, p_application_id, v_eval_id;
    END IF;

    -- вставка оценки
    INSERT INTO application_evaluations (application_id, expert_id, score, comment, created_at)
    VALUES (p_application_id, v_program_expert_id, p_score, p_comment, now())
    RETURNING id INTO v_eval_id;

    -- проверить, все ли эксперты оценили (и если да — поменять статус заявки на 'reviewed')
    SELECT count(*) INTO v_remaining
    FROM program_experts pe
    WHERE pe.program_id = v_app.program_id
      AND NOT EXISTS (
          SELECT 1 FROM application_evaluations ae
          WHERE ae.application_id = p_application_id AND ae.expert_id = pe.id
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
-- подсчет среднего балла
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

----------------------------------------------------------------------
-- индексы для пользователей
----------------------------------------------------------------------

-- поиск по email самый частый сценарий при регистрации и автризации
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- много операций с выборками по определенным ролям: назначение экспертов, ...
CREATE INDEX idx_users_role ON users(role);

----------------------------------------------------------------------
-- индексы для резиденций и программ
----------------------------------------------------------------------

-- просмотр всех программ резиденции
CREATE INDEX idx_programs_residence_id ON programs(residence_id);

-- поиск всех открытых программ
-- SELECT * FROM programs WHERE deadline_apply >= CURRENT_DATE;
CREATE INDEX idx_programs_deadline_apply ON programs(deadline_apply);

----------------------------------------------------------------------
-- индексы для заявок
----------------------------------------------------------------------

-- просмотр всех заявок на программу
CREATE INDEX idx_app_requests_program_id ON application_requests(program_id);

-- фильтрация заявок по статусу
CREATE INDEX idx_app_requests_status ON application_requests(status);

----------------------------------------------------------------------
-- индексы для оценок экспертов
----------------------------------------------------------------------

-- просмотр всех оценок заявки
CREATE INDEX idx_app_eval_application_id ON application_evaluations(application_id);

-- нужен для проверки, оценивал ли эксперт заявку
CREATE INDEX idx_app_eval_expert_id ON application_evaluations(expert_id);

----------------------------------------------------------------------
-- индексы для назначений экспертов
----------------------------------------------------------------------

-- эксперт смотрит свои программы
CREATE INDEX idx_program_experts_user_id ON program_experts(user_id);

----------------------------------------------------------------------
-- индексы для портфолио и медиа
----------------------------------------------------------------------

-- просмотр портфолио жудожника
CREATE INDEX idx_portfolio_artist_id ON portfolio_works(artist_id);

-- фильтрация работ по направлению
CREATE INDEX idx_portfolio_direction ON portfolio_works(art_direction);

----------------------------------------------------------------------
-- индексы для отзывов
----------------------------------------------------------------------

-- получение отзывов для программы
CREATE INDEX idx_reviews_program_id ON reviews(program_id);

----------------------------------------------------------------------
-- индексы для уведомлений
----------------------------------------------------------------------

-- просмотр уведомлений пользователем
CREATE INDEX idx_notifications_user_id ON notifications(user_id);

----------------------------------------------------------------------
-- индексы для статистики
----------------------------------------------------------------------

-- быстрый доступ к статистике программы
CREATE UNIQUE INDEX idx_program_stats_program_id ON program_stats(program_id);

-- быстрый доступ к статистике резиденции
CREATE UNIQUE INDEX idx_residence_stats_residence_id ON residence_stats(residence_id);
