-- TechPulse schema, MySQL 8.0.16+.
-- Run on a fresh server/schema: mysql < 01_schema.sql
CREATE DATABASE techpulse CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE techpulse;

CREATE TABLE client (
  client_id INT PRIMARY KEY,
  client_name VARCHAR(150) NOT NULL,
  contact_details VARCHAR(150) NOT NULL,
  email VARCHAR(254) NOT NULL,
  address VARCHAR(300) NOT NULL,
  creation_date DATE NOT NULL,
  client_type VARCHAR(20) NOT NULL,
  CONSTRAINT chk_client_type CHECK (client_type IN ('Individual','Corporate'))
);

CREATE TABLE device_catalog (
  manufacturer_name VARCHAR(100) NOT NULL,
  model_name VARCHAR(100) NOT NULL,
  warranty_duration INT UNSIGNED NOT NULL COMMENT 'Manufacturer warranty in months',
  device_category VARCHAR(30) NOT NULL,
  PRIMARY KEY (manufacturer_name, model_name),
  CONSTRAINT chk_device_category CHECK (device_category IN ('Smartphone','Tablet','Smartwatch','Earbuds','Headphones'))
);

CREATE TABLE device (
  serial_number VARCHAR(80) PRIMARY KEY,
  IMEI VARCHAR(32) NULL,
  color VARCHAR(40) NOT NULL,
  storage_capacity INT UNSIGNED NULL COMMENT 'GB; NULL for devices without storage specification',
  client_id INT NOT NULL,
  manufacturer_name VARCHAR(100) NOT NULL,
  model_name VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_device_imei (IMEI),
  CONSTRAINT fk_device_client FOREIGN KEY (client_id) REFERENCES client(client_id),
  CONSTRAINT fk_device_catalog FOREIGN KEY (manufacturer_name, model_name)
    REFERENCES device_catalog(manufacturer_name, model_name)
);

CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  employee_name VARCHAR(150) NOT NULL
);
CREATE TABLE clerk (
  employee_id INT PRIMARY KEY,
  CONSTRAINT fk_clerk_employee FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);
CREATE TABLE technician (
  employee_id INT PRIMARY KEY,
  primary_specialisation VARCHAR(50) NOT NULL,
  certification_level VARCHAR(50) NOT NULL,
  billing_rate DECIMAL(10,2) NOT NULL COMMENT 'Currency units per hour',
  CONSTRAINT chk_technician_rate CHECK (billing_rate >= 0),
  CONSTRAINT fk_technician_employee FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);
CREATE TABLE inventory_manager (
  employee_id INT PRIMARY KEY,
  CONSTRAINT fk_inventory_manager_employee FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);
CREATE TABLE workshop_manager (
  employee_id INT PRIMARY KEY,
  CONSTRAINT fk_workshop_manager_employee FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);

CREATE TABLE work_station (
  station_id INT PRIMARY KEY,
  station_name VARCHAR(120) NOT NULL,
  occupancy_status VARCHAR(20) NOT NULL,
  CONSTRAINT chk_station_status CHECK (occupancy_status IN ('Occupied','Free','Maintenance'))
);
CREATE TABLE manage (
  manager_employee_id INT NOT NULL,
  station_id INT NOT NULL,
  PRIMARY KEY (manager_employee_id, station_id),
  CONSTRAINT fk_manage_manager FOREIGN KEY (manager_employee_id) REFERENCES workshop_manager(employee_id),
  CONSTRAINT fk_manage_station FOREIGN KEY (station_id) REFERENCES work_station(station_id)
);

CREATE TABLE service_ticket (
  ticket_id INT PRIMARY KEY,
  date_received DATETIME NOT NULL,
  current_status VARCHAR(30) NOT NULL,
  client_id INT NOT NULL,
  clerk_employee_id INT NOT NULL,
  claim_original_ticket_id INT NULL,
  claim_no INT NULL,
  CONSTRAINT chk_ticket_status CHECK (current_status IN ('Received','Diagnosing','In Progress','Ready for Pickup','Completed','Cancelled')),
  CONSTRAINT chk_claim_pair CHECK ((claim_original_ticket_id IS NULL AND claim_no IS NULL) OR (claim_original_ticket_id IS NOT NULL AND claim_no IS NOT NULL)),
  CONSTRAINT fk_ticket_client FOREIGN KEY (client_id) REFERENCES client(client_id),
  CONSTRAINT fk_ticket_clerk FOREIGN KEY (clerk_employee_id) REFERENCES clerk(employee_id)
);

