# V3 implementation status

Updated 2026-09-29.

Operator friction from live use is recorded in `OPERATOR_FRICTION_AND_REDESIGN.md`. Database cutover steps are in `V3_DATABASE_CUTOVER.md`. Admission workbench steps are clickable; CREATE offering/batch empty states and standard action reasons landed earlier on this branch.

This branch is the V3 transition branch. After `pnpm run activate:v3-migrations`, the active Supabase migration path is the V3 baseline (`01_`–`07_`).

| Area | Status | Notes |
| --- | --- | --- |
| V3 product / architecture / delivery docs | Implemented | Repository docs are the current phase contract. |
| Operator friction map | Implemented | `OPERATOR_FRICTION_AND_REDESIGN.md` lists live blockers and V3 responses. |
| Ordered task navigation | Implemented | Sidebar groups follow the V3 operator order. |
| Focused admission case route | Implemented | `/dashboard/admissions/[admissionId]` workbench. |
| Clickable admission steps + work panel | Implemented | Progress steps link into `#work-panel`. |
| Select-first action reasons | Implemented | READY/ACCEPT/BILL/ACTIVATE/PAY standard notes. |
| Prospect CREATE empty offering/batch messaging | Implemented | Empty states explain missing fee plan or batch. |
| Admissions start cards | Implemented | `?start=staff` / `?start=enquiry` open dedicated forms. |
| Direct staff intake → case | Implemented | No synthetic CRM Enquiry. |
| Prospect conversion → case | Implemented | Preserves enquiry link. |
| Unified teacher Admin Review Queue | Implemented | Attendance, class logs, assessment results, questions. |
| V3 clean database baseline | Implemented | `supabase/baseline_v3` + activate script → `migrations/01_`–`07_`. |
| V3 database cutover/reset | Ready for operator reset | Follow `docs/V3_DATABASE_CUTOVER.md`. Requires disposable DB reset + `db push` + typegen. |
| Teacher vertical slice | In transition | Class-log and attendance V3; assessments/questions transition. |
| Finance V3 reconnection | In transition | Direct admin V3 commands; legacy approvals transition-only. |
| Browser acceptance | Pending | Linked-environment acceptance still required. |
| Database/RLS acceptance | Pending | After disposable reset and `db push`. |

## Current implementation boundary

UI workbench and start-path UX are on the branch. Schema cutover is prepared: run `activate:v3-migrations`, reset a disposable database, then `db push` and regenerate types.

## Next V3 delivery slice

1. Operator: reset disposable Supabase project and run cutover commands in `docs/V3_DATABASE_CUTOVER.md`.
2. Regenerate `types/database.ts` and fix any compile gaps.
3. Continue finance reconnection and teacher assessment/question V3 commands.
4. Browser acceptance of admin admission path end-to-end on one page.
