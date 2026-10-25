-- Run after 01_schema.sql. All names, contact details, and identifiers are fictional.
USE techpulse;
START TRANSACTION;

INSERT INTO client VALUES
(1,'Ada Lee','+65 8000 1001','ada.lee@example.test','11 Orchard Road, Singapore','2026-09-01','Individual'),
(2,'Northstar Labs Pte Ltd','+65 8000 2002','it@northstar.example.test','8 Science Park Drive, Singapore','2026-08-15','Corporate'),
(3,'Chen Wei','+65 8000 3003','chen.wei@example.test','20 Bedok North Road, Singapore','2026-09-12','Individual'),
(4,'Harborline Logistics Pte Ltd','+65 8000 4004','ops@harborline.example.test','5 Jurong Port Road, Singapore','2026-07-20','Corporate'),
(5,'Elena Tan','+65 8000 5005','elena.tan@example.test','42 Tampines Avenue, Singapore','2026-10-01','Individual');

INSERT INTO device_catalog VALUES
('Aster','Aster X','24','Smartphone'),
('Aster','Aster Tab 11','12','Tablet'),
('Meridian','M One','18','Smartphone'),
('Meridian','M Watch','12','Smartwatch'),
('Sonic','Sonic Max','12','Headphones'),
('Sonic','Sonic Buds','12','Earbuds');

INSERT INTO device VALUES
('SN-A001','356789012340001','Black',128,1,'Aster','Aster X'),
('SN-A002','356789012340002','Silver',256,1,'Aster','Aster X'),
('SN-A003','356789012340003','Blue',128,1,'Meridian','M One'),
('SN-A004','356789012340004','Black',256,1,'Meridian','M One'),
('SN-N005','356789012340005','White',128,2,'Aster','Aster X'),
('SN-N006','356789012340006','Gray',256,2,'Aster','Aster Tab 11'),
('SN-C007',NULL,'Black',NULL,3,'Sonic','Sonic Max'),
('SN-E008',NULL,'Blue',NULL,5,'Sonic','Sonic Max'),
('SN-H009',NULL,'White',NULL,4,'Sonic','Sonic Max'),
('SN-E010',NULL,'Black',32,5,'Meridian','M Watch');

INSERT INTO employee VALUES
(101,'Maya Lim'),(102,'Oliver Goh'),
(201,'Ravi Kumar'),(202,'Nora Aziz'),(203,'Grace Ong'),(204,'Daniel Koh'),(205,'Sophia Wong'),
(301,'Irene Chua'),(401,'Marcus Teo');
INSERT INTO clerk VALUES (101),(102);
INSERT INTO technician VALUES
(201,'Display','Senior',72.00),
(202,'Audio','Senior',68.00),
(203,'Battery','Level 2',62.00),
(204,'Diagnostics','Level 2',55.00),
(205,'Wearables','Senior',75.00);
INSERT INTO inventory_manager VALUES (301);
INSERT INTO workshop_manager VALUES (401);
INSERT INTO work_station VALUES
(1,'Cleanroom Screen Station','Free'),
(2,'Micro-Soldering Desk','Free'),
(3,'Audio Testing Station','Occupied'),
(4,'ESD-Safe Diagnostic Bench','Free'),
(5,'Battery Safety Bench','Free');
INSERT INTO manage VALUES (401,1),(401,2),(401,3),(401,4),(401,5);

INSERT INTO service_ticket
(ticket_id,date_received,current_status,client_id,clerk_employee_id,claim_original_ticket_id,claim_no) VALUES
(1001,'2026-10-02 09:10:00','Completed',1,101,NULL,NULL),
(1002,'2026-10-05 10:20:00','Completed',1,101,NULL,NULL),
(1003,'2026-10-08 11:00:00','Completed',1,102,NULL,NULL),
(1004,'2026-10-11 14:30:00','Completed',1,101,NULL,NULL),
(1005,'2026-10-13 09:00:00','Completed',2,102,NULL,NULL),
(1006,'2026-10-09 15:40:00','Completed',3,101,NULL,NULL),
(1007,'2026-10-16 08:30:00','In Progress',3,101,NULL,NULL),
(1008,'2026-10-17 13:25:00','In Progress',5,102,NULL,NULL),
(1009,'2026-10-17 08:15:00','In Progress',4,102,NULL,NULL),
(1010,'2026-10-20 16:10:00','Received',5,101,NULL,NULL);