CREATE TABLE service_item (
  ticket_id INT NOT NULL,
  item_no INT NOT NULL,
  device_condition VARCHAR(300) NOT NULL,
  description TEXT NOT NULL COMMENT 'Device-specific reported issue',
  repair_cost DECIMAL(10,2) NOT NULL COMMENT 'Estimated repair cost for this item',
  serial_number VARCHAR(80) NOT NULL,
  PRIMARY KEY (ticket_id, item_no),
  UNIQUE KEY uq_ticket_device (ticket_id, serial_number),
  CONSTRAINT chk_item_no CHECK (item_no > 0),
  CONSTRAINT chk_item_repair_cost CHECK (repair_cost >= 0),
  CONSTRAINT fk_item_ticket FOREIGN KEY (ticket_id) REFERENCES service_ticket(ticket_id),
  CONSTRAINT fk_item_device FOREIGN KEY (serial_number) REFERENCES device(serial_number)
);

CREATE TABLE repair_procedure (
  ticket_id INT NOT NULL,
  item_no INT NOT NULL,
  procedure_no INT NOT NULL,
  procedure_type VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  procedure_status VARCHAR(20) NOT NULL,
  station_id INT NOT NULL,
  PRIMARY KEY (ticket_id, item_no, procedure_no),
  CONSTRAINT chk_procedure_no CHECK (procedure_no > 0),
  CONSTRAINT chk_procedure_type CHECK (procedure_type IN ('Diagnostics','Display','Battery','Audio','Wearables')),
  CONSTRAINT chk_procedure_status CHECK (procedure_status IN ('Planned','In Progress','Completed','Cancelled')),
  CONSTRAINT fk_procedure_item FOREIGN KEY (ticket_id,item_no) REFERENCES service_item(ticket_id,item_no),
  CONSTRAINT fk_procedure_station FOREIGN KEY (station_id) REFERENCES work_station(station_id)
);

CREATE TABLE diagnostic_assessment (
  ticket_id INT NOT NULL,
  item_no INT NOT NULL,
  procedure_no INT NOT NULL,
  battery_health_percentage DECIMAL(5,2) NULL,
  liquid_damage_indicator_status VARCHAR(30) NOT NULL,
  error_code VARCHAR(50) NULL,
  recommended_action TEXT NOT NULL,
  technician_employee_id INT NOT NULL,
  PRIMARY KEY (ticket_id, item_no),
  CONSTRAINT chk_battery_health CHECK (battery_health_percentage IS NULL OR battery_health_percentage BETWEEN 0 AND 100),
  CONSTRAINT chk_liquid_status CHECK (liquid_damage_indicator_status IN ('Clear','Liquid Damage','Tripped','Not Applicable')),
  CONSTRAINT fk_assessment_item FOREIGN KEY (ticket_id,item_no) REFERENCES service_item(ticket_id,item_no),
  CONSTRAINT fk_assessment_procedure FOREIGN KEY (ticket_id,item_no,procedure_no)
    REFERENCES repair_procedure(ticket_id,item_no,procedure_no),
  CONSTRAINT fk_assessment_technician FOREIGN KEY (technician_employee_id) REFERENCES technician(employee_id)
);

CREATE TABLE work_session (
  session_id INT PRIMARY KEY,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  billable_hours_minutes INT UNSIGNED NOT NULL COMMENT 'Actual billable duration in minutes',
  technician_employee_id INT NOT NULL,
  ticket_id INT NOT NULL,
  item_no INT NOT NULL,
  procedure_no INT NOT NULL,
  locked_billing_rate DECIMAL(10,2) NOT NULL COMMENT 'Hourly rate at time of work',
  CONSTRAINT chk_session_time CHECK (end_time > start_time),
  CONSTRAINT chk_session_minutes CHECK (billable_hours_minutes > 0 AND
    billable_hours_minutes <= TIMESTAMPDIFF(MINUTE,start_time,end_time)),
  CONSTRAINT chk_session_rate CHECK (locked_billing_rate >= 0),
  CONSTRAINT fk_session_technician FOREIGN KEY (technician_employee_id) REFERENCES technician(employee_id),
  CONSTRAINT fk_session_procedure FOREIGN KEY (ticket_id,item_no,procedure_no)
    REFERENCES repair_procedure(ticket_id,item_no,procedure_no)
);

