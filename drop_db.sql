-- 1. удаляем триггеры
DROP TRIGGER IF EXISTS trg_program_view ON program_views_log;
DROP TRIGGER IF EXISTS trg_residence_view ON residence_views_log;
DROP TRIGGER IF EXISTS trg_program_application ON application_requests;

-- 2. удаляем функции
DROP FUNCTION IF EXISTS increment_program_view() CASCADE;
DROP FUNCTION IF EXISTS increment_residence_view() CASCADE;
DROP FUNCTION IF EXISTS increment_applications_count() CASCADE;
DROP FUNCTION IF EXISTS create_notification(BIGINT, TEXT, VARCHAR, TEXT) CASCADE;
DROP FUNCTION IF EXISTS mark_notification_read(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS log_program_view(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS log_residence_view(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS create_program(
    BIGINT, TEXT, TEXT, TEXT, DATE, DATE, DATE, INT, INT, INT, BIGINT
) CASCADE;
DROP FUNCTION IF EXISTS submit_application(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS confirm_participation(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS decline_participation(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS assign_expert_to_program(BIGINT, BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS unassign_expert(BIGINT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS add_evaluation(BIGINT, BIGINT, INT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS calculate_application_rating(BIGINT) CASCADE;

-- 3. удаляем таблицы (в правильном порядке, чтобы не упасть на FK)
DROP TABLE IF EXISTS residence_views_log CASCADE;
DROP TABLE IF EXISTS program_views_log CASCADE;
DROP TABLE IF EXISTS residence_stats CASCADE;
DROP TABLE IF EXISTS program_stats CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS media CASCADE;
DROP TABLE IF EXISTS portfolio_works CASCADE;
DROP TABLE IF EXISTS application_evaluations CASCADE;
DROP TABLE IF EXISTS application_requests CASCADE;
DROP TABLE IF EXISTS program_experts CASCADE;
DROP TABLE IF EXISTS programs CASCADE;
DROP TABLE IF EXISTS validation_requests CASCADE;
DROP TABLE IF EXISTS residence_details CASCADE;
DROP TABLE IF EXISTS artist_details CASCADE;
DROP TABLE IF EXISTS art_users CASCADE;

-- 4. enum
DROP TYPE IF EXISTS art_direction_enum;

-- 5. индексы, если что-то не удалилось каскадно
DROP INDEX IF EXISTS idx_users_email;
DROP INDEX IF EXISTS idx_users_role;

DROP INDEX IF EXISTS idx_programs_residence_id;
DROP INDEX IF EXISTS idx_programs_deadline_apply;

DROP INDEX IF EXISTS idx_app_requests_program_id;
DROP INDEX IF EXISTS idx_app_requests_status;

DROP INDEX IF EXISTS idx_app_eval_application_id;
DROP INDEX IF EXISTS idx_app_eval_expert_id;

DROP INDEX IF EXISTS idx_program_experts_user_id;

DROP INDEX IF EXISTS idx_portfolio_artist_id;
DROP INDEX IF EXISTS idx_portfolio_direction;

DROP INDEX IF EXISTS idx_reviews_program_id;

DROP INDEX IF EXISTS idx_notifications_user_id;

DROP INDEX IF EXISTS idx_program_stats_program_id;
DROP INDEX IF EXISTS idx_residence_stats_residence_id;
