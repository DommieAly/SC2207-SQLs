# TechPulse SQL (MySQL 8.0.16+)

This folder implements the 22 relations in **Lab3_SDAA_Team5 → Lab 5 Final → Relations, Keys and FDs**, cross-checked against `Final.drawio.pdf` and the project requirements. All sample identities, emails, phones, and device identifiers are fictional.

## Run order

Run these files **in order** on a fresh MySQL server. `01_schema.sql` creates a database named `techpulse` and intentionally fails if that database already exists, to avoid silently overwriting a real database.

```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p < 02_mock_data.sql
mysql -u root -p < 03_appendix_b_queries.sql
mysql -u root -p < 04_stock_rule_demo.sql
mysql -u root -p < 05_validation.sql
```

The stock demo creates a temporary stored procedure, tests one allowed corporate allocation and one blocked retail allocation, rolls both transactions back, then drops the procedure. It leaves mock data unchanged.

## Using these files in IntelliJ IDEA

1. Start a MySQL server, open this folder in IntelliJ IDEA, and connect to it from **View → Tool Windows → Database → + → Data Source → MySQL**. Enter the server host, port, user, and password, then use **Test Connection**. Full database tools require an IntelliJ IDEA Ultimate subscription.
2. The schema and stock demo contain MySQL client `DELIMITER` commands for triggers and a stored procedure. The reliable way to run the complete set is IntelliJ's built-in **Terminal**, using the five `mysql` commands above from this folder. Use an account allowed to create the `techpulse` database. Do this only on a fresh database; `01_schema.sql` intentionally fails if `techpulse` already exists.
3. Refresh the Database window and select the `techpulse` schema to inspect the tables. You can open `03_appendix_b_queries.sql` and execute individual queries in IntelliJ after attaching the file to the MySQL data source.

JetBrains references: [connect to MySQL](https://www.jetbrains.com/help/idea/mysql.html), [run SQL files](https://www.jetbrains.com/help/idea/run-sql-files.html).

## Files

- `01_schema.sql`: 22 tables, primary/alternate/composite keys, foreign keys, checks, immutable price/rate snapshots, and the low-stock allocation rule.
- `02_mock_data.sql`: linked example rows for every table, including a corporate batch, four smartphone tickets for one customer in one month, liquid-damage claims, a warranty return, and emergency stock allocations.
- `03_appendix_b_queries.sql`: sample SQL for Appendix B questions 1–4 and 6.
- `04_stock_rule_demo.sql`: Appendix B question 5, success and fail cases.
- `05_validation.sql`: counts, ownership, diagnostic, station, warranty, restock, payment, invoice, and price-history checks.
- `ASSUMPTION_AUDIT.md`: historical review of design tradeoffs; the final Google Doc assumptions and current SQL supersede its unresolved-item list.

## Table inventory

`client`, `device_catalog`, `device`, `employee`, `clerk`, `technician`, `inventory_manager`, `workshop_manager`, `work_station`, `manage`, `service_ticket`, `service_item`, `repair_procedure`, `diagnostic_assessment`, `work_session`, `parts`, `part_component`, `supplier`, `purchase_order`, `restock_request`, `billing_statement`, `warranty_claim`.

## Explicit implementation choices

1. The final tab's 22 relations are the baseline. The device-specific problem and initial estimate are stored only on `service_item`. `warranty_claim.original_item_no`, `warranty_claim.requested_remedy`, and `billing_statement.amount_paid` follow the updated final tab and ERD.
2. `device.serial_number` is mandatory and globally unique. `IMEI` is nullable and unique when present, because headphones and some other devices have no IMEI. `storage_capacity` is nullable and is measured in GB.
3. A service ticket belongs to one client and can contain many `service_item` rows. Item numbers are scoped to tickets. A warranty claim identifies one original service item within its billed ticket. The sample keeps the ticket client and device owner equal; this cross-table rule is checked by `05_validation.sql`, not enforced by a foreign key.
4. An initial assessment is optional until inspection; physical repair requires one. It links to a `Diagnostics` procedure. `work_session.billable_hours_minutes` is a number of **minutes**; the labor charge is minutes ÷ 60 × the locked hourly rate.
5. `parts.selling_price` is the current customer price. Insertion of a `part_component` copies that price into `locked_unit_price` and atomically deducts stock. Existing allocations cannot be updated or deleted in this first version; a production system needs a separate correcting/return transaction.
6. Emergency stock policy checks the quantity **before** allocation. If on-hand quantity is strictly below 20% of `min_reorder_threshold`, only a corporate-client ticket or a ticket linked to a warranty claim may take remaining units. Stock may never go negative. Restock requests do not reserve inventory.
7. A restock request starts with a part, quantity, time, status, and manager. `supplier_id` and `order_id` are both NULL until the request is assigned to a purchase order. The composite foreign key then identifies that order and its supplier. This follows the TA's unassigned-request example and the ERD's indirect supplier relationship.
8. `billing_statement.promotional_discount` is a fixed currency amount applied before tax; `applicable_tax_rates` is one fractional tax rate. Monetary values are in one unspecified currency. Invoice total is `(labor + parts − discount) × (1 + tax rate)`, rounded to cents. `amount_paid` makes balance due computable. Ticket 1005 is partially paid to test payment-status and balance consistency.
9. `approved_remedy` is NULL for Under Review or Rejected claims. For Approved claims it is a nonnegative refund amount, including 0 for an approved repair without cash refund. `requested_remedy` separately stores the nonnegative amount requested even on rejected claims. A CHECK constraint enforces status/value consistency.
10. Query B1 counts only completed physical procedures with less than 180 total logged billable minutes. Query B2 follows assumption A26: “revenue generated/collected” means pre-tax, pre-discount labor and parts charges on all completed tickets, regardless of payment status. It sums work-session charges and allocated-part charges separately, without using `amount_paid` or allocating discounts. Query B3 compares each physical `procedure_type` to the technician's primary specialisation and ignores diagnostic sessions.
11. The 90-day claim period starts at the original bill's `billing_date`, which the team assumes follows completion. `05_validation.sql` checks the sample claims' dates. Cross-table rules such as payment/status synchronization, same-device warranty follow-ups, and station occupancy are checked in the sample but require application transactions or additional triggers to hold for arbitrary later updates.

## Verified locally

The revised scripts were executed in sequence against a fresh temporary MySQL 9.4 instance: **22 tables**, sample rows in every table, Appendix B queries 1–6 successful, corporate low-stock allocation allowed, retail allocation blocked, and stock restored by rollback. Every integrity mismatch query returned **0**; the partial bill for ticket 1005 has a `242.52` balance. A temporary catalog price change left the historical `80.00` repair price unchanged.
