# V3 implementation status

Updated 2026-09-29.

Operator friction from live use is recorded in `OPERATOR_FRICTION_AND_REDESIGN.md`. Admission workbench steps are now clickable and route to the work panel; CREATE offering/batch empty states and standard action reasons were improved on this pass.

This branch is the V3 transition branch. The current application and Supabase migration chain are still V2 unless a row below explicitly says otherwise.

| Area | Status | Notes |
| --- | --- | --- |
| V3 product / architecture / delivery docs | Implemented | Repository docs are the current phase contract. |
| Operator friction map | Implemented | `OPERATOR_FRICTION_AND_REDESIGN.md` lists live blockers and V3 responses. |
| Ordered task navigation | Implemented | Sidebar groups follow the V3 operator order; Help remains available from the ERP shell/header. |
| Unknown-route header handling | Implemented | Unknown paths show a neutral ERP heading instead of inheriting another module title. |
| Focused admission case route | Implemented | `/dashboard/admissions/[admissionId]` provides the working case page and next-step actions. |
| Clickable admission steps + work panel | Implemented | Progress steps link into `#work-panel`; current step title drives the panel. |
| Select-first action reasons | Implemented | READY/ACCEPT/BILL/ACTIVATE/PAY use standard notes with Other free text. |
| Prospect CREATE empty offering/batch messaging | Implemented | Filters no longer hide all options silently; empty states explain missing fee plan or batch. |
| Direct staff intake → case | Implemented | Successful direct intake navigates to its admission case; no synthetic CRM Enquiry is created. |
| Prospect conversion → case | Implemented | Creating an admission from a CRM Enquiry preserves the original enquiry link and opens the case. |
| Referral / paper-consent focused refresh | Implemented | Successful actions refresh the focused case route. |
| Unified teacher Admin Review Queue | Implemented | Attendance, class logs, assessment results and questions are surfaced as one review queue with exact task links. |
| Teacher class-log review lifecycle | Implemented | Class logs now follow DRAFT → SUBMITTED → APPROVED/REJECTED with immutable reviewed history. |
| V3 clean database baseline | Prepared | Seven ordered schema-only baseline parts under `supabase/baseline_v3`; active migration path remains V2 until cutover. |
| V3 database cutover/reset | Not implemented | Baseline is ready for disposable clean-database rehearsal; linked V2 project has not been reset. |
| Teacher vertical slice | In transition | Class-log and focused attendance use V3 commands; assessments/questions still transition. |
| Finance V3 reconnection | In transition | Student Accounts and core accounting have direct admin V3 commands; legacy approvals are transition-only. |
| Browser acceptance | Pending | Signed-in admin/teacher workflows still need linked-environment acceptance. |
| Database/RLS acceptance | Pending | V3 baseline constraints, RLS, idempotency and concurrency tests remain for the clean V3 environment. |

## Current implementation boundary

The admission case route uses a focused V3 transition read model. Direct staff intake records `DIRECT_STAFF` without manufacturing a CRM Enquiry. Underlying tables remain part of the V2-derived baseline until clean database cutover.

## Next V3 delivery slice

1. Admissions home entry cards: always open dedicated forms (staff intake / from enquiry).
2. Apply `supabase/baseline_v3` to a disposable database; SQL/RLS suite; regenerate types.
3. Continue finance reconnection and teacher assessment/question V3 commands.
4. Browser acceptance of admin admission path end-to-end on one page.
