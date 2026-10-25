# TechPulse assumption audit — final Google Doc tab, ERD, and Appendices A/B

> Historical review from before the final assumptions and SQL corrections. Several recommendations below were subsequently resolved, including the unassigned restock request, NULL for a non-approved remedy, the 90-day billing-date start, and Query B2's billed-charge interpretation. Use the final Google Doc tab and executable SQL as the current specification; the items below remain useful as design tradeoffs and possible future extensions.

This is a review of the **report's current assumptions**, not a replacement for the SQL implementation. The source document is the final tab of [Lab3_SDAA_Team5](https://docs.google.com/document/d/1_Oy93OIMw2gfCPKTutT0vJ9AYLNWnxlE7FYiIEqIlAI/edit?tab=t.bhc4lknsjfio). I also checked the supplied Appendix A/B images and the one-page Final.drawio.pdf ERD. “A §” and “B Q” below refer to Appendix A's numbered requirements and Appendix B's numbered queries.

## Decisions to resolve before treating the design as final

| Priority | Issue | Why it matters | Disposition |
| --- | --- | --- | --- |
| P0 | Device identity requires both serial number and IMEI in the relation, although the requirement says “IMEI or Serial Number” | Earbuds, headphones, and many tablets have no IMEI; a mandatory globally unique serial number is itself a business assumption | Change Device constraint/FDs or use a surrogate device ID |
| P0 | A1 allows several devices per ticket, but a warranty claim references only the original ticket's billing statement | Cannot identify which original device/diagnosis/technician a claim concerns; B Q3–4 can multiply or misattribute claims | Add original service-item key to Warranty_Claim |
| P0 | Only approved_remedy is stored | B Q4 asks for **payout requested**, distinct from approved refund | Add requested payout amount; separate remedy type and approved amount |
| P0 | No payment amount or payment event exists | A §5a's net balance due and B Q2's “revenue collected” cannot be computed from Paid/Partial/Unpaid status | Add Payment or an amount-paid field with its update rules |
| P0 | No defined date starts the 90-day service warranty | The requirement mentions completed services and later pickup, but does not say whether the clock starts at completion or pickup; the current schema records neither event distinctly | State the start event and record its timestamp/date |
| P0 | ERD/relation gives station_id to a procedure, whereas A §2a assigns a station to each **active ticket** | A1's multi-device ticket may occupy several stations through different procedures. Assignment grain must be chosen explicitly | Change schema for literal ticket assignment, or explicitly document item/procedure-level reinterpretation |
| P0 | “Specialisation does not match device category” has no defined comparison | Display, Audio, and Headphones belong to different taxonomies; a string inequality is meaningless | Publish a compatibility matrix, in a table or in the query specification |
| P0 | B Q1 “took less than 180 minutes” has no agreed time measure | A procedure may have multiple sessions and span days. Sum of labor minutes and elapsed wall time give different answers | Define one measure; add procedure timestamps if wall time is intended |
| P1 | Purchase-order total is asserted to be “not computable” | The absence of agreed purchase prices makes it manually entered, not intrinsically noncomputable; its provenance and consistency are unexplained | Document manual total, or add order-line purchase-price snapshots |

## Review of the existing A1–A7 and unnumbered assumptions

| Current text | Assessment |
| --- | --- |
| **A1:** A ticket may contain several devices, each a separate service item | Sensible for a corporate batch, but creates item-level requirements for diagnosis, station allocation, parts, revenue, and claims. State that one ticket has one client and no device occurs twice on the same ticket. This also makes the ticket-level language of A §2a and §5b ambiguous. |
| **Unnumbered model-name assumption:** manufacturer_name + model_name identifies catalog row | State this as a uniqueness/identification rule rather than “only ... specifies a devices catalogue.” If manufacturers reuse a model name for variants with different warranty/category, a variant identifier is needed. |
| **A2:** At most one initial diagnostic assessment per item | Allows zero forever. A received item may have none, but a physically repaired/completed item must have one before repair starts. |
| **A3:** Inspection is itself a repair procedure; assessment documents exactly one procedure | Clarify procedure_type = INSPECTION, same item, valid assessor/work session, whether its labor is billable, and exclusion/inclusion in B Q1. It should occur before any physical repair. |
| **Unnumbered device-reuse assumption:** same device may recur in later tickets, but only once per ticket | Correct. Implement UNIQUE(ticket_id, serial_number) or its replacement device key. Explain that historical service items retain their client and model attribution even if current device ownership changes. |
| **A4:** Request has no purchase order until consolidated | Correct, but state whether supplier is already selected; order_id can be NULL while supplier_id is non-NULL. Once consolidated, one request belongs to at most one PO and all consolidated requests match its supplier. |
| **Unnumbered total_order_cost assumption:** total is “not computable” | Currently true only because the model omits procurement unit prices, freight, tax, etc. Explain whether staff manually enters and verifies it, or store prices/charges and derive it. Do not present this as a general fact about purchase orders. |
| **A5:** At most one bill per ticket | Good; specify when the bill is created, whether a completed ticket is required, whether claim repair tickets also receive a bill, and whether later line changes are forbidden or corrected separately. |
| **A6:** Warranty repair creates a new ticket linked to the claim | Specify that only approved claims lead to a repair ticket, cardinality per claim, how the original item/device is retained, and both-or-neither NULL behavior for the composite claim FK. |
| **A7:** approved_remedy stores refund value, with -1 for nonapproved claims | Replace. Negative money is a sentinel, mixes state with value, and cannot represent a noncash remedy. Use NULL for not approved, nonnegative approved_refund_amount when approved, and a separate remedy_type. Add requested_refund_amount for B Q4. |
| **Notation convention:** FKs may be NULL only when an assumption says so | A4 and A6 cover two cases. Also explicitly decide whether an unassigned procedure's station_id is NULL, whether supplier_id is known on request creation, and whether optional identifiers/diagnostic measurements are NULL. An absent IMEI is not an absent FK but still needs a rule. |

## Candidate wording for the report

The following text is deliberately phrased as assumptions the team can paste into an English report. Bracketed choices must be resolved by the team; do not leave both branches in the final submission. “Schema” flags a change needed to satisfy the stated interpretation, “Policy” can be implemented through constraints/triggers/query definitions on existing fields, and “Either” depends on the choice.

### 1. Intake, clients, devices, and ticket grain

**N01 — One customer per ticket.** “Each service ticket is submitted by exactly one client. A corporate batch is represented as one ticket containing multiple service items, all submitted by that client; items from different clients cannot share a ticket.”  
Basis/impact: A §1a–c; B Q6. Extends A1. **Policy.** This also fixes the meaning of client_type when B Q5 permits corporate jobs.

**N02 — Device identifier.** “Every physical device has a unique serial number. IMEI is optional and unique when present; it is NULL for equipment without an IMEI. Serial number is the physical-device identifier used by service items.”  
Basis/impact: A §1a lists “IMEI or Serial Number” and includes audio wearables. B Q6 lists identifiers. **Schema:** Device.IMEI must allow NULL and have uniqueness only for non-NULL values; revise the stated IMEI functional dependency/candidate-key claim. If globally unique serial numbers cannot be guaranteed, use a surrogate device_id and treat manufacturer + serial number as a candidate key after checking manufacturer reuse. The current table's two candidate-key FDs are not valid if IMEI is optional. ERD underlines serial_number alone, while the report lists both.

**N03 — One appearance per ticket.** “A device may be serviced on multiple tickets over time, but appears at most once among the service items of one ticket.”  
Basis/impact: A §1c; B Q6. Formalizes the unnumbered assumption following A3. **Policy:** unique ticket/device pair.

**N04 — Ownership at intake.** “At intake, the ticket client is the recorded owner or authorized submitting account for each included device. The service item retains that client association for historical reporting even if the device is later reassigned.”  
Basis/impact: A §1a; B Q3/6. Extends A1; prevents a later Device.client_id change from rewriting history. **Either:** prohibit transfer in this version, or snapshot ownership/history. Corporate repair on an employee-owned device needs an explicit exception if intended.

**N05 — Catalog key and units.** “A catalog model is uniquely identified by manufacturer name and model name within this project; the same pair has one device category and one manufacturer-warranty duration, measured in calendar months. Storage capacity is recorded in GB and is NULL where inapplicable.”  
Basis/impact: A §1a–b. Clarifies the unnumbered model-name assumption and Device.storage_capacity. **Policy.** If model variants have different categories or warranties, add a variant key.