INSERT INTO service_item VALUES
(1001,1,'Front glass shattered','Replace OLED screen',180.00,'SN-A001'),
(1002,1,'Battery swollen slightly','Replace battery',95.00,'SN-A002'),
(1003,1,'Liquid mark visible near connector','Repair flickering display',210.00,'SN-A003'),
(1004,1,'No visible exterior damage','Replace touch display',190.00,'SN-A004'),
(1005,1,'Cracked screen','Replace fleet phone screen',180.00,'SN-N005'),
(1005,2,'Charging port loose','Repair tablet charging port',120.00,'SN-N006'),
(1006,1,'Moisture indicator tripped','Replace audio driver',140.00,'SN-C007'),
(1007,1,'Audio fails again after pickup','Warranty audio driver replacement',0.00,'SN-C007'),
(1008,1,'Left channel silent','Diagnose and replace audio driver',120.00,'SN-E008'),
(1009,1,'Right channel distorted','Replace corporate headset driver',130.00,'SN-H009'),
(1010,1,'Case and strap intact','Diagnose charging failure',90.00,'SN-E010');

INSERT INTO repair_procedure VALUES
(1001,1,1,'Diagnostics','Initial inspection','Completed',4),
(1001,1,2,'Display','OLED screen replacement','Completed',1),
(1002,1,1,'Diagnostics','Initial inspection','Completed',4),
(1002,1,2,'Battery','Battery replacement','Completed',5),
(1003,1,1,'Diagnostics','Liquid indicator and screen inspection','Completed',4),
(1003,1,2,'Display','Display connector and panel repair','Completed',2),
(1004,1,1,'Diagnostics','Initial inspection','Completed',4),
(1004,1,2,'Display','Touch display replacement','Completed',1),
(1005,1,1,'Diagnostics','Fleet phone inspection','Completed',4),
(1005,1,2,'Display','Fleet phone screen replacement','Completed',1),
(1005,2,1,'Diagnostics','Tablet charging inspection','Completed',4),
(1005,2,2,'Battery','Tablet charging port repair','Completed',2),
(1006,1,1,'Diagnostics','Moisture and audio inspection','Completed',4),
(1006,1,2,'Audio','Headphone audio driver replacement','Completed',3),
(1007,1,1,'Diagnostics','Warranty intake inspection','Completed',4),
(1007,1,2,'Audio','Warranty audio driver replacement','In Progress',3),
(1008,1,1,'Diagnostics','Retail headset inspection','Completed',4),
(1008,1,2,'Audio','Planned retail audio driver replacement','Planned',3),
(1009,1,1,'Diagnostics','Corporate headset inspection','Completed',4),
(1009,1,2,'Audio','Corporate audio driver replacement','In Progress',3);

INSERT INTO diagnostic_assessment VALUES
(1001,1,1,88.00,'Clear','OLED-01','Replace display assembly',204),
(1002,1,1,62.00,'Clear','BAT-03','Replace battery',204),
(1003,1,1,79.00,'Liquid Damage','LCD-12','Clean connector and replace display',204),
(1004,1,1,90.00,'Clear','TOUCH-02','Replace touch panel',204),
(1005,1,1,85.00,'Tripped','OLED-01','Replace screen assembly',204),
(1005,2,1,72.00,'Clear','PORT-09','Repair charging port',204),
(1006,1,1,NULL,'Tripped','AUD-07','Replace audio driver after moisture cleaning',204),
(1007,1,1,NULL,'Tripped','AUD-07','Replace failed driver under warranty',204),
(1008,1,1,NULL,'Clear','AUD-05','Replace left audio driver',204),
(1009,1,1,NULL,'Clear','AUD-06','Replace right audio driver',204);

