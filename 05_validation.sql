-- Read-only checks, except for a rolled-back temporary price change.
USE techpulse;
SELECT COUNT(*) AS table_count, IF(COUNT(*)=22,'PASS','FAIL') AS expected_22_tables
FROM information_schema.tables
WHERE table_schema='techpulse' AND table_type='BASE TABLE';

SELECT 'client' AS table_name,COUNT(*) AS row_count FROM client
UNION ALL SELECT 'device_catalog',COUNT(*) FROM device_catalog
UNION ALL SELECT 'device',COUNT(*) FROM device
UNION ALL SELECT 'employee',COUNT(*) FROM employee
UNION ALL SELECT 'clerk',COUNT(*) FROM clerk
UNION ALL SELECT 'technician',COUNT(*) FROM technician
UNION ALL SELECT 'inventory_manager',COUNT(*) FROM inventory_manager
UNION ALL SELECT 'workshop_manager',COUNT(*) FROM workshop_manager
UNION ALL SELECT 'work_station',COUNT(*) FROM work_station
UNION ALL SELECT 'manage',COUNT(*) FROM manage
UNION ALL SELECT 'service_ticket',COUNT(*) FROM service_ticket
UNION ALL SELECT 'service_item',COUNT(*) FROM service_item
UNION ALL SELECT 'repair_procedure',COUNT(*) FROM repair_procedure
UNION ALL SELECT 'diagnostic_assessment',COUNT(*) FROM diagnostic_assessment
UNION ALL SELECT 'work_session',COUNT(*) FROM work_session
UNION ALL SELECT 'parts',COUNT(*) FROM parts
UNION ALL SELECT 'part_component',COUNT(*) FROM part_component
UNION ALL SELECT 'supplier',COUNT(*) FROM supplier
UNION ALL SELECT 'purchase_order',COUNT(*) FROM purchase_order
UNION ALL SELECT 'restock_request',COUNT(*) FROM restock_request
UNION ALL SELECT 'billing_statement',COUNT(*) FROM billing_statement
UNION ALL SELECT 'warranty_claim',COUNT(*) FROM warranty_claim;

-- In this sample, every item belongs to the same client as its ticket.
SELECT COUNT(*) AS ticket_device_owner_mismatches
FROM service_item si JOIN service_ticket st ON st.ticket_id=si.ticket_id
JOIN device d ON d.serial_number=si.serial_number
WHERE st.client_id<>d.client_id;

-- Cross-table rules that ordinary CHECK constraints cannot express.
SELECT COUNT(*) AS non_diagnostic_assessments
FROM diagnostic_assessment da
JOIN repair_procedure rp ON (rp.ticket_id,rp.item_no,rp.procedure_no)=
  (da.ticket_id,da.item_no,da.procedure_no)
WHERE rp.procedure_type<>'Diagnostics';

SELECT COUNT(*) AS physical_repair_items_without_assessment
FROM (SELECT DISTINCT ticket_id,item_no FROM repair_procedure
      WHERE procedure_type<>'Diagnostics' AND procedure_status<>'Cancelled') p
LEFT JOIN diagnostic_assessment da ON (da.ticket_id,da.item_no)=
  (p.ticket_id,p.item_no)
WHERE da.ticket_id IS NULL;

SELECT COUNT(*) AS station_occupancy_mismatches
FROM work_station s
WHERE (s.occupancy_status='Occupied') <>
  EXISTS (SELECT 1 FROM repair_procedure rp
          WHERE rp.station_id=s.station_id AND rp.procedure_status='In Progress');

SELECT COUNT(*) AS warranty_window_or_owner_mismatches
FROM warranty_claim wc
JOIN billing_statement b ON b.ticket_id=wc.original_ticket_id
JOIN service_ticket st ON st.ticket_id=wc.original_ticket_id
JOIN service_item si ON (si.ticket_id,si.item_no)=
  (wc.original_ticket_id,wc.original_item_no)
JOIN device d ON d.serial_number=si.serial_number
WHERE DATEDIFF(wc.submission_date,b.billing_date) NOT BETWEEN 0 AND 90
   OR st.client_id<>d.client_id;

