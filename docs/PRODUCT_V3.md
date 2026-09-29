# V3 product and operator workflow — Current-State Architecture

Status: active direction; revised 2026-09-29.

## Product goal
An authorized person can complete the normal task where it starts. The ERP guides decisions, explains blockers, saves the current state directly and preserves evidence automatically.
The ERP does not use business version-control as a normal operating workflow.

## Core product rule
Edit current record → Save → Audit.
Users should not have to understand database versions, publish Version 2, retire Version 1, or choose a historical version to perform ordinary work.
History is available as evidence when needed.

## Navigation by task
1. Workspace — Overview and My Tasks
2. Admissions & Students — Admissions, Students, Enquiries
3. Teaching & Academics — My Classes, Sessions & Attendance, Assessments, Question Bank, Batches
4. Finance — Student Accounts, Accounting & Settlements
5. People — Staff and teaching assignments
6. Academy Setup — Academic Directory, Programme Offerings, Fee Plans, Operating Rules, Access & Security
7. Governance — Admin Review Queue, Audit Trail

## Admission: one working page
The admission case remains the working page from intake through enrollment.
1. Identity — verify student and guardian.
2. Placement — select academic year, branch, class, offering and available batch.
3. Fee — automatically show the current Fee Plan for the selected offering.
4. Referral — select canonical referrer or Organic.
5. Consent — record the physical consent receipt.
6. Accept — confirm identity, placement, fee, referral and consent.
7. Bill and collect — post billing and record actual payment separately.
8. Enroll — evaluate the current activation rule and seat availability.
Admission never asks the operator to select a Fee Plan version.
The admission case stores the fee terms/snapshot needed to explain its finalized financial facts. Later editing of the current Fee Plan does not rewrite an already finalized charge.

## Programme Offering and Fee Plan
Programme, Programme Offering and Fee Plan are separate concepts.
A Programme describes the academic product.
A Programme Offering describes the context: academic year, branch, class, group and programme.
A Fee Plan is the current standard commercial configuration attached to an offering.
The operator can create, edit, add/remove components, change billing cycle/due day/effective date, enter a reason and save.
The operator does not publish a new version, retire an old version, compare Version 1 and Version 2, or schedule the next version.

## Teacher work and admin review
Teacher-submitted academic work uses workflow states: DRAFT → SUBMITTED → APPROVED / REJECTED → CORRECTED SUBMISSION.
Approval is required before teacher-submitted attendance, marks/results, question papers and class logs become official where configured.
Approval is not a version-management system. The submitted/finalized snapshot remains traceable for correction and audit.

## Settings
Frequently edited configuration lives in focused registers.

| Area | Current values | Change behavior |
| --- | --- | --- |
| Academy Settings | academy identity, branches, receipt/print details | edit and save with audit |
| Academic Directory | years, classes, groups, subjects, schools, programmes | edit/deactivate with audit |
| Programme Setup | offerings, batches, current Fee Plans, public content | edit/save; approval only where required |
| Operating Rules | capacity, activation, billing, compensation settings | edit current rule and save |
| Access & Security | roles, permissions, assignments | controlled edit with audit |

## Finance
Financial records are current-state workflows plus immutable finalized facts.
- Draft charges can be edited.
- Issued/finalized charges are not silently rewritten.
- Posted payments are not edited or deleted.
- Corrections use reversal, refund, adjustment or compensating records.
- Receipts exist only for posted money.
- Finalized transactions retain the terms needed to explain their calculation.

## Data integrity and traceability
Every important mutation records actor, role/permission context, entity and immutable ID, action, before/after values where meaningful, reason for sensitive changes, correlation ID and timestamp.
No destructive operational deletion is used for referenced business records.

## UX acceptance
A new employee should understand where they are, what they need to enter, why it is needed, what Save will change, what happens next and whether the action succeeded.
No screen should expose internal database version terminology.

## Engineering rule
Server Actions remain thin: UI → validation → authorization → domain command → database transaction → audit event → revalidation.
Business rules do not live inside React components.
All critical commands must be idempotent and concurrency-safe.