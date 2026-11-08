-- Представление для сводной карточки заявки:
-- Собирает воедино данные заявки, подрядчика и текущего согласующего
CREATE OR REPLACE VIEW v_request_summary_card AS
SELECT 
    r.request_id,
    r.construction_object,
    r.request_date,
    r.current_status,
    contractor.full_name AS contractor_name,
    contractor.department AS contractor_org,
    approver.full_name AS current_approver_name,
    approver.department AS approver_department,
    -- Расчет количества дней в текущем статусе:
    ROUND(SYSDATE - r.request_date) AS days_in_work
FROM requests r
JOIN users contractor ON r.contractor_id = contractor.user_id
LEFT JOIN users approver ON r.current_approver_id = approver.user_id;