**N06 — Item-level facts.** “Device.color and storage capacity describe the physical device; Service_Item.device_condition records its state at this intake; Service_Item.description is the customer-reported problem; Service_Item.repair_cost is the initial estimate, not the final charge.”  
Basis/impact: A §1a/1c/5a; A1. **Policy.** The corrected ERD and final relation both attach description and repair_cost to Service_Item. Keep them there; avoid duplicating them on Service_Ticket.

**N07 — Customer contact cardinality.** “Client.email is the primary contact email, and contact_details contains one atomic primary telephone number [or is decomposed into contact methods]. client_type is either INDIVIDUAL or CORPORATE, with client_name holding a person's or organization’s display name respectively.”  
Basis/impact: A §1a; B Q5–6. **Either.** The doc's “all values atomic” convention is incompatible with a free-form, multi-number contact_details field unless its contents are restricted.

### 2. Stations, assessments, procedures, and technicians

**N08 — Station assignment grain.** “For a ticket containing multiple devices, workstation assignment is tracked at the service-item/procedure level. Each active physical repair procedure has exactly one assigned station; the ticket may use multiple stations over its lifetime.”  
Basis/impact: A §2a; B Q1; A1. **Either.** This is a deliberate reinterpretation of “each active service ticket is assigned to a specific station.” If that requirement is literal, add a ticket-level station assignment or an assignment history instead; procedure.station_id alone cannot satisfy it.

**N09 — Station occupancy.** “A workstation is FREE, OCCUPIED, or MAINTENANCE. MAINTENANCE stations cannot be assigned new active work. OCCUPIED means at least one active scheduled procedure uses the station [or occupancy is explicitly maintained by managers]; concurrent occupancy follows the stated capacity policy.”  
Basis/impact: A §2a. **Policy/Either.** A stored status can disagree with active procedures unless synchronized. If capacity is one, enforce no overlapping active intervals or one active procedure per station.

**N10 — Diagnostic lifecycle.** “A service item can have no diagnostic assessment while awaiting inspection, but must have exactly one initial assessment before physical repair starts or the item is marked complete. No second initial assessment is created for the same item.”  
Basis/impact: A §2b; A2. **Policy.** A2's “at most one” is not enough to enforce required inspection.

**N11 — Inspection link.** “The procedure referenced by an assessment belongs to the same service item, has procedure_type = INSPECTION, and precedes physical repair. The recorded assessment technician is the technician who performed the inspection and has a corresponding work session.”  
Basis/impact: A §2b/3b; A3. **Policy.** Decide whether zero-duration/documentation-only inspection is allowed; if so, remove the corresponding-session sentence.

**N12 — Diagnostic missingness and coding.** “battery_health_percentage is between 0 and 100 when measured; battery health, liquid-indicator status and error code may be NULL when not applicable or not measured. A negative finding is an explicit value rather than NULL. Liquid indicators use controlled values including TRIPPED, and the diagnostic code identifying LIQUID_DAMAGE is published.”  
Basis/impact: A §2b; B Q4. **Policy.** This gives B Q4 a reproducible predicate and avoids treating unknown as negative.

**N13 — Procedure taxonomy and status.** “Each procedure belongs to one service item and has a controlled procedure_type. INSPECTION is distinct from physical repair types; procedure_status has explicitly defined planned, active, completed, and cancelled values. A completed procedure has its final work sessions and parts recorded.”  
Basis/impact: A §2b/3a; B Q1–3. **Policy.** Current free-text type/status can otherwise make query results unstable.

**N14 — Meaning of 180 minutes.** “For Appendix B Query 1, a procedure's time to complete is the sum of its actual billable minutes in valid work sessions. Count each completed physical repair procedure once under its assigned station and device category; exclude the initial inspection, cancelled procedures and procedures without any work session.”  
Basis/impact: A §3b; B Q1; A3. **Policy.** If “took” means wall-clock elapsed time instead, replace this wording and add procedure started_at/completed_at; multi-day gaps cannot be inferred reliably from billable time.

