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
23. Loading/mutation state stays local to the affected control whenever possible.

## Public admissions workflow (account-free)

Branch `feature/workflow_redefine` formalizes public programme discovery and account-free interest / admission forms, CRM verification, and Manage CRM master-data editing. See [Public admissions workflow](PUBLIC_ADMISSIONS_WORKFLOW.md).
