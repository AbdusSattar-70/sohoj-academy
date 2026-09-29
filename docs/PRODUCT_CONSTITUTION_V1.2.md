# Sohoj Academy ERP — Product Constitution & Master Blueprint v1.2

Status: architecture authority for the current-state ERP reset, 2026-09-29.

## North Star

Every important fact has one source of truth. Every important action is traceable. Nothing important silently disappears. The software guides the user instead of forcing the user to understand the database.

## 1. Product philosophy

Sohoj Academy ERP is a coaching-institute operating system, not a collection of disconnected forms.

- Premium but simple.
- No ambiguity.
- Traceability by default.
- No destructive operational deletion.
- Current-state business records with explicit workflow states.
- Modular monolith in Next.js + Supabase/Postgres.
- Mobile/PWA first.
- WCAG 2.2 AA accessibility baseline.
- Analytics-ready canonical data.

### Architecture reset: no business version-control model

The ERP does not use Version 1 / Version 2 as the normal operating model for Fee Plans, settings, programme public content or other editable master/configuration records.

Normal operation is:

**Edit current record → Save → Audit.**

History is retained automatically as evidence. Finalized transactions retain the facts/snapshots necessary to explain what happened.

Versioning may exist as an internal implementation detail during migration, but it is not a product concept and must not appear in user workflows.

## 2. Product architecture

### Experience
Role-specific Admin, Operator, Teacher and future Student/Guardian experiences.

### Workflow
Admission, billing, payment, attendance, assessment, academic planning, teacher review, staff work, assets, procurement and approvals.

### Domain
Students, prospects, guardians, academic directory, programmes, offerings, batches, subjects, Fee Plans, staff, payments, invoices, journals, assets and vendors.

### Integrity
Permissions, RLS, validation, approvals, audit, database constraints, idempotency, concurrency, reversal/void rules and finalized snapshots.

### Intelligence
Dashboards, alerts, conversion, retention, academic coverage, profitability, teacher compensation and management analytics.

### Platform
Next.js, Supabase/Postgres, authentication, PWA/offline, notifications, observability, backups and integrations.

## 3. Data integrity and traceability

Operational history is evidence.

Use lifecycle transitions, archive/inactivate, reversal, void, adjustment and controlled anonymisation where appropriate.

Every important mutation records:
- actor
- role/permission context
- immutable entity ID
- action
- before/after values where meaningful
- reason for sensitive changes
- correlation ID
- timestamp

Finalized financial records are not silently edited or deleted.

## 4. Admission

Admission remains a distinct workflow:

Prospect/Direct Intake → Admission Case → Acceptance → Billing → Payment → Enrollment.

The selected Programme Offering supplies the **current Fee Plan**.

Operators do not choose a Fee Plan version.

A finalized charge/invoice stores the fee facts needed to explain its amount later. Editing the current Fee Plan does not rewrite finalized financial history.

## 5. Finance

Student billing follows:

Current Fee Plan → Student Fee Assignment → Billing Period → Charge/Invoice → Payment → Allocation.

Draft records may be edited.

Posted payments and finalized financial facts are immutable. Corrections use reversal, refund, adjustment or compensating entries.

Receipts are generated only for posted money.

## 6. Fee Plan

Programme, Programme Offering and Fee Plan are separate concepts.

A Fee Plan is the current standard commercial configuration attached to an offering.

It contains:
- tuition and other components
- billing cycle
- due rules
- currency
- effective date

The normal workflow is:
1. select offering
2. load current Fee Plan
3. edit charges
4. enter reason
5. save
6. audit before/after values

There is no publish-new-version workflow.

## 7. Teacher and academic review

Teacher work that requires governance uses explicit workflow:

DRAFT → SUBMITTED → APPROVED / REJECTED → CORRECTED SUBMISSION.

Attendance, marks/results, question papers and class logs become official only after the required admin/academic review.

Approval is a workflow state, not a version-management system.

## 8. Academic planning

Curriculum plans and session plans are editable working records.

Finalized submissions retain the submitted/finalized snapshot and correction trail.

Users do not manage plan versions.

## 9. Programme public content

Public content belongs to the current Programme Offering.

Editing changes the current offering. Approval/publication is a workflow state.

If a legal or compliance snapshot is ever needed, it is retained internally as historical evidence and does not become a user-facing version system.

## 10. Configuration-first operations

Management-changeable values are current settings:
- batch capacity
- admission activation rules
- billing defaults
- discount/approval thresholds
- teacher compensation percentages
- document/communication preferences

A finalized transaction stores the relevant values needed to explain its calculation.

The settings UI edits the current rule directly.

## 11. UX standard

A new employee should understand:
1. where they are,
2. what they need to enter,
3. why it is needed,
4. what Save changes,
5. what happens next,
6. whether the action succeeded.

Every field has a persistent label. Required/optional is explicit. Errors identify the field and recovery action. High-impact actions explain impact and require reason/approval where appropriate.

No user-facing screen should expose internal version identifiers.

## 12. Permissions and approvals

Effective access is Role + Permission + Scope.

Sensitive workflows use maker-checker approval where required.

Teacher submissions require independent admin/academic review before finalization.

Bootstrap admin retains protected recovery authority.

## 13. Engineering architecture

Recommended architecture: modular monolith in Next.js + Supabase/Postgres.

Domain boundaries:
- crm
- students & admissions
- academics
- finance & accounting
- staff & compensation
- assets & procurement
- shared platform

Server Actions remain thin:

UI → validation → authorization → domain command → database transaction → audit event → revalidation.

Business formulas do not live in React components.

## 14. Reliability

Critical workflows require:
- idempotency
- transactional locking
- duplicate prevention
- concurrency-safe numbering
- targeted loading/revalidation
- conflict detection for offline work
- server-authoritative financial posting

## 15. Quality gate

Production-ready means:
- new employees can complete workflows without developer explanation
- management can trust business and financial meaning
- auditors can reconstruct changes
- invalid actions are prevented at UI, server and database layers
- finalized transactions remain explainable
- no business version-management workflow is required
- RLS and concurrency tests pass
- accessibility checks pass
- critical end-to-end flows pass

## Closing principle

Build gradually, architect deliberately.

The product should feel simple because complexity is handled by the system, not pushed onto staff.

**Edit the current thing. Approve the workflows that need approval. Preserve the evidence automatically.**