**N15 — Work session validity and billing rate.** “A work session belongs to exactly one technician and one procedure. end_time is later than start_time; billable_minutes is a nonnegative integer no greater than elapsed minutes. Breaks are excluded. The technician's standard hourly rate is copied into locked_billing_rate when the session starts and remains unchanged if the standard rate changes later.”  
Basis/impact: A §3a–b/5a; B Q1–2. **Policy.** The current billable_hours_minutes name has no clear numeric unit; use minutes consistently. Overlapping sessions for the same technician should be prohibited or explicitly allowed.

**N16 — Specialization comparison.** “Technician primary_specialisation, procedure domain, and device category are controlled vocabularies. Compatibility is evaluated against an explicit specialization-to-procedure/device-category mapping. A technician may work outside their primary specialization, but the mismatch is retained for quality reporting.”  
Basis/impact: A §3a; B Q3. **Either:** mapping table recommended; a fixed CASE matrix is possible if documented. Comparing ‘Display’ and ‘Headphones’ as strings is semantically invalid.

**N17 — Claim-linked mismatch count.** “For Appendix B Query 3, first identify affected clients as those with at least one warranty claim on an original billed service item whose physical repair involved an incompatible technician under N16. For each affected client, count all of that client's warranty claims, once per claim, grouped by the original claimed device's manufacturer; the counted claims need not each be mismatch-linked.”  
Basis/impact: B Q3; A1/A6. **Policy after N16 and N33.** This follows the phrase “how many total warranty claims they have filed” after identifying affected customers. If the intended count is only claims tied to mismatched jobs, replace the final sentence explicitly. Without an item-specific claim, either interpretation can falsely join work on a different batch device.

### 3. Parts, stock, requests, and orders

**N18 — Selling-price snapshot.** “Parts.selling_price is the current customer-facing unit price. When a part is assigned to a procedure, Part_Component.locked_unit_price is copied from that price and is never changed by future catalog updates; billed parts charge is quantity_used times the locked unit price.”  
Basis/impact: A §4a/4c/5a; B Q2. **Policy.** The phrase “supplier prices” in A §4c is not the same concept as the customer-facing selling price; if true supplier purchase prices are also needed, store them separately.

**N19 — Inventory unit and atomic allocation.** “Parts.current_quantity is nonnegative stock on hand in whole units. quantity_used is a positive whole number; allocation inserts the component record and decrements stock in one atomic transaction. An allocation cannot drive stock below zero, and cancelling an allocation restores exactly the same quantity once.”  
Basis/impact: A §4a; B Q5. **Policy.** Define whether returns and damaged stock are excluded or separately recorded.

**N20 — Available versus on-hand.** “For this version, available stock equals current_quantity because advance reservations are not recorded [or available stock equals on-hand less outstanding reservations, which are stored separately].”  
Basis/impact: B Q5's “available stock”; A §4a's “quantity on hand.” **Either.** A stock-protection trigger must check the same quantity that the query reports.

**N21 — Two distinct thresholds.** “A restock request is eligible when quantity on hand is at or below min_reorder_threshold. The emergency allocation threshold is separately defined as strictly less than 20% of that positive reorder threshold.”  
Basis/impact: A §4b; B Q5. **Policy.** The two conditions have different comparison operators and different business effects. Define integer boundaries using an exact comparison such as 5 × available < threshold rather than rounded percentages.

**N22 — Emergency allocation exception.** “Once stock is below the emergency threshold immediately before allocation, a component may be issued only to a corporate-client ticket or a ticket linked to an approved warranty claim. Standard individual retail tickets are blocked. The check and stock decrement are atomic.”  
Basis/impact: B Q5; A1/A6. **Policy.** Decide whether a merely submitted claim qualifies; “approved” is the safer interpretation. The success and failure examples in B Q5 should use the same part/stock level.

**N23 — Restock request and supplier selection.** “Each restock request concerns exactly one part and a positive requested quantity. An inventory manager raises it and selects a supplier at request time [or supplier remains NULL until consolidation]. Before consolidation order_id is NULL. After consolidation, a request belongs to at most one purchase order, and its supplier matches that order's supplier.”  
Basis/impact: A §4b; A4. **Either.** Select one supplier timing rule and express the composite FK's NULL behavior.

