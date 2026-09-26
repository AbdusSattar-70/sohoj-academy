# Sohoj Academy ERP — Implementation Guardrails

The authoritative blueprint is **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1**.

## Non-negotiable engineering rules

1. **Traceability first.** Important mutations record actor, entity, action, time, reason/context and correlation ID.
2. **No destructive business-history deletion.** Use lifecycle status, archive, revision, reversal, void, cancellation, refund or controlled anonymisation.
3. **Workflow before form.** UI mirrors the user’s business job, not raw database columns.
4. **Configuration before constants.** Batch capacity, fees, percentages, thresholds and policies are versioned configuration, not application constants.
5. **Historical pinning.** Finalized transactions retain governing policy/Fee Plan versions.
6. **No ambiguous fields.** Persistent label, Required/Optional, business-context help and field-level errors are required.
7. **Live validation.** Known invalid input is surfaced on change/blur; do not wait for full-form submission.
8. **Submit gating.** Submit is disabled until the form is valid, changed and not processing.
9. **Local pending state.** Do not replace the whole ERP shell for a button/row/section mutation.
10. **WCAG 2.2 AA.** Keyboard, focus, semantics, screen reader, contrast and touch targets are mandatory.
11. **Canonical master data.** Reusable business values are referenced by IDs; snapshots are deliberate.
12. **Programme / Offering / Fee separation.** Normal admission inherits standard charges; users do not retype them.
13. **Admission/Billing/Payment separation.** A receipt proves payment. No money received means no receipt.
14. **Business rules are versioned.** Active rules are superseded by new versions, not silently overwritten.
15. **Approval-based finalisation.** Teacher-entered attendance/results/questions and sensitive finance/operations follow submit → review → approve/reject where policy requires.
16. **Financial corrections are compensating events.** Posted money is corrected with reversal/refund/credit/adjustment.
17. **Advances are balances.** Staff/teacher/vendor/project advances remain outstanding until settlement/refund.
18. **Plan vs actual is separate.** Curriculum plan, routine, actual session, coverage and recovery remain distinguishable.
19. **Modular monolith.** Strong domain boundaries; no premature microservices.
20. **Thin Server Actions.** UI → validation → authorization → domain RPC → transaction → audit/version reference → targeted revalidation.
21. **Critical integrity belongs in Postgres too.**
22. **Idempotency/concurrency protection is mandatory** for payments, capacity, numbering, allocation and retry-prone operations.
23. **Duplicate prevention/review is a workflow**, not a silent extra insert.
24. **Mock-data/database verification is mandatory.**

## Authorization model

Effective authorization is:

```text
Role
+ Permission
+ Scope
+ active assignment/effective dates
```

Possible future scope includes OWN, ASSIGNED_BATCHES, BRANCH and ORGANIZATION.

The bootstrap ADMIN role remains protected recovery authority. Operational role permission bundles are editable by authorized admins through audited workflows.

## Admission and fee guardrail

```text
Class / Programme Offering / Batch
→ active Fee Plan Version
→ standard charges auto-loaded
→ approved exception if applicable
→ initial billing
→ activation policy
→ ACTIVE enrollment when policy conditions pass
```

A due balance may exist without a payment. A receipt may not.

## Current implementation order

### Phase 0 — Dashboard/Platform Initialization
- permission-aware shell
- route registry
- stable sidebar/header
- Action Center
- Settings / Control Center
- audit/approval/business-rule views
- local route/section loading
- live-validation form foundation
- error/correlation feedback
- CI/database verification

### Phase 1 — CRM + Student/Admission Core
- Prospect/Student Bank
- public Interest
- follow-up timeline
- master-data UX
- Programme Offering/Fee Plan
- Admission state machine
- billing + enrollment activation
- student timeline/global search

### Phase 2 — Academic Operations
- curriculum structure/versions
- routine vs actual sessions
- leave/substitution
- class log/homework/coverage recovery
- question-generation approval
- attendance/results approval
- academic-health dashboard

Subsequent phases follow Master Blueprint v1.1.

## Acceptance test

A feature is incomplete until all are true:

1. New staff can understand it without verbal explanation.
2. Management can trust its business/financial meaning.
3. An auditor can reconstruct the workflow and governing policy version.
4. Invalid actions are prevented at UI, server and database layers.
5. Operational values are configurable rather than hidden constants.
6. Loading/errors stay local to the affected interaction.
7. Concurrency, retry and duplicate risks are addressed.
8. It remains extendable without rebuilding the foundation.
