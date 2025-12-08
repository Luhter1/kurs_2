-- Вставка тестовых пользователей
INSERT INTO art_users (email, password_hash, name, surname, role) VALUES
('superadmin@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Супер', 'Админ', 'ROLE_SUPERADMIN'),
('admin1@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Иван', 'Иванов', 'ROLE_RESIDENCE_ADMIN'),
('admin2@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Петр', 'Петров', 'ROLE_RESIDENCE_ADMIN'),
('expert1@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Анна', 'Сидорова', 'ROLE_EXPERT'),
('expert2@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Мария', 'Кузнецова', 'ROLE_EXPERT'),
('artist1@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Алексей', 'Смирнов', 'ROLE_ARTIST'),
('artist2@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Елена', 'Васильева', 'ROLE_ARTIST'),
('artist3@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Дмитрий', 'Попов', 'ROLE_ARTIST'),
('artist4@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Ольга', 'Новикова', 'ROLE_ARTIST'),
('artist5@example.com', '$2a$10$xJwL5v5z3b3Z3b3Z3b3Z3u', 'Сергей', 'Морозов', 'ROLE_ARTIST');

-- Вставка профилей художников
INSERT INTO artist_details (user_id, location) VALUES
(6, 'Москва'),
(7, 'Санкт-Петербург'),
(8, 'Казань'),
(9, 'Екатеринбург'),
(10, 'Новосибирск');

-- Вставка резиденций
INSERT INTO residence_details (user_id, title, description, location, is_published) VALUES
(2, 'Московская арт-резиденция', 'Современная резиденция в центре Москвы', 'Москва', true),
(3, 'Петербургская творческая мастерская', 'Резиденция для художников всех направлений', 'Санкт-Петербург', true);

-- Вставка заявок на валидацию резиденций
INSERT INTO validation_requests (residence_id, status, comment, submitted_at, processed_at) VALUES
(1, 'approved', 'Резиденция одобрена', now() - interval '7 days', now() - interval '5 days'),
(2, 'pending', NULL, now() - interval '2 days', NULL);

-- Вставка программ
INSERT INTO programs (residence_id, title, description, goals, deadline_apply, deadline_review, deadline_notify, duration_days, budget_quota, people_quota) VALUES
(1, 'Летняя арт-программа', 'Интенсивная программа для художников', '{"goal1": "Развитие творческих навыков", "goal2": "Создание новых работ"}', now() + interval '30 days', now() + interval '45 days', now() + interval '50 days', 30, 500000, 10),
(1, 'Зимняя мастерская', 'Программа для цифровых художников', '{"goal1": "Освоение новых технологий", "goal2": "Создание цифровых арт-объектов"}', now() + interval '60 days', now() + interval '75 days', now() + interval '80 days', 45, 700000, 8),
(2, 'Весенняя выставка', 'Подготовка к ежегодной выставке', '{"goal1": "Создание экспозиции", "goal2": "Подготовка к презентации"}', now() + interval '15 days', now() + interval '30 days', now() + interval '35 days', 60, 300000, 12);

-- Вставка статистики программ
INSERT INTO program_stats (program_id, views_count, applications_count) VALUES
(1, 150, 0),
(2, 80, 0),
(3, 200, 0);

-- Вставка назначений экспертов
INSERT INTO program_experts (program_id, user_id) VALUES
(1, 4),
(1, 5),
(2, 4),
(3, 5);

-- Вставка заявок художников
INSERT INTO application_requests (program_id, artist_id, status) VALUES
(1, 6, 'approved'),
(1, 7, 'reserve'),
(1, 8, 'rejected'),
(2, 6, 'reviewed'),
(2, 9, 'sent'),
(3, 7, 'confirmed'),
(3, 8, 'declined_by_artist'),
(3, 10, 'approved');

-- Вставка оценок заявок
INSERT INTO application_evaluations (application_id, expert_id, score, comment) VALUES
(1, 1, 8, 'Сильная заявка с интересным подходом'),
(1, 2, 9, 'Отличная работа, рекомендую к участию'),
(4, 3, 7, 'Хорошая заявка, но требует доработки'),
(6, 4, 8, 'Очень сильный портфолио');