CREATE TABLE parts (
  part_code VARCHAR(40) PRIMARY KEY,
  item_description VARCHAR(250) NOT NULL,
  selling_price DECIMAL(10,2) NOT NULL,
  current_quantity INT UNSIGNED NOT NULL,
  min_reorder_threshold INT UNSIGNED NOT NULL,
  part_category VARCHAR(50) NOT NULL,
  CONSTRAINT chk_part_price CHECK (selling_price >= 0),
  CONSTRAINT chk_reorder_threshold CHECK (min_reorder_threshold > 0)
);

CREATE TABLE part_component (
  ticket_id INT NOT NULL,
  item_no INT NOT NULL,
  procedure_no INT NOT NULL,
  component_no INT NOT NULL,
  part_code VARCHAR(40) NOT NULL,
  date_assigned DATETIME NOT NULL,
  locked_unit_price DECIMAL(10,2) NOT NULL,
  quantity_used INT UNSIGNED NOT NULL,
  PRIMARY KEY (ticket_id,item_no,procedure_no,component_no),
  CONSTRAINT chk_component_no CHECK (component_no > 0),
  CONSTRAINT chk_quantity_used CHECK (quantity_used > 0),
  CONSTRAINT chk_locked_price CHECK (locked_unit_price >= 0),
  CONSTRAINT fk_component_procedure FOREIGN KEY (ticket_id,item_no,procedure_no)
    REFERENCES repair_procedure(ticket_id,item_no,procedure_no),
  CONSTRAINT fk_component_part FOREIGN KEY (part_code) REFERENCES parts(part_code)
);

CREATE TABLE supplier (
  supplier_id INT PRIMARY KEY,
  supplier_name VARCHAR(150) NOT NULL,
  email VARCHAR(254) NOT NULL,
  phone_number VARCHAR(50) NOT NULL,
  payment_terms VARCHAR(100) NOT NULL
);
CREATE TABLE purchase_order (
  supplier_id INT NOT NULL,
  order_id INT NOT NULL,
  order_date DATE NOT NULL,
  delivery_date DATE NOT NULL,
  order_status VARCHAR(20) NOT NULL,
  total_order_cost DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (supplier_id,order_id),
  CONSTRAINT chk_order_status CHECK (order_status IN ('Pending','Shipped','Received','Cancelled')),
  CONSTRAINT chk_delivery_date CHECK (delivery_date >= order_date),
  CONSTRAINT chk_order_cost CHECK (total_order_cost >= 0),
  CONSTRAINT fk_order_supplier FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id)
);
CREATE TABLE restock_request (
  part_code VARCHAR(40) NOT NULL,
  request_no INT NOT NULL,
  request_time DATETIME NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  status VARCHAR(20) NOT NULL,
  supplier_id INT NULL,
  order_id INT NULL,
  inventory_manager_employee_id INT NOT NULL,
  PRIMARY KEY (part_code,request_no),
  CONSTRAINT chk_request_no CHECK (request_no > 0),
  CONSTRAINT chk_request_quantity CHECK (quantity > 0),
  CONSTRAINT chk_request_status CHECK (status IN ('Pending','Ordered','Received','Cancelled')),
  CONSTRAINT chk_request_order_pair CHECK (
    (supplier_id IS NULL AND order_id IS NULL) OR
    (supplier_id IS NOT NULL AND order_id IS NOT NULL)),
  CONSTRAINT fk_request_part FOREIGN KEY (part_code) REFERENCES parts(part_code),
  CONSTRAINT fk_request_order FOREIGN KEY (supplier_id,order_id)
    REFERENCES purchase_order(supplier_id,order_id),
  CONSTRAINT fk_request_manager FOREIGN KEY (inventory_manager_employee_id)
    REFERENCES inventory_manager(employee_id)
);

