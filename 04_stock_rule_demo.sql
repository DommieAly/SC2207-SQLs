-- Appendix B query 5: executable success and fail simulations.
-- Both inserts run in separate transactions and are rolled back, so this file
-- leaves the mock database unchanged. AUD-001 starts at 1 unit after seeding;
-- its reorder threshold is 20, and 20% of 20 is 4 units.
USE techpulse;
DELIMITER //
CREATE PROCEDURE demo_low_stock_policy()
BEGIN
  DECLARE v_success VARCHAR(255) DEFAULT 'Allowed';
  DECLARE v_failure VARCHAR(255) DEFAULT 'Unexpectedly allowed';

  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_success = MESSAGE_TEXT;
    END;
    INSERT INTO part_component
      (ticket_id,item_no,procedure_no,component_no,part_code,date_assigned,locked_unit_price,quantity_used)
      VALUES (1009,1,2,2,'AUD-001','2026-10-17 11:30:00',0,1);
  END;
  SELECT 'Corporate allocation (expected success)' AS scenario, v_success AS result,
         (SELECT current_quantity FROM parts WHERE part_code='AUD-001') AS stock_during_test;
  ROLLBACK;

  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_failure = MESSAGE_TEXT;
    END;
    INSERT INTO part_component
      (ticket_id,item_no,procedure_no,component_no,part_code,date_assigned,locked_unit_price,quantity_used)
      VALUES (1008,1,2,1,'AUD-001','2026-10-17 14:30:00',0,1);
  END;
  SELECT 'Retail allocation (expected blocked)' AS scenario, v_failure AS result,
         (SELECT current_quantity FROM parts WHERE part_code='AUD-001') AS stock_during_test;
  ROLLBACK;
END//
DELIMITER ;
CALL demo_low_stock_policy();
DROP PROCEDURE demo_low_stock_policy;
SELECT part_code,current_quantity,min_reorder_threshold
  FROM parts WHERE part_code='AUD-001';
