# Расчёт количества пользователей, числа trial, оплат и итоговых конверсий для old и new onboarding.
SELECT 
    onboarding_version,
    COUNT(DISTINCT user_id) AS users,
    SUM(trial_started_flag) AS trial_users,
    SUM(paid_flag) AS pay_users,
    ROUND(SUM(trial_started_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS trial_conv,
    ROUND(SUM(paid_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS pay_conv
FROM users
GROUP BY onboarding_version;

# Сравнение конверсии в оплату по платформам (Android / iOS) для разных версий onboarding.
SELECT 
onboarding_version, 
device_type, 
COUNT(DISTINCT user_id) AS users, 
ROUND(SUM(trial_started_flag) * 100.0 / COUNT(DISTINCT user_id), 1) AS trial_conv, 
ROUND(SUM(paid_flag) * 100.0 / COUNT(DISTINCT user_id), 1) AS pay_conv 
FROM users 
GROUP BY onboarding_version, device_type;

# Сравнение конверсии в оплату по странам для old и new onboarding.
SELECT 
    onboarding_version,
    country,
    COUNT(DISTINCT user_id) AS users,
    ROUND(SUM(trial_started_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS trial_conv,
    ROUND(SUM(paid_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS pay_conv
FROM users
GROUP BY onboarding_version, country
ORDER BY country;

# Анализ retention на 1, 3 и 7 день после регистрации.
SELECT
    u.onboarding_version,
    ROUND(AVG(r.returned_day_1)*100,1) AS day1_retention,
    ROUND(AVG(r.returned_day_3)*100,1) AS day3_retention,
    ROUND(AVG(r.returned_day_7)*100,1) AS day7_retention
FROM users u
JOIN retention_flags r 
ON u.user_id = r.user_id
GROUP BY u.onboarding_version;

# Количество сессий, средняя длительность сессии, число начатых и завершённых уроков по версиям onboarding.
WITH sessions_per_user AS (
SELECT
        user_id,
        COUNT(*) AS sessions_cnt,
        AVG(session_duration_sec) AS avg_session_sec,
        SUM(lessons_started) AS lessons_started_cnt,
        SUM(lessons_completed) AS lessons_completed_cnt
    FROM sessions
    GROUP BY user_id
)
SELECT
    u.onboarding_version,
    ROUND(AVG(s.sessions_cnt), 2) AS avg_sessions_per_user,
    ROUND(AVG(s.avg_session_sec), 1) AS avg_session_sec,
    ROUND(AVG(s.lessons_started_cnt), 2) AS avg_lessons_started_per_user,
    ROUND(AVG(s.lessons_completed_cnt), 2) AS avg_lessons_completed_per_user
FROM users u
JOIN sessions_per_user s
    ON u.user_id = s.user_id
GROUP BY u.onboarding_version;

# Сравнение количества пользователей, конверсии в trial и оплаты по каналам привлечения для old и new onboarding.
SELECT
    onboarding_version,
    acquisition_channel,
    COUNT(DISTINCT user_id) AS users,
    SUM(trial_started_flag) AS trial_users,
    ROUND(SUM(trial_started_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS trial_conv,
    SUM(paid_flag) AS pay_users,
    ROUND(SUM(paid_flag) * 100.0 / COUNT(DISTINCT user_id),1) AS pay_conv
FROM users
GROUP BY onboarding_version, acquisition_channel
ORDER BY acquisition_channel, onboarding_version;

# Накопительная конверсия от регистрации до trial
SELECT 
onboarding_version, 
ROUND(SUM(CASE WHEN trial_started_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT user_id), 2) AS reg_to_trial_conv 
FROM users 
GROUP BY onboarding_version;

# Конверсия между соседними шагами
WITH step_counts AS (
    SELECT
        u.onboarding_version,
        e.step_number,
        e.step_name,
        COUNT(DISTINCT e.user_id) AS users_at_step
    FROM onboarding_events e
    JOIN users u
        ON e.user_id = u.user_id
    GROUP BY u.onboarding_version, e.step_number, e.step_name
),
step_conv AS (
    SELECT
        onboarding_version,
        step_number,
        step_name,
        users_at_step,
        LAG(users_at_step) OVER (PARTITION BY onboarding_version ORDER BY step_number) AS prev_users
    FROM step_counts
)
SELECT
    onboarding_version,
    step_name,
    users_at_step,
    ROUND(users_at_step * 100.0 / prev_users, 2) AS step_conversion
FROM step_conv
WHERE prev_users IS NOT NULL
ORDER BY onboarding_version, step_number;

