# ERP v2 Interaction, Workflow and Configuration Standard

This document is normative for every internal Sohoj Academy ERP module and aligns with Master Blueprint v1.1.

## 1. Configuration over hard-coded operations

Operational values must not be embedded in React components, server actions or SQL trigger fallbacks.

Examples:
- Batch capacity
- Tuition and other Fee Plan charges
- Teacher teaching-pool percentage
- Acquisition/retention bonus percentages
- Admission activation requirements
- Minimum payment/deposit rules
- Due-day rules
- Discount/scholarship thresholds
- Approval requirements/thresholds
- Role/permission bundles
- Communication/document preferences

Seed values are initial policy versions only. Changes are versioned, effective-dated, reasoned and audited.

Structural integrity is not configurable:
- immutable audit history;
- unique permanent identities;
- receipt only for actual posted payment;
- posted financial correction through reversal/adjustment;
- maker-checker separation where required;
- database authorization/RLS;
- accounting balance/integrity;
- referential integrity.

## 2. Form behavior

1. Persistent visible label for every control.
2. Required/Optional is explicit.
3. Helper text explains business meaning.
4. React Hook Form + shared Zod contract for client validation.
5. Validation uses onChange/onBlur as appropriate.
6. Cross-field rules update immediately.
7. Async uniqueness/availability checks are debounced and field-scoped.
8. Submit is disabled until required fields are satisfied, the form is valid, it is meaningfully changed and no submission is already running.
9. Server/database repeat critical validation.
10. Server errors map to a field/section where possible.
11. Sensitive actions show impact and require reason/confirmation/approval as appropriate.
12. Long workflows may support Draft + unsaved-change protection.

## 3. Loading and mutation feedback

- ERP shell stays mounted.
- Route content uses section/table/card skeletons.
- Mutations show pending state on the affected button/row/dialog/panel.
- Background refresh does not replace the whole screen.
- Invalidation/revalidation is targeted.
- Optimistic updates are used only where rollback semantics are clear.
- Long-running work becomes a tracked job.
- Financial posting remains server-authoritative.

## 4. Programme Offering and Fee inheritance

Programme, Programme Offering and Fee Plan are separate.

Normal Admission flow:

```text
Class
→ eligible Programme Offering
→ available Batch
→ active Fee Plan Version
→ automatic standard charges
→ approved discount/scholarship/fee exception
→ calculated net payable
```

Standard tuition/charges are read-only in normal Admission. A special student arrangement is represented explicitly; it does not overwrite the Programme Fee.

Fee changes create a new version. Historical billing keeps the governing version.

## 5. Admission lifecycle

```text
PROSPECT
→ ADMISSION_DRAFT
→ ADMISSION_READY
→ ADMISSION_ACCEPTED
→ BILLING_POSTED
→ PENDING_PAYMENT when active policy requires deposit/minimum payment
→ ACTIVE_ENROLLMENT
```

Default policy:
- admission accepted;
- student/guardian/academic placement valid;
- Fee Plan assigned;
- initial billing posted;
- payment not inherently required unless configured;
- unpaid balance remains receivable;
- receipt only after real payment;
- Active Student count = ACTIVE enrollment only.

## 6. State machines instead of free-form status edits

Important domains use explicit allowed transitions:
- Prospect
- Admission
- Enrollment
- Invoice/charge
- Payment
- Approval
- Attendance finalization
- Result finalization
- Staff employment
- Leave/substitution
- Advance settlement
- Procurement
- Asset lifecycle

UI shows only allowed actions; server/database recheck.

## 7. Policy-version pinning

Transactions affected by a rule store the governing version.

Examples:
- Fee Plan
- Batch capacity decision
- Admission activation
- Discount approval
- Teacher revenue share
- Acquisition/retention bonus
- Advance settlement

## 8. Concurrency, retries and duplicate prevention

- idempotency keys for retry-prone business writes;
- row locking/equivalent for capacity, payment allocation and settlement;
- unique constraints for permanent references;
- duplicate student/prospect/guardian/master-data review/merge workflows;
- double-click/retry must not duplicate payment/admission/posting events.

## 9. Settings / Control Center

Admin Control Center groups settings by:
- Organization/branches
- Master data
- Programmes/Offerings/Fee Plans
- Admissions
- Academics
- CRM
- Finance
- Staff/compensation
- Approvals
- Roles/permissions/scope
- Documents/numbering
- Communication
- Security/operations

Permission/policy changes require reason + audit event. Protected bootstrap ADMIN cannot be accidentally stripped of recovery access.

## 10. Authorization model

Effective access is Role + Permission + Scope.

Examples:
- students.view
- students.edit
- payments.post
- payments.reverse
- attendance.record
- attendance.approve
- assessments.record
- assessments.approve
- compensation.view
- compensation.manage
- audit.view
- settings.manage

Scope may grow to OWN / ASSIGNED_BATCHES / BRANCH / ORGANIZATION.

## 11. Errors and supportability

Business errors are distinct from technical failures.

Examples:
- “Selected batch is full” is a business error.
- “Unable to reach database” is a technical error.

Technical failures expose a safe correlation/reference ID for support/log tracing without exposing sensitive implementation detail.

## 12. Operational acceptance

A workflow is not production-ready until:
- new staff can understand it;
- management trusts the business meaning;
- audit can reconstruct the change and governing version;
- invalid actions are prevented at UI/server/database;
- operational values are configurable;
- loading/errors are localized;
- keyboard/screen-reader/touch use is viable;
- concurrency/retry/duplicate risks are addressed;
- mock/database/end-to-end verification passes.
