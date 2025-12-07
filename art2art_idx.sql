----------------------------------------------------------------------
-- индексы для пользователей
----------------------------------------------------------------------

-- поиск по email самый частый сценарий при регистрации и автризации
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- много операций с выборками по определенным ролям: назначение экспертов, ...
CREATE INDEX idx_users_role ON users(role);

-- портфолио часто будут просмотривать, индекс для быстрого достпа к работам от пользователя
CREATE UNIQUE INDEX idx_artist_details_user_id ON artist_details(user_id);


----------------------------------------------------------------------
-- индексы для резиденций и программ
----------------------------------------------------------------------

-- быстрый поиск резиденций по владельцу
CREATE UNIQUE INDEX idx_residence_details_user_id ON residence_details(user_id);

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
CREATE INDEX idx_app_eval_expert_id ON application_evaluations(expert_user_id);


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