-- Вставка работ портфолио
INSERT INTO portfolio_works (artist_id, title, description, link, art_direction, date) VALUES
(1, 'Городской пейзаж', 'Абстрактное изображение мегаполиса', 'http://example.com/art1', 'painting', '2023-05-15'),
(1, 'Цифровой коллаж', 'Комбинация фотографии и цифровой живописи', 'http://example.com/art2', 'digital_art', '2023-07-20'),
(2, 'Скульптура времени', 'Инсталляция из металла и стекла', 'http://example.com/art3', 'sculpture', '2023-03-10'),
(3, 'Перформанс "Тишина"', 'Видео-запись перформанса', 'http://example.com/art4', 'performance', '2023-09-05'),
(4, 'Серия фотографий', 'Документальная фотография', 'http://example.com/art5', 'photo', '2023-06-18'),
(5, 'Мультимедийная инсталляция', 'Интерактивная инсталляция', 'http://example.com/art6', 'multimedia', '2023-10-25');

-- Вставка медиа-файлов
INSERT INTO media (work_id, uri, media_type, metadata) VALUES
(1, 'portfolio/1/image1.jpg', 'image', '{"width": 1920, "height": 1080, "format": "jpg"}'),
(1, 'portfolio/1/image2.jpg', 'image', '{"width": 1280, "height": 720, "format": "jpg"}'),
(2, 'portfolio/2/video1.mp4', 'video', '{"duration": "00:04:22", "format": "mp4"}'),
(3, 'portfolio/3/image1.jpg', 'image', '{"width": 2048, "height": 1536, "format": "jpg"}'),
(4, 'portfolio/4/video1.mp4', 'video', '{"duration": "00:12:45", "format": "mp4"}'),
(5, 'portfolio/5/image1.jpg', 'image', '{"width": 3000, "height": 2000, "format": "jpg"}'),
(6, 'portfolio/6/video1.mp4', 'video', '{"duration": "00:08:30", "format": "mp4"}');

-- Вставка достижений художников
INSERT INTO achievements (artist_id, title, description, link) VALUES
(1, 'Лауреат премии "Золотая кисть"', 'Первое место в номинации "Живопись"', 'http://example.com/award1'),
(2, 'Участник биеннале современного искусства', 'Представлял Россию на международной выставке', 'http://example.com/award2'),
(3, 'Грант фонда поддержки искусства', 'Получил грант на создание новой инсталляции', 'http://example.com/award3'),
(4, 'Победитель фотоконкурса "Мир глазами художника"', 'Первое место в категории "Документальная фотография"', 'http://example.com/award4');

-- Вставка отзывов о программах
INSERT INTO reviews (program_id, artist_id, score, comment) VALUES
(1, 6, 9, 'Отличная программа, много полезных знакомств и вдохновения'),
(1, 7, 8, 'Хорошая организация, но хотелось бы больше практических занятий'),
(3, 7, 10, 'Великолепная резиденция, обязательно приму участие снова');

-- Вставка уведомлений
INSERT INTO notifications (user_id, message, category, link, read_at) VALUES
(2, 'Новая заявка на программу "Летняя арт-программа"', 'review', '/programs/1/applications', NULL),
(4, 'Вас назначили экспертом на программу "Зимняя мастерская"', 'invite', '/programs/2', now() - interval '1 day'),
(6, 'Ваша заявка на программу одобрена', 'status', '/applications/1', now() - interval '2 hours'),
(7, 'Новая оценка вашей заявки', 'review', '/applications/6', NULL),
(3, 'Программа "Весенняя выставка" набрала достаточно заявок', 'system', '/programs/3', now() - interval '1 day');

-- Вставка статистики резиденций
INSERT INTO residence_stats (residence_id, views_count) VALUES
(1, 350),
(2, 280);

-- Вставка логов просмотров
INSERT INTO program_views_log (program_id) VALUES
(1), (1), (2), (3), (3), (3);

INSERT INTO residence_views_log (residence_id) VALUES
(1), (1), (1), (2), (2);