**N24 — PO amount provenance.** “The total order cost is [manually confirmed from the supplier quotation and stored as an authoritative amount / derived from immutable line-level agreed purchase unit costs, quantities and explicitly defined extra charges]. Supplier purchase prices are independent of Parts.selling_price.”  
Basis/impact: A §4b; unnumbered statement after A4. **Either.** The manual choice meets the bare ‘capture total’ requirement but cannot validate line cost or explain later price changes. The derived choice requires purchase-order line costs and possibly freight/tax fields. Do not claim total is inherently not computable.

**N25 — Receipt and expected delivery.** “Purchase_Order.delivery_date is the expected delivery date. A transition to RECEIVED increases inventory exactly once for the ordered quantities; partial receipts are [not supported / recorded as separate receipt lines with actual quantities and dates].”  
Basis/impact: A §4b. **Either.** The existing field name does not distinguish expected from actual delivery. Partial receipts require more data than the current schema has.

**N26 — Supplier contact.** “The supplier record stores one primary phone number and one primary email address; additional phone numbers are outside this version [or are stored in a child Supplier_Phone relation]. payment_terms is a controlled description of the agreed cash/credit terms.”  
Basis/impact: A §4b explicitly says “phone numbers”; current Supplier has one phone_number. **Either.** If all numbers must be retained, schema change is necessary.

### 4. Billing, payments, and warranties

**N27 — Bill generation and freeze.** “A ticket is ready for billing only after every required physical repair procedure for its items is completed or cancelled with authorization. At most one final billing statement is issued per ticket; after issue, its billable work sessions, allocated parts, tax and discount snapshots are not silently edited.”  
Basis/impact: A §5a; A5. **Policy.** A §1c's sample status list has READY_FOR_PICKUP but not COMPLETED or CLOSED; define which state means work complete and when invoice date occurs.

**N28 — Billing formula and precision.** “Labor subtotal is the sum over sessions of billable_minutes ÷ 60 × locked_billing_rate. Parts subtotal is the sum over component allocations of quantity_used × locked_unit_price. All amounts are in [currency], stored as fixed-point decimal values, and rounded to two minor-unit decimals at [line/subtotal] level.”  
Basis/impact: A §5a; B Q2. **Policy.** Choose one rounding level and currency; floats and varying rounding can change totals.

**N29 — Discount and tax.** “promotional_discount is [a fixed currency amount / a percentage] applied to [the pre-tax combined labor-and-parts subtotal]. applicable_tax_rate is the rate effective on the billing date. Tax applies to [subtotal after discount], and net invoice amount is subtotal minus discount plus tax.”  
Basis/impact: A §5a; B Q2. **Either.** Resolve the brackets. The current plural applicable_tax_rates cannot be atomic if multiple independent rates are stored in one value; use invoice tax lines if several taxes apply.

**N30 — Payments and balance.** “A payment records a strictly positive amount, time and ticket. Amount paid is the sum of settled payments; net balance due is max(0, net invoice amount minus settled payments). UNPAID, PARTIAL and PAID are derived from that balance and must remain consistent with it.”  
Basis/impact: A §5a; B Q2. **Schema:** add Payment or, for a single-payment-only design, paid_amount and paid_at. Multiple/partial payments make Payment preferable. Refunds/overpayments need their own explicit rule if supported.

**N31 — Meaning of collected category revenue.** “For Appendix B Query 2, include only completed work orders with settled payments. Allocate each ticket's collected amount among its service items in proportion to each item's final pre-tax labor-plus-parts charge; then report each item under its catalog device category, using deterministic cent rounding. Report labor and parts components separately after the same allocation rule. A zero-charge ticket contributes zero collected revenue.”  
Basis/impact: B Q2; A1/A5. **Policy after N30.** If the intended query is gross **billed** charges, not cash collected, state that clearly and do not call it revenue collected. A multi-category ticket and ticket-level payments make this choice unavoidable.

