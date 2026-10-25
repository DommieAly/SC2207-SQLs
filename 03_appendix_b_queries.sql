-- Appendix B queries 1-4 and 6. Query 5 has an executable success/failure
-- demonstration in 04_stock_rule_demo.sql.
USE techpulse;

-- B1. Count completed procedures with actual logged time under 180 minutes,
-- by station and device category. A procedure with several sessions is counted once.
WITH procedure_minutes AS (
  SELECT ws.ticket_id,ws.item_no,ws.procedure_no,
         SUM(ws.billable_hours_minutes) AS actual_minutes
  FROM work_session ws
  GROUP BY ws.ticket_id,ws.item_no,ws.procedure_no
)
SELECT st.station_id,st.station_name,dc.device_category,
       COUNT(*) AS procedures_under_180_minutes
FROM procedure_minutes pm
JOIN repair_procedure rp ON (rp.ticket_id,rp.item_no,rp.procedure_no) =
  (pm.ticket_id,pm.item_no,pm.procedure_no)
JOIN work_station st ON st.station_id=rp.station_id
JOIN service_item si ON (si.ticket_id,si.item_no)=(rp.ticket_id,rp.item_no)
JOIN device d ON d.serial_number=si.serial_number
JOIN device_catalog dc ON (dc.manufacturer_name,dc.model_name)=
  (d.manufacturer_name,d.model_name)
WHERE rp.procedure_status='Completed'
  AND rp.procedure_type <> 'Diagnostics'
  AND pm.actual_minutes < 180
GROUP BY st.station_id,st.station_name,dc.device_category
ORDER BY st.station_id,dc.device_category;

-- B2. Pre-tax, pre-discount service charges for completed work orders.
-- Labor and parts are aggregated separately so their rows do not multiply.
WITH labor AS (
  SELECT ticket_id,item_no,
    SUM(billable_hours_minutes * locked_billing_rate / 60) AS labor_charge
  FROM work_session GROUP BY ticket_id,item_no
), components AS (
  SELECT ticket_id,item_no,
    SUM(quantity_used * locked_unit_price) AS parts_charge
  FROM part_component GROUP BY ticket_id,item_no
)
SELECT dc.device_category,
       ROUND(SUM(COALESCE(l.labor_charge,0)),2) AS labor_revenue,
       ROUND(SUM(COALESCE(p.parts_charge,0)),2) AS spare_parts_revenue,
       ROUND(SUM(COALESCE(l.labor_charge,0)+COALESCE(p.parts_charge,0)),2)
         AS total_service_revenue
FROM service_ticket st
JOIN service_item si ON si.ticket_id=st.ticket_id
JOIN device d ON d.serial_number=si.serial_number
JOIN device_catalog dc ON (dc.manufacturer_name,dc.model_name)=
  (d.manufacturer_name,d.model_name)
LEFT JOIN labor l ON (l.ticket_id,l.item_no)=(si.ticket_id,si.item_no)
LEFT JOIN components p ON (p.ticket_id,p.item_no)=(si.ticket_id,si.item_no)
WHERE st.current_status='Completed'
GROUP BY dc.device_category ORDER BY dc.device_category;