SELECT COUNT(*) AS claim_amount_status_mismatches
FROM warranty_claim
WHERE (review_status='Approved' AND
       (approved_remedy IS NULL OR approved_remedy<0))
   OR (review_status<>'Approved' AND approved_remedy IS NOT NULL);

SELECT COUNT(*) AS warranty_followup_mismatches
FROM service_ticket st
JOIN warranty_claim wc ON (wc.original_ticket_id,wc.claim_no)=
  (st.claim_original_ticket_id,st.claim_no)
JOIN service_item original_item ON (original_item.ticket_id,original_item.item_no)=
  (wc.original_ticket_id,wc.original_item_no)
JOIN service_item followup_item ON followup_item.ticket_id=st.ticket_id
WHERE wc.review_status<>'Approved'
   OR followup_item.serial_number<>original_item.serial_number;

-- In this seed no purchase order has been received, so current stock is a
-- valid check of whether each recorded request remains at/below threshold.
SELECT COUNT(*) AS restock_requests_above_threshold
FROM restock_request rr JOIN parts p ON p.part_code=rr.part_code
WHERE p.current_quantity>p.min_reorder_threshold;

-- Invoices derive labor and parts independently, then apply discount and tax.
WITH labor AS (
 SELECT ticket_id,ROUND(SUM(billable_hours_minutes*locked_billing_rate/60),2) AS labor_total
 FROM work_session GROUP BY ticket_id
), components AS (
 SELECT ticket_id,SUM(quantity_used*locked_unit_price) AS parts_total
 FROM part_component GROUP BY ticket_id
)
SELECT b.ticket_id,COALESCE(l.labor_total,0) AS labor_total,
       COALESCE(p.parts_total,0) AS parts_total,
       ROUND((COALESCE(l.labor_total,0)+COALESCE(p.parts_total,0)
         - b.promotional_discount)*(1+b.applicable_tax_rates),2) AS invoice_total,
       b.amount_paid,
       ROUND(ROUND((COALESCE(l.labor_total,0)+COALESCE(p.parts_total,0)
         - b.promotional_discount)*(1+b.applicable_tax_rates),2)-b.amount_paid,2)
         AS balance_due
FROM billing_statement b
LEFT JOIN labor l ON l.ticket_id=b.ticket_id
LEFT JOIN components p ON p.ticket_id=b.ticket_id
ORDER BY b.ticket_id;

WITH labor AS (
  SELECT ticket_id,SUM(billable_hours_minutes*locked_billing_rate/60) AS amount
  FROM work_session GROUP BY ticket_id
), components AS (
  SELECT ticket_id,SUM(quantity_used*locked_unit_price) AS amount
  FROM part_component GROUP BY ticket_id
), due AS (
  SELECT b.ticket_id,b.promotional_discount,b.amount_paid,b.current_payment_status,
    COALESCE(l.amount,0)+COALESCE(p.amount,0) AS gross,
    ROUND((COALESCE(l.amount,0)+COALESCE(p.amount,0)-b.promotional_discount)
      *(1+b.applicable_tax_rates),2) AS invoice_total
  FROM billing_statement b
  LEFT JOIN labor l ON l.ticket_id=b.ticket_id
  LEFT JOIN components p ON p.ticket_id=b.ticket_id
)
SELECT COUNT(*) AS payment_or_discount_mismatches
FROM due
WHERE promotional_discount>gross OR amount_paid>invoice_total
   OR (current_payment_status='Unpaid' AND amount_paid<>0)
   OR (current_payment_status='Paid' AND amount_paid<>invoice_total)
   OR (current_payment_status='Partial' AND
       (amount_paid<=0 OR amount_paid>=invoice_total));

-- Changing today's catalog price does not change prior locked repair prices.
START TRANSACTION;
UPDATE parts SET selling_price=99.00 WHERE part_code='AUD-001';
SELECT p.selling_price AS current_catalog_price,
       pc.locked_unit_price AS historical_charge_price,
       IF(pc.locked_unit_price=80.00,'PASS','FAIL') AS price_snapshot_test
FROM parts p JOIN part_component pc ON pc.part_code=p.part_code
WHERE p.part_code='AUD-001' AND pc.ticket_id=1007;
ROLLBACK;