**N32 — Warranty start and period.** “For this version, the 90-day TechPulse service warranty begins on the date the customer actually collects the repaired device, recorded per service item if a batch is collected in stages. A claim submitted no later than 90 calendar days after that date is within the period; the manufacturer's model warranty is a separate concept.”  
Basis/impact: A §5b; A1/A5/A6. **Schema:** add item-level pickup date (or ticket-level pickup date only if all devices in a ticket are always collected together). This is a proposed interpretation: A §5b says the warranty is on completed services but does not specify whether its clock starts at completion or pickup. If the team chooses completion instead, record a completion timestamp and state that rule. Billing date/READY_FOR_PICKUP is not necessarily either event.

**N33 — Claim target and cardinality.** “A warranty claim references exactly one original billed service item, and its claimant is the original ticket's client. Multiple claims may be filed for the same original item, each with a claim number unique within its original ticket. A claim never references an unbilled ticket.”  
Basis/impact: A §5b; B Q3–4; A1/A5/A6. **Schema:** include original_item_no in claim FK and validate original bill. If one claim can cover multiple items, use a claim-item bridge instead; the present ticket-only reference is insufficient.

**N34 — Claim money and remedy.** “requested_refund_amount records the nonnegative payout requested at submission, independently of review outcome. review_status is UNDER_REVIEW, APPROVED, or REJECTED. approved_remedy_type identifies REFUND, REPAIR, REPLACEMENT or another supported remedy; approved_refund_amount is NULL for pending or rejected claims and zero for an approved noncash remedy.”  
Basis/impact: A §5b; B Q4; A7. **Schema:** replace the -1 sentinel; add requested amount and remedy type/amount fields. If a textual remedy is preferred, keep it separate from numeric approved value.

**N35 — Warranty repair tickets.** “Only an approved claim may create a warranty repair ticket. A rejected claim creates none, and an approved refund-only claim need not create one. A claim may generate [at most one / multiple] repair tickets. Each such ticket must include the same device as the original claimed item. Its claim FK columns are either both NULL or both non-NULL; ordinary tickets have both NULL.”  
Basis/impact: A §5b; A6. **Either.** Choose cardinality and whether warranty labor/parts are billed to the customer, internally costed, or zero-rated. A unique claim FK enforces the exactly-one maximum.

**N36 — Query 4 water-damage rule.** “Appendix B Query 4 examines the initial assessment of the original claimed service item. A claim qualifies when that assessment has liquid_damage_indicator_status = TRIPPED or error_code = LIQUID_DAMAGE. Sum requested_refund_amount, not approved_refund_amount, and count each claim once per customer.”  
Basis/impact: B Q4; A2/A6/A7. **Policy after N12/N33/N34.** This avoids mistakenly reading diagnostics from the warranty follow-up ticket or another device in the batch.

### 5. Cross-cutting query and data rules

**N37 — Repeated-order month and category.** “For Appendix B Query 6, a separate work order means a distinct ticket_id. The calendar month is based on date_received in the shop's [time zone]. A ticket with multiple device categories counts once in each category it contains; list the distinct identifiers of the items in that category on the qualifying tickets.”  
Basis/impact: B Q6; A1. **Policy.** More than three means at least four distinct tickets, not four devices on one batch ticket.

**N38 — Key scopes.** “item_no is numbered within a ticket; procedure_no within a service item; component_no within a procedure; request_no within a part; claim_no within an original ticket; and order_id within a supplier [or order_id is globally unique, with the relation key revised accordingly].”  
Basis/impact: final tab's composite keys and weak-entity decomposition. **Policy/Either.** Explicit numbering scopes make mock data and FDs coherent.

**N39 — Time and current-state history.** “All timestamps are stored in one canonical time zone and converted to the shop's local time zone for calendar-day/month reporting. Current status fields describe present state only; events such as payment, pickup and component assignment retain their own immutable times.”  
Basis/impact: A §1c/3b/4c/5b; B Q1/6. **Policy.** State a concrete zone in the final report and seed data.

**N40 — Deletion and corrections.** “Billed sessions, assigned component price snapshots, settled payments and submitted claims are retained for historical reporting. Corrections use explicit reversal or adjustment records rather than deleting referenced business events.”  
Basis/impact: A §4c/5a–b; B Q2–4. **Either.** If reversals are out of scope, state that seeded data contains no cancellations or post-billing corrections, and prevent destructive changes to historical rows.

## Schema changes versus assumption-only decisions

