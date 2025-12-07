
-- TODO: возможно стоит сделать все поля с проверками вида role IN ('ROLE_ARTIST', 'ROLE_EXPERT', 'ROLE_RESIDENCE_ADMIN', 'ROLE_SUPERADMIN') enum
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
    -- TODO: если пользователь может иметь несколько ролей, надо это убрать
    -- иначе надо добавить триггер. Смотри TODO для program_experts и application_requests
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
    goals                       JSONB,
    deadline_apply              DATE NOT NULL,
    deadline_review             DATE NOT NULL,
    deadline_notify             DATE NOT NULL,
    status                      VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')), -- TODO
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
    -- TODO: возможно надо добавить ограничение на добавление только с ролью ROLE_EXPERT
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
    -- TODO: возможно надо добавить ограничение на добавление только с ролью ROLE_ARTIST
    -- если художник участвовал в программе, его нельзя удалять
    artist_id        BIGINT NOT NULL REFERENCES artist_details(id) ON DELETE RESTRICT,
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
    score           INT CHECK (score >= 0 AND score <= 100),
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
    media_type      VARCHAR(50) CHECK (media_type IN ('image', 'video'))
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
    artist_id    BIGINT NOT NULL REFERENCES artist_details(id) ON DELETE RESTRICT,
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

--------------------------------------------------------------------------
-- ФУНКЦИИ И ТРИГГЕРЫ
--------------------------------------------------------------------------
-- TODO: чтобы увеличивать просмотры с помощью триггера, надо добавить таблицу:
CREATE TABLE program_views_log (
    id BIGSERIAL PRIMARY KEY,
    -- просмотры без программы бессмыслены
    program_id BIGINT REFERENCES programs(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT now()
);

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

-- TODO: чтобы увеличивать просмотры с помощью триггера, надо добавить таблицу:
CREATE TABLE residence_views_log (
    id BIGSERIAL PRIMARY KEY,
    -- просмотры без резиденции бессмыслены
    residence_id BIGINT REFERENCES residence_details(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT now()
);

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
