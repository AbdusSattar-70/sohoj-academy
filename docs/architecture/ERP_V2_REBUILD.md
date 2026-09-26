# Sohoj Academy ERP v2 — Clean Rebuild Contract

This branch is the clean ERP rebuild based on **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.0**.

## Scope boundary

Preserve:
- Public Home and branding
- Public Interest experience
- Auth / Sign-in experience
- Shared design tokens, theme system and public bilingual support
- Reusable low-level UI components that satisfy the blueprint

Rebuild:
- Supabase public business schema
- ERP dashboard
- ERP navigation
- ERP permissions and access context
- CRM / Student Bank
- Student and guardian lifecycle
- Admissions
- Academic operations
- Finance
- Staff and compensation
- Assets / procurement
- Accounting
- Portals / PWA / intelligence layers

## Non-negotiable product constitution

1. One source of truth for every important business fact.
2. Every important action is traceable through an immutable audit event.
3. No destructive operational deletion.
4. Sensitive workflows use explicit approval / maker-checker where applicable.
5. Business rules live in domain/database layers, not React components.
6. Critical integrity is enforced in Postgres as well as application validation.
7. Canonical master data replaces repeated free-text values.
8. Financial corrections use reversal / void / adjustment rather than deletion.
9. Plan and actual academic execution are separate records.
10. Staff is the canonical person identity; Teacher is a role/assignment.
11. Dashboard ERP is English-only. Public Home, Interest and Auth/Sign-in support English/Bangla.
12. Light / Dark / System appearance is supported everywhere.
13. WCAG 2.2 AA is the accessibility baseline.
14. Mobile-first layouts and PWA-safe architecture are first-class requirements.
15. Mock-data and database verification are mandatory before a module is operationally complete.
16. Operational values are configurable policies, not hard-coded constants. Seeded values are defaults only.
17. Settings changes are versioned, effective-dated, reasoned and audited; historical transactions retain the policy version that governed them.
18. Access is permission-based. Admin can assign roles/permissions without changing application code; the bootstrap ADMIN role itself remains a protected recovery authority.
19. Forms validate continuously while the user types. Required-field readiness, field errors and cross-field conflicts are visible before submission.
20. Submit is disabled until the form is valid, changed and not already processing.
21. Mutations expose local pending state (button/section/row) rather than blocking or reloading the whole ERP shell.
22. Posted/finalized finance and academic records use state transitions, reversals or superseding revisions rather than in-place historical rewrites.
23. Admission identity, enrollment activation, billing and payment are separate business facts. A payment receipt is never generated when no money was received; unpaid obligations use invoices/charges/receivables.
24. Default admission activation policy requires an accepted admission plus posted initial billing. Whether payment/deposit is required before ACTIVE enrollment is a configurable policy.

## Configuration and Settings Control Center

The ERP must expose a dedicated Settings / Control Center grouped by domain:

- Organization & branches
- Academic years, classes, programs, subjects and master data
- Admission activation and enrollment policies
- Batch capacity and scheduling policies
- Billing, due dates, discounts, scholarships and payment methods
- Teacher compensation, revenue sharing, retention/acquisition bonuses and advances
- Staff roles, user roles, permission matrix and branch scope
- Approval workflows and maker-checker thresholds
- CRM sources, statuses, follow-up defaults and ownership rules
- Document/numbering preferences and communication templates
- Security, session and operational controls

Settings are not unrestricted free-form edits. Each setting has a type, validation contract, scope, effective date and audit history. Policies that affect historical calculations are versioned rather than overwritten.

## Engineering shape

```text
modules/
  platform/
    auth/
    permissions/
    audit/
    approvals/
    master-data/
    rules/
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

Business workflow rule:

```text
UI with on-change validation
→ local readiness state
→ permission check
→ domain service / transactional RPC
→ database invariant + idempotency/concurrency guard
→ approval where policy requires it
→ audit event / policy-version reference
→ targeted cache invalidation
→ local success/error update
```

## Delivery order

### Phase 0 — Platform foundation
- Organization / branch-ready identity
- Profiles
- Permission-based RBAC
- Staff identity foundation
- Universal audit events
- Approval engine
- Versioned business rules
- Canonical master-data infrastructure
- CI / database verification

### Phase 1 — CRM + Student Core
- Prospects / Student Bank
- Follow-up timeline
- Schools, areas, sources
- Students, guardians, relationships
- Enrollments
- Prospect → Admission conversion

### Phase 2 — Academic Operations
- Curriculum / syllabus structure
- Routine templates and real sessions
- Session plan vs actual coverage
- Attendance approval workflow
- Homework
- Assessments / result approval
- Leave, substitution and recovery gaps

### Phase 3 — Finance
- Fee plans / assignments
- Billing periods / charges
- Payments / allocations
- Receipts
- Discounts / approvals
- Reversals / refunds
- Staff / vendor advances

### Phase 4 onward
Follow the Master Blueprint roadmap.

## Reset policy

The linked development database must not be reset until the v2 migration baseline on this branch replaces the legacy migration chain. Running a reset against the old migration set would simply recreate the legacy schema.

For a throwaway linked **development/staging** project, once the v2 migration baseline is ready:

```bash
pnpm exec supabase db reset --linked --no-seed
```

This is destructive and must never be run against production.
