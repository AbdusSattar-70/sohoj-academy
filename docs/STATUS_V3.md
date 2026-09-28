# V3 implementation status

Updated 2026-09-29.

This branch is the V3 transition branch. The current application and Supabase migration chain are still V2 unless a row below explicitly says otherwise.

| Area | Status | Notes |
| --- | --- | --- |
| V3 product / architecture / delivery docs | Implemented | Repository docs are the current phase contract. |
| Ordered task navigation | Implemented | Sidebar groups follow the V3 operator order; Help remains available from the ERP shell/header. |
| Unknown-route header handling | Implemented | Unknown paths show a neutral ERP heading instead of inheriting another module title. |
| Focused admission case route | Implemented | `/dashboard/admissions/[admissionId]` provides the working case page and next-step actions. |
| Direct staff intake → case | Implemented | Successful direct intake navigates to its admission case. |
| Prospect conversion → case | Implemented | Creating an admission from a Prospect returns the case identity and navigates to it. |
| Referral / paper-consent focused refresh | Implemented | Successful actions refresh the focused case route. |
| V3 clean database baseline | Not implemented | The repository still contains the V2 migration chain. |
| V3 database cutover/reset | Not implemented | Do not reset or push the current migration folder as a V3 baseline. |
| Teacher vertical slice | Not implemented as V3 | Existing teacher workflow remains V2 code until migrated to the V3 domain boundary. |
| Finance V3 reconnection | Not implemented as V3 | Existing finance functionality remains V2 code until the clean baseline exists. |
| Browser acceptance | Pending | Signed-in admin/teacher workflows have not been accepted against the linked development environment here. |
| Database/RLS acceptance | Pending | V3 baseline constraints, RLS, idempotency and concurrency tests remain to be run in the clean V3 environment. |
| Lint / typecheck / build | Pending | GitHub/Vercel checks should be treated as the authoritative execution gate; this branch has not been locally executed in this session. |

## Current implementation boundary

The admission case route intentionally reuses the existing V2 admission read model and command services as a transition surface. This preserves the working application while the V3 domain/database baseline is built. It should be replaced by the V3 focused read model and canonical domain commands during the clean-baseline slice.

## Next V3 delivery slice

The documented next foundation is the clean V3 database baseline: platform, catalogue, CRM, admissions, academics and Finance integrity, followed by generated database types and removal of superseded V2 route/module code in validated slices.
