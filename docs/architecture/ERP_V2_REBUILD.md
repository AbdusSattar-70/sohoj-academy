# Sohoj Academy ERP v2 — Clean Rebuild Contract

This implementation follows **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1**.

## Scope boundary

Preserve:
- Public Home and branding
- Public Interest experience
- Auth / Sign-in experience
- Shared design tokens, theme system and public bilingual support
- Reusable low-level UI components that satisfy the blueprint

Rebuild:
- Supabase public business schema
- ERP dashboard/navigation
- Permission/scope model
- Settings / Control Center
- CRM / Student Bank
- Student/guardian/admission lifecycle
- Programme Offering / Fee Plan / Billing foundation
- Academic operations
- Finance/accounting
- Staff/compensation
- Assets/procurement
- Portals/PWA/intelligence layers

## Non-negotiable product constitution

1. One source of truth for every important business fact.
2. Every important action is traceable through immutable audit events.
3. No destructive operational deletion.
4. Sensitive workflows use explicit maker-checker approval where policy requires it.
5. Business rules live in domain/database layers, not React components.
6. Critical integrity is enforced in Postgres as well as application validation.
7. Canonical master data replaces repeated free-text values.
8. Financial corrections use reversal/void/adjustment rather than deletion.
9. Plan and actual academic execution are separate records.
10. Staff is the canonical person identity; Teacher is a role/assignment.
11. Dashboard ERP is English-only. Public Home, Interest and Auth support English/Bangla.
12. Light/Dark/System appearance is supported everywhere.
13. WCAG 2.2 AA is the accessibility baseline.
14. Mobile-first layouts and PWA-safe architecture are first-class requirements.
15. Mock-data and database verification are mandatory.
16. Operational values are configurable policies, never hidden hard-coded constants.
17. Seeded values are initial defaults only.
18. Policies/settings are versioned, effective-dated, reasoned and audited.
19. Historical transactions retain the exact rule/Fee Plan version that governed them.
20. Access is permission-driven; scope is explicit as the product grows.
21. Forms validate continuously while the user works.
22. Submit is disabled until valid, changed and not processing.
23. Loading/mutation state is localized to the affected section/row/button.
24. Admission, Enrollment, Billing and Payment are separate business facts.
25. A receipt is generated only for actual posted payment.
26. Unpaid obligations are invoices/charges/receivables, not “due receipts”.
27. Idempotency, locking and duplicate prevention are required for critical writes.

## Configuration and Settings Control Center

The Control Center covers:
- Organization & branches
- Academic/master data
- Programme Offerings and Fee Plans
- Admission activation policies
- Batch capacity and scheduling policies
- CRM ownership/follow-up policies
- Billing/due/discount/scholarship/payment settings
- Staff/teacher compensation and advance policies
- Approval thresholds and maker-checker rules
- Roles/permissions/scope
- Documents/numbering/templates
- Security/operations/observability/integrations

Configuration is typed and validated. Historical-impact settings are versioned rather than overwritten.

## Programme / Offering / Fee Plan model

```text
Programme
→ Programme Offering
  → Academic Year
  → Eligible Class/Group
  → Branch
  → Batch availability
→ Fee Plan Version
  → Tuition
  → Admission/exam/material charges
  → Billing cycle / due rules
```

During Admission the operator selects context; normal fee terms auto-load. The operator does not retype standard tuition/charges.

Special student terms are represented as approved Discount / Scholarship / Fee Exception records, not by overwriting the standard Fee Plan.

## Admission lifecycle

```text
PROSPECT
→ ADMISSION_DRAFT
→ ADMISSION_READY
→ ADMISSION_ACCEPTED
→ INITIAL_BILLING_POSTED
→ PENDING_PAYMENT      (only if active policy requires payment/deposit)
→ ACTIVE_ENROLLMENT
```

The activation policy is configurable.

Default policy:
- accepted admission required;
- validated student/guardian/academic placement required;
- Fee Plan/Fee Assignment required;
- initial billing must be posted;
- actual payment is not required unless the active policy says so;
- unpaid balance remains receivable;
- Active Student counts use ACTIVE enrollment only.

## Engineering shape

```text
modules/
  platform/
    auth/
    permissions/
    audit/
    approvals/
    navigation/
    master-data/
    settings/
    rules/
  dashboard/
  action-center/
  crm/
  students/
  admissions/
  academics/
    curriculum/
    routine/
    sessions/
    attendance/
    homework/
    assessments/
    coverage/
  finance/
    fee-plans/
    billing/
    payments/
    advances/
    accounting/
  staff/
    identity/
    leave/
    workload/
    compensation/
  assets/
  procurement/
```

Business workflow:

```text
UI with on-change validation
→ local readiness state
→ permission + scope check
→ domain service / transactional RPC
→ database invariant
→ idempotency/concurrency protection
→ approval when policy requires it
→ audit event + governing policy/version reference
→ targeted cache invalidation
→ local success/error state
```

## Delivery order

### Phase 0 — Platform + Dashboard Initialization
- organization/branch-ready identity
- profile + Staff identity
- permission-driven RBAC
- Settings / Control Center
- universal audit events
- approval engine
- versioned business rules
- canonical master data
- explicit dashboard route registry
- local loading/error boundaries
- shared live-validation form primitives
- CI/database verification

### Phase 1 — CRM + Student/Admission Core
- Prospect / Student Bank
- follow-up timeline and Action Center
- Schools/Areas/Sources
- Students/Guardians
- Programme Offering + Fee Plan foundation
- Admission Case state machine
- Student conversion
- initial Billing
- Enrollment activation policy

### Phase 2 — Academic Operations
- curriculum/syllabus structure
- routine templates and real sessions
- plan vs actual coverage
- attendance approval
- homework
- assessments/results approval
- leave/substitution/recovery gaps

### Phase 3 — Finance
- billing periods/charges/invoices
- payment allocation/receipts
- dues/aging
- discounts/scholarships/exceptions
- reversals/refunds/credits
- staff/vendor advances

### Phase 4 onward
Follow Master Blueprint v1.1.

## Reset policy

A destructive reset is allowed only for disposable development/staging environments and only after confirming the migration chain represents the intended v2 architecture.

```bash
pnpm exec supabase db reset --linked --no-seed
```

Never run this against production.
