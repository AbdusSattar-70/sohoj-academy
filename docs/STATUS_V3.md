# V3 implementation status

Updated 2026-09-29.

This branch is the V3 transition branch. The current application and Supabase migration chain are still V2 unless a row below explicitly says otherwise.

| Area | Status | Notes |
| --- | --- | --- |
| V3 product / architecture / delivery docs | Implemented | Repository docs are the current phase contract. |
| Ordered task navigation | Implemented | Sidebar groups follow the V3 operator order; Help remains available from the ERP shell/header. |
| Unknown-route header handling | Implemented | Unknown paths show a neutral ERP heading instead of inheriting another module title. |
| Focused admission case route | Implemented | `/dashboard/admissions/[admissionId]` provides the working case page and next-step actions. |
| Direct staff intake → case | Implemented | Successful direct intake navigates to its admission case; no synthetic CRM Enquiry is created. |
| Prospect conversion → case | Implemented | Creating an admission from a CRM Enquiry preserves the original enquiry link and opens the case. |
| Referral / paper-consent focused refresh | Implemented | Successful actions refresh the focused case route. |
| Unified teacher Admin Review Queue | Implemented | Attendance, class logs, assessment results and questions are surfaced as one review queue with exact task links. |
| Teacher class-log review lifecycle | Implemented | Class logs now follow DRAFT → SUBMITTED → APPROVED/REJECTED with immutable reviewed history. |
| V3 clean database baseline | Prepared | Four ordered schema-only baseline parts now exist under `supabase/baseline_v3/`; the active Supabase migration path remains V2 until clean-environment verification. |
| V3 database cutover/reset | Not implemented | The baseline is isolated and ready for disposable clean-database rehearsal; the linked V2 project has not been reset. |
| Teacher vertical slice | In transition | Direct teacher submission/review path and unified Admin Review Queue are implemented as V3 transition surfaces; the underlying schema still comes from the V2 chain. |
| Finance V3 reconnection | Not implemented as V3 | Finance accounting exists on the transition branch, but discount/cancellation/refund and billing flows still require V3 reconnection after the clean baseline is verified. |
| Browser acceptance | Pending | Signed-in admin/teacher workflows have not been accepted against the linked development environment here. |
| Database/RLS acceptance | Pending | V3 baseline constraints, RLS, idempotency and concurrency tests remain to be run in the clean V3 environment. |
| Lint / typecheck / build | Pending | GitHub/Vercel checks should be treated as the authoritative execution gate; this branch has not been locally executed in this session. |

## Current implementation boundary

The admission case route now uses a focused V3 transition read model. Direct staff intake records an explicit DIRECT_STAFF origin without manufacturing a CRM Enquiry. The underlying admission tables remain part of the V2-derived baseline until the clean database is cut over.

## Next V3 delivery slice

The clean V3 baseline is prepared as four ordered schema-only files under `supabase/baseline_v3/`. The next gate is to apply it to a disposable clean Supabase database, run the SQL/RLS suite, generate fresh database types, then remove the superseded V2 migration path and continue Finance reconnection.
