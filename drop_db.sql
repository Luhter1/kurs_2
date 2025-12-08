-- Завершение активных соединений с базой
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'art_residency_db';

-- Удаление базы данных
DROP DATABASE IF EXISTS art_residency_db;