-- B3. First identify customers with a claim on an original repair that used
-- a mismatched technician; then count *all* claims by those customers, grouped
-- by device manufacturer. Inspection sessions are excluded.
WITH affected_clients AS (
  SELECT DISTINCT st.client_id
  FROM warranty_claim wc
  JOIN service_ticket st ON st.ticket_id=wc.original_ticket_id
  JOIN service_item si ON si.ticket_id=st.ticket_id
    AND si.item_no=wc.original_item_no
  JOIN work_session ws ON (ws.ticket_id,ws.item_no)=(si.ticket_id,si.item_no)
  JOIN repair_procedure rp ON (rp.ticket_id,rp.item_no,rp.procedure_no)=
    (ws.ticket_id,ws.item_no,ws.procedure_no)
  JOIN technician t ON t.employee_id=ws.technician_employee_id
  WHERE rp.procedure_type <> 'Diagnostics'
    AND t.primary_specialisation <> rp.procedure_type
), claim_manufacturers AS (
  SELECT DISTINCT st.client_id,wc.original_ticket_id,wc.claim_no,dc.manufacturer_name
  FROM warranty_claim wc
  JOIN service_ticket st ON st.ticket_id=wc.original_ticket_id
  JOIN service_item si ON si.ticket_id=st.ticket_id
    AND si.item_no=wc.original_item_no
  JOIN device d ON d.serial_number=si.serial_number
  JOIN device_catalog dc ON (dc.manufacturer_name,dc.model_name)=
    (d.manufacturer_name,d.model_name)
)
SELECT c.client_id,c.client_name,c.email,cm.manufacturer_name,
       COUNT(*) AS total_warranty_claims
FROM affected_clients ac JOIN client c ON c.client_id=ac.client_id
JOIN claim_manufacturers cm ON cm.client_id=c.client_id
GROUP BY c.client_id,c.client_name,c.email,cm.manufacturer_name
ORDER BY total_warranty_claims DESC,c.client_id,cm.manufacturer_name;

-- B4. Claims on original items whose initial assessment shows liquid damage.
-- The item-level predicate prevents another device on a batch ticket from
-- making an unrelated claim appear water-related.
SELECT c.client_id,c.client_name,c.email,
       COUNT(*) AS water_related_claim_count,
       SUM(wc.requested_remedy) AS total_requested_payout
FROM warranty_claim wc
JOIN service_ticket st ON st.ticket_id=wc.original_ticket_id
JOIN client c ON c.client_id=st.client_id
WHERE EXISTS (
  SELECT 1 FROM diagnostic_assessment da
  WHERE da.ticket_id=wc.original_ticket_id
    AND da.item_no=wc.original_item_no
    AND da.liquid_damage_indicator_status IN ('Liquid Damage','Tripped')
)
GROUP BY c.client_id,c.client_name,c.email
ORDER BY water_related_claim_count DESC,c.client_id;

-- B6. More than 3 separate tickets for one client/category/calendar month.
WITH monthly_ticket_counts AS (
  SELECT st.client_id,dc.device_category,
         DATE_FORMAT(st.date_received,'%Y-%m') AS ticket_month,
         COUNT(DISTINCT st.ticket_id) AS work_order_count
  FROM service_ticket st
  JOIN service_item si ON si.ticket_id=st.ticket_id
  JOIN device d ON d.serial_number=si.serial_number
  JOIN device_catalog dc ON (dc.manufacturer_name,dc.model_name)=
    (d.manufacturer_name,d.model_name)
  GROUP BY st.client_id,dc.device_category,DATE_FORMAT(st.date_received,'%Y-%m')
  HAVING COUNT(DISTINCT st.ticket_id) > 3
)
SELECT c.client_name,c.email,m.device_category,m.ticket_month,m.work_order_count,
       GROUP_CONCAT(DISTINCT si.serial_number ORDER BY si.serial_number
         SEPARATOR ', ') AS device_serial_numbers
FROM monthly_ticket_counts m
JOIN client c ON c.client_id=m.client_id
JOIN service_ticket st ON st.client_id=m.client_id
  AND DATE_FORMAT(st.date_received,'%Y-%m')=m.ticket_month
JOIN service_item si ON si.ticket_id=st.ticket_id
JOIN device d ON d.serial_number=si.serial_number
JOIN device_catalog dc ON (dc.manufacturer_name,dc.model_name)=
  (d.manufacturer_name,d.model_name)
  AND dc.device_category=m.device_category
GROUP BY c.client_id,c.client_name,c.email,m.device_category,m.ticket_month,m.work_order_count
ORDER BY c.client_name,m.ticket_month,m.device_category;