INSERT INTO work_session VALUES
(1,'2026-10-02 09:30:00','2026-10-02 10:00:00',30,204,1001,1,1,55.00),
(2,'2026-10-02 10:15:00','2026-10-02 12:15:00',120,201,1001,1,2,72.00),
(3,'2026-10-05 10:30:00','2026-10-05 11:00:00',30,204,1002,1,1,55.00),
(4,'2026-10-05 11:15:00','2026-10-05 12:15:00',60,203,1002,1,2,62.00),
(5,'2026-10-08 11:15:00','2026-10-08 11:45:00',30,204,1003,1,1,55.00),
(6,'2026-10-08 12:00:00','2026-10-08 15:15:00',195,201,1003,1,2,72.00),
(7,'2026-10-11 14:45:00','2026-10-11 15:15:00',30,204,1004,1,1,55.00),
(8,'2026-10-11 15:30:00','2026-10-11 17:30:00',120,201,1004,1,2,72.00),
(9,'2026-10-13 09:15:00','2026-10-13 09:45:00',30,204,1005,1,1,55.00),
(10,'2026-10-13 10:00:00','2026-10-13 11:45:00',105,201,1005,1,2,72.00),
(11,'2026-10-13 09:50:00','2026-10-13 10:20:00',30,204,1005,2,1,55.00),
(12,'2026-10-13 10:30:00','2026-10-13 12:30:00',120,203,1005,2,2,62.00),
(13,'2026-10-09 16:00:00','2026-10-09 16:30:00',30,204,1006,1,1,55.00),
(14,'2026-10-09 16:45:00','2026-10-09 18:15:00',90,201,1006,1,2,72.00),
(15,'2026-10-16 09:00:00','2026-10-16 09:30:00',30,204,1007,1,1,55.00),
(16,'2026-10-16 09:45:00','2026-10-16 10:45:00',60,202,1007,1,2,68.00),
(17,'2026-10-17 13:40:00','2026-10-17 14:10:00',30,204,1008,1,1,55.00),
(18,'2026-10-17 08:30:00','2026-10-17 09:00:00',30,204,1009,1,1,55.00),
(19,'2026-10-17 09:15:00','2026-10-17 10:30:00',75,202,1009,1,2,68.00);

INSERT INTO parts VALUES
('DISP-001','Aster X OLED assembly',125.00,4,4,'Displays'),
('DISP-002','Meridian M One display assembly',130.00,8,3,'Displays'),
('BAT-001','Aster X replacement battery',45.00,5,5,'Batteries'),
('PORT-001','Aster Tab 11 charging port',35.00,4,4,'Flex Cables'),
('AUD-001','Sonic Max premium audio driver',80.00,3,20,'Audio Drivers'),
('AUD-002','Sonic Max standard audio driver',65.00,10,4,'Audio Drivers');

INSERT INTO billing_statement (ticket_id,billing_date,promotional_discount,applicable_tax_rates,current_payment_status) VALUES
(1001,'2026-10-03',10.00,0.0900,'Paid'),
(1002,'2026-10-06',0.00,0.0900,'Paid'),
(1003,'2026-10-09',0.00,0.0900,'Paid'),
(1004,'2026-10-12',5.00,0.0900,'Paid'),
(1005,'2026-10-14',20.00,0.0900,'Paid'),
(1006,'2026-10-10',0.00,0.0900,'Paid');
INSERT INTO warranty_claim
(original_ticket_id,claim_no,original_item_no,submission_date,fault_description,review_status,requested_remedy,approved_remedy) VALUES
(1003,1,1,'2026-10-18','Display flickers again after liquid-exposure repair','Under Review',180.00,NULL),
(1003,2,1,'2026-10-19','Additional refund request for the same display repair','Rejected',90.00,NULL),
(1005,1,2,'2026-10-20','Tablet charging fault recurs','Under Review',50.00,NULL),
(1006,1,1,'2026-10-15','Headphones again lose audio after original repair','Approved',140.00,120.00);
UPDATE service_ticket SET claim_original_ticket_id=1006, claim_no=1 WHERE ticket_id=1007;