**Required if the team keeps A1 and answers every Appendix B query literally:**

1. Make device identity work for equipment with no IMEI, or use a surrogate physical-device key (N02).
2. Give Warranty_Claim a reference to the original service item/device, not only original ticket/bill (N33).
3. Store the claim's requested payout separately from its approved outcome (N34).
4. Store cash received to calculate “collected” revenue and net balance (N30).
5. Define whether the 90-day service warranty begins at repair completion or pickup and store that actual date/time at the appropriate grain (N32).
6. If A §2a's “each active service ticket is assigned to a specific station” is interpreted literally, add ticket-level assignment/history. If the team chooses item/procedure grain, explicitly identify that as a deviation/interpretation (N08).

**Schema changes conditional on chosen scope:** a mapping table for specialization compatibility (N16); purchase-order line prices and receipt lines if procurement totals and partial deliveries are auditable (N24–N25); multiple supplier phone numbers (N26); item-level tax/payment allocation fields if per-item cash attribution must be exact rather than algorithmic (N31); procedure timestamps if 180 minutes means elapsed wall time (N14); device ownership history if ownership transfers are in scope (N04).

**Primarily explicit assumptions, constraints, triggers or query definitions:** one client per ticket; per-ticket device uniqueness; diagnostic lifecycle; station occupancy synchronization; controlled statuses/codes; session minute/rate arithmetic; stock quantity and two thresholds; emergency allocation; bill timing, money formula, discounts/tax; warranty repair cardinality; Q3–Q6 counting rules; key numbering; currency, time zone and rounding.

## Remaining ERD and report checks

1. **Device key:** the ERD underlines serial_number, while the final relation lists both serial_number and IMEI as candidate keys. Optional IMEI cannot be a candidate key for every device; revise the report's FD/key statement.
2. **Station allocation:** the ERD places workstation assignment on repair_procedure, while Appendix A §2a says each active service ticket is assigned to a station. State the item/procedure-level interpretation explicitly, or add ticket-level assignment if the wording must be literal.
3. **Warranty reference:** Warranty_Claim is correctly supported by Billing_Statement and retains its repeated claim key. If a corporate ticket contains several devices, B Q3–4 still need a stated bill-level interpretation or a reference to the claimed Service_Item.
4. **A7 sentinel:** approved_remedy = -1 for nonapproval loses any prior requested amount unless requested payout is stored separately; it also cannot represent a noncash remedy without another field.
5. **Normalization narrative:** the final tab's Section 5 states every relation is in 3NF and no decomposition occurred. State this directly rather than implying an unshown decomposition.

**Already aligned in the corrected ERD:** description and repair_cost connect to Service_Item, consistent with the final relation and the TA feedback. Also, order_id and request_no alone are partial keys in weak-entity notation; the mapped relations can correctly use (supplier_id, order_id) and (part_code, request_no) as composite keys. These are not ERD/report contradictions.

## Suggested mock-data cases to prove the assumptions

- Individual client plus corporate client with a four-device batch; four **separate** tickets in one month for B Q6, and one multi-device ticket that must count only once.
- Smartphone with serial + IMEI; earbuds/headphones with serial and NULL IMEI; repeat the same physical device in a later ticket.
- One original multi-device ticket where only one item has a liquid-damage/TRIPPED assessment and a claim; another item has a different technician, showing why claim-to-item matters.
- Technician specialization compatible on one procedure and incompatible on another; multiple sessions on the mismatched procedure but one claim count.
- Completed procedures with total active labor of 179, 180 and 181 minutes; inspection session excluded; procedure split across two sessions/days to document chosen duration definition.
- Price update after part allocation and technician rate update after work session; old locked values remain billed.
- Restock at or below ordinary reorder threshold; at a strictly below-20% stock level, one corporate or approved-warranty allocation succeeds and a retail allocation fails without changing inventory.
- Multiple restock requests consolidated into one supplier PO, and a pending request with NULL order_id.
- Completed and billed ticket with partial payment; another with full payment; a warranty claim within 90 days of pickup, plus one on the boundary and one after it.
- Claim requesting a refund that is later rejected; an approved noncash repair remedy; an approved refund smaller than the amount requested. These are distinct rows and amounts.
