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
UI
→ schema validation
→ authorisation
→ domain service / transactional RPC
→ audit event
→ revalidation
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