-- The insert trigger fills locked_unit_price and decrements parts.current_quantity.
INSERT INTO part_component
(ticket_id,item_no,procedure_no,component_no,part_code,date_assigned,locked_unit_price,quantity_used) VALUES
(1001,1,2,1,'DISP-001','2026-10-02 10:15:00',0,1),
(1002,1,2,1,'BAT-001','2026-10-05 11:15:00',0,1),
(1003,1,2,1,'DISP-002','2026-10-08 12:00:00',0,1),
(1004,1,2,1,'DISP-002','2026-10-11 15:30:00',0,1),
(1005,1,2,1,'DISP-001','2026-10-13 10:00:00',0,1),
(1005,2,2,1,'PORT-001','2026-10-13 10:30:00',0,1),
(1006,1,2,1,'AUD-002','2026-10-09 16:45:00',0,1),
(1007,1,2,1,'AUD-001','2026-10-16 09:45:00',0,1),
(1009,1,2,1,'AUD-001','2026-10-17 09:15:00',0,1);

INSERT INTO supplier VALUES
(1,'CircuitSource Pte Ltd','sales@circuitsource.example.test','+65 6000 1100','Net 30'),
(2,'MobileParts Asia','orders@mobileparts.example.test','+65 6000 2200','Credit 45 days');
INSERT INTO purchase_order VALUES
(1,500,'2026-10-15','2026-10-25','Shipped',720.00),
(2,501,'2026-10-16','2026-10-26','Pending',340.00);
INSERT INTO restock_request VALUES
('AUD-001',1,'2026-10-17 11:00:00',25,'Pending',NULL,NULL,301),
('BAT-001',1,'2026-10-14 14:00:00',20,'Ordered',1,500,301),
('DISP-001',1,'2026-10-14 15:00:00',10,'Ordered',1,500,301),
('PORT-001',1,'2026-10-16 10:00:00',10,'Ordered',2,501,301);

-- Calculate invoice payments from
-- separately aggregated labor and parts to avoid work-session x part fan-out.
UPDATE billing_statement b
JOIN (
  SELECT x.ticket_id, ROUND((x.labor_total + x.parts_total - b2.promotional_discount)
    * (1 + b2.applicable_tax_rates), 2) AS invoice_total
  FROM (
    SELECT st.ticket_id,
      COALESCE((SELECT SUM(ws.billable_hours_minutes * ws.locked_billing_rate / 60)
                FROM work_session ws WHERE ws.ticket_id=st.ticket_id),0) AS labor_total,
      COALESCE((SELECT SUM(pc.quantity_used * pc.locked_unit_price)
                FROM part_component pc WHERE pc.ticket_id=st.ticket_id),0) AS parts_total
    FROM service_ticket st
  ) x JOIN billing_statement b2 ON b2.ticket_id=x.ticket_id
) totals ON totals.ticket_id=b.ticket_id
SET b.amount_paid=totals.invoice_total;

-- Ticket 1005 contains two device categories and is only half paid. Query B2
-- includes its full labor and parts charges under assumption A26; the partial
-- payment separately exercises balance and payment-status validation.
UPDATE billing_statement
SET amount_paid=ROUND(amount_paid/2,2), current_payment_status='Partial'
WHERE ticket_id=1005;

COMMIT;

-- Sanity snapshots after seeding.
SELECT 'tables' AS measure, COUNT(*) AS value FROM information_schema.tables
 WHERE table_schema='techpulse' AND table_type='BASE TABLE';
SELECT part_code, selling_price, current_quantity, min_reorder_threshold
 FROM parts WHERE part_code='AUD-001';
SELECT ticket_id,item_no,procedure_no,part_code,locked_unit_price FROM part_component
 WHERE part_code='AUD-001' ORDER BY ticket_id;
