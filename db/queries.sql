/* =================================================================
   1. СВЯЗЬ С ТЕКУЩИМ СОГЛАСУЮЩИМ (INNER JOIN)
   Цель: Вывести только активные заявки, у которых назначен согласующий,
   чтобы понимать, на ком конкретно лежит задача.
================================================================= */
SELECT 
    r.request_id,
    r.construction_object,
    r.request_date,
    u.full_name AS current_approver,
    u.department AS approver_dept
FROM requests r
INNER JOIN users u ON r.current_approver_id = u.user_id
WHERE r.current_status = 'IN_PROGRESS';

/* =================================================================
   2. МОНИТОРИНГ ВСЕХ ЗАЯВОК (LEFT JOIN)
   Цель: Руководителю важно не терять заявки, по которым согласование 
   ещё даже не начиналось (этапов нет в таблице approval_stages).
================================================================= */
SELECT 
    r.request_id,
    r.construction_object,
    r.current_status,
    st.stage_name,
    st.decision,
    st.assigned_date
FROM requests r
LEFT JOIN approval_stages st ON r.request_id = st.request_id
ORDER BY r.request_date DESC;

/* =================================================================
   3. ФИЛЬТРАЦИЯ ПО ПОСЛЕДНЕМУ ЭТАПУ ЧЕРЕЗ ПОДЗАПРОС
   Цель: Отобрать только финальное действие по заявке 
   без использования оконных функций.
================================================================= */
SELECT 
    st.request_id,
    st.stage_name,
    st.decision,
    st.decision_date,
    st.comment_text
FROM approval_stages st
WHERE st.stage_id IN (
    -- Подзапрос находит максимальный (последний) идентификатор этапа для каждой заявки
    SELECT MAX(stage_id)
    FROM approval_stages
    GROUP BY request_id
);

/* =================================================================
   4. МЕТРИКИ ДЛЯ РУКОВОДСТВА (GROUP BY + CASE)
   Цель: Сводка по отделам — сколько заявок согласовано, отклонено 
   или застряло на согласовании свыше 7 дней.
================================================================= */
SELECT 
    u.department,
    COUNT(r.request_id) AS total_requests,
    -- Категоризация через CASE:
    SUM(CASE WHEN r.current_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_count,
    SUM(CASE WHEN r.current_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_count,
    SUM(CASE WHEN r.current_status = 'IN_PROGRESS' AND (SYSDATE - r.request_date) > 7 THEN 1 ELSE 0 END) AS overdue_count
FROM requests r
INNER JOIN users u ON r.current_approver_id = u.user_id
GROUP BY u.department
ORDER BY overdue_count DESC;

/* =================================================================
   5. ПРОВЕРКА ЦЕЛОСТНОСТИ ДАННЫХ (DATA QUALITY И ДУБЛИКАТЫ)
   Цель: Проверка отсутствия задвоения записей по заявкам и этапам.
================================================================= */
-- А. Поиск дублей этапов по одной и той же заявке
SELECT 
    request_id,
    stage_name,
    COUNT(*) AS duplicates_count
FROM approval_stages
GROUP BY request_id, stage_name
HAVING COUNT(*) > 1;

-- Б. Сверка количества строк до и после JOIN для исключения декартова произведения
SELECT 
    (SELECT COUNT(*) FROM requests) AS total_requests,
    (SELECT COUNT(DISTINCT r.request_id) 
     FROM requests r 
     LEFT JOIN approval_stages s ON r.request_id = s.request_id) AS requests_after_join;