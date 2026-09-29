# Sohoj Academy ERP — Architecture Reset: No Business Versioning

Status: active architecture direction, 2026-09-29.

## Decision

Sohoj Academy will not use business version-control models as the normal way to operate the ERP.

A user edits the current record. Saving changes the current state. The interface does not ask users to publish Version 2, retire Version 1, create a new policy version, or choose among historical versions for routine work.

This applies across the application, not only Fee Plans.

The system still keeps an immutable audit trail and preserves the historical business facts that legally or financially need to remain reconstructable. History is evidence, not a parallel version-management workflow.

## Core rules

1. One current record per business object where the domain requires one current record.
2. Edit means edit. Normal configuration changes update the current record.
3. No publish-to-supersede workflow for ordinary master/configuration records.
4. No user-facing Version N language for operational records.
5. Audit is separate from the record: actor, timestamp, action, reason, before/after data and correlation ID.
6. Finalized transactions are not rewritten. Financial postings use reversal, refund, adjustment or compensating entries.
7. Historical interpretation uses snapshots/effective facts where required, not a general version-control UI.
8. Approval is a workflow state, not a versioning system.
9. Archive/inactivate replaces destructive deletion for referenced master data.
10. Business configuration is editable directly by authorized management.

## Domain architecture

### Experience layer
Role-specific workspaces: Admin, Operator, Teacher, and future Student/Guardian portals.
The UI is task-first and exposes current records, pending work, approvals and audit/history only where useful.

### Workflow layer
Business workflows remain explicit: Prospect → Admission → Billing → Payment → Enrollment; Teacher draft → submission → admin review → finalization; Discount/adjustment → approval → financial application; Asset request → approval → purchase → receipt → settlement.
A workflow may retain snapshots of submitted/finalized facts. That does not create a user-managed version-control model.

### Domain layer
Canonical current records include students, guardians, prospects, academic directory, programmes, offerings, batches, Fee Plans, fee components, staff, teaching assignments, attendance, assessments, question papers, class logs, charges/invoices, payments, receipts, refunds, adjustments, assets, vendors, procurement and operating settings.

### Integrity layer
Owns RLS, permissions, validation, approvals, database constraints, concurrency/idempotency, audit events, reversal/void rules and historical snapshots required by finalized transactions. It does not expose business version creation/retirement as the default integrity mechanism.

### Intelligence layer
Dashboards read canonical current data plus finalized historical events for acquisition, enrollment, attendance, academic coverage, dues, collections, compensation, profitability and operational exceptions.

### Platform layer
Next.js + Supabase/Postgres + authentication + PWA/offline + notifications + observability + backups + integrations.

## Fee Plan architecture

The business concept is Programme Offering → Current Fee Plan → Fee Components.
There is one editable standard Fee Plan for an offering.

Fee Plan editing: select offering; load current charges; edit billing cycle/due rule/effective date; edit/add/remove components; enter a reason; save; audit before/after values.

There is no Version 1 / Version 2, publish-new-version, retire-old-version, next-version date validation, or published-version register.

Admission reads the current Fee Plan and creates the student's financial facts from it. Once a charge/invoice is finalized, that finalized transaction retains the fee terms/snapshot required to explain the amount later.

## Operating rules

Settings such as batch capacity, admission activation rules, billing defaults and compensation percentages are current editable settings.
When a finalized transaction depends on a setting, the transaction stores the relevant values needed to explain its calculation. The settings screen remains simple: edit the current rule and save.

## Academic planning

Academic plans can be edited while they are drafts/current working plans.
Once a teacher/admin submission is finalized, the submitted/finalized snapshot is retained for audit and correction history. The user does not manage Plan Version 1, Plan Version 2, etc.

## Public programme content

Programme public content is part of the current Programme Offering.
Editing public content updates the current offering. Approval/publication status is a workflow state, not a content-version management UI.
If the product later needs legal publication snapshots, those snapshots are internal historical evidence and must not become a user-facing version-control model.

## Historical data

History is modeled through audit_events, before/after payloads, immutable financial records, approval records, finalized workflow snapshots and effective dates when a date is itself a business fact.
History answers: who changed it, when, what was it before, what is it now, why was it changed, and which workflow caused the change.
It does not require users to maintain parallel versions.

## API/domain naming

New application APIs should use current-state language: saveFeePlan, getFeePlan, updateOperatingRule, saveProgrammeOffering, updateProgrammePublicContent, submitTeacherWork and approveTeacherWork.
Avoid new APIs named publishFeePlan, createFeePlanVersion, retireFeePlanVersion, createPolicyVersion, publishPolicyVersion or createPublicContentVersion.
Legacy database objects may remain temporarily during migration, but they are compatibility internals only and must not leak into the product vocabulary.

## Migration strategy

Phase 1 — Contract: adopt this document as the architecture authority; remove versioning terminology from product/docs/UI; define current-state domain contracts.
Phase 2 — Database: introduce canonical current-state tables where legacy version tables exist; migrate current active data; preserve finalized transaction snapshots and audit events; replace application RPCs with current-state commands; remove legacy version tables/functions after dependent workflows are migrated.
Phase 3 — Application: replace version-oriented actions, schemas, queries and components; remove version selectors and version lists; make edit/save the primary command; keep approval/reversal/archive where the domain requires it.
Phase 4 — Verification: no user-facing Version N terminology; no routine publish/retire flow; current edits persist; historical finalized transactions remain explainable; audit is complete; RLS, concurrency and idempotency remain enforced; admission always receives the current Fee Plan; teacher submissions still require admin approval.

## Non-goals

Removing business versioning does not mean deleting audit history, rewriting posted payments, deleting finalized invoices, bypassing approval, allowing unauthorized edits, removing concurrency protection, or losing the original facts of a finalized workflow.

The goal is simpler operation with stronger traceability: edit the current thing, approve the workflows that need approval, and preserve evidence automatically.