CREATE TABLE billing_statement (
  ticket_id INT PRIMARY KEY,
  billing_date DATE NOT NULL,
  promotional_discount DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT 'Fixed currency amount',
  applicable_tax_rates DECIMAL(5,4) NOT NULL DEFAULT 0 COMMENT 'Fraction, e.g. 0.0900 = 9%',
  current_payment_status VARCHAR(20) NOT NULL,
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'Cash received toward the statement; needed to calculate balance due',
  CONSTRAINT chk_amount_paid CHECK (amount_paid >= 0),
  CONSTRAINT chk_discount CHECK (promotional_discount >= 0),
  CONSTRAINT chk_tax CHECK (applicable_tax_rates BETWEEN 0 AND 1),
  CONSTRAINT chk_payment_status CHECK (current_payment_status IN ('Unpaid','Partial','Paid')),
  CONSTRAINT fk_bill_ticket FOREIGN KEY (ticket_id) REFERENCES service_ticket(ticket_id)
);
CREATE TABLE warranty_claim (
  original_ticket_id INT NOT NULL,
  claim_no INT NOT NULL,
  original_item_no INT NOT NULL COMMENT 'Claimed service item within the original billed ticket',
  submission_date DATE NOT NULL,
  fault_description TEXT NOT NULL,
  review_status VARCHAR(20) NOT NULL,
  requested_remedy DECIMAL(10,2) NOT NULL COMMENT 'Payout amount requested at submission, including rejected claims',
  approved_remedy DECIMAL(10,2) NULL DEFAULT NULL COMMENT 'NULL until approved or if rejected; 0 for approved non-cash repair',
  PRIMARY KEY (original_ticket_id,claim_no),
  CONSTRAINT chk_claim_no CHECK (claim_no > 0),
  CONSTRAINT chk_claim_status CHECK (review_status IN ('Under Review','Approved','Rejected')),
  CONSTRAINT chk_requested_remedy CHECK (requested_remedy >= 0),
  CONSTRAINT chk_approved_remedy CHECK (
    (review_status IN ('Under Review','Rejected') AND approved_remedy IS NULL) OR
    (review_status = 'Approved' AND approved_remedy IS NOT NULL AND approved_remedy >= 0)),
  CONSTRAINT fk_claim_bill FOREIGN KEY (original_ticket_id) REFERENCES billing_statement(ticket_id),
  CONSTRAINT fk_claim_item FOREIGN KEY (original_ticket_id,original_item_no)
    REFERENCES service_item(ticket_id,item_no)
);
ALTER TABLE service_ticket
  ADD CONSTRAINT fk_ticket_claim FOREIGN KEY (claim_original_ticket_id,claim_no)
  REFERENCES warranty_claim(original_ticket_id,claim_no);

-- Audit-safe rate and price snapshots.
DELIMITER //
CREATE TRIGGER bi_work_session BEFORE INSERT ON work_session FOR EACH ROW
BEGIN
  SET NEW.locked_billing_rate = (SELECT billing_rate FROM technician WHERE employee_id = NEW.technician_employee_id);
END//
CREATE TRIGGER bu_work_session BEFORE UPDATE ON work_session FOR EACH ROW
BEGIN
  IF NEW.locked_billing_rate <> OLD.locked_billing_rate THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Historical work-session billing rate is immutable';
  END IF;
END//
CREATE TRIGGER bi_part_component BEFORE INSERT ON part_component FOR EACH ROW
BEGIN
  DECLARE v_on_hand INT UNSIGNED;
  DECLARE v_reorder INT UNSIGNED;
  DECLARE v_price DECIMAL(10,2);
  DECLARE v_client_type VARCHAR(20);
  DECLARE v_claim_ticket INT;
  SELECT current_quantity, min_reorder_threshold, selling_price
    INTO v_on_hand, v_reorder, v_price
    FROM parts WHERE part_code = NEW.part_code FOR UPDATE;
  SELECT c.client_type, st.claim_original_ticket_id
    INTO v_client_type, v_claim_ticket
    FROM service_ticket st JOIN client c ON c.client_id = st.client_id
    WHERE st.ticket_id = NEW.ticket_id;
  IF v_on_hand IS NULL OR v_on_hand < NEW.quantity_used THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock';
  END IF;
  IF v_on_hand * 5 < v_reorder
     AND v_client_type <> 'Corporate' AND v_claim_ticket IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Low-stock parts reserved for corporate or warranty jobs';
  END IF;
  SET NEW.locked_unit_price = v_price;
END//
CREATE TRIGGER ai_part_component AFTER INSERT ON part_component FOR EACH ROW
BEGIN
  UPDATE parts SET current_quantity = current_quantity - NEW.quantity_used
    WHERE part_code = NEW.part_code;
END//
CREATE TRIGGER bu_part_component BEFORE UPDATE ON part_component FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Part allocations are immutable; add a correcting transaction';
END//
CREATE TRIGGER bd_part_component BEFORE DELETE ON part_component FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Part allocations are immutable; add a correcting transaction';
END//
DELIMITER ;
