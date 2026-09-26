# Sohoj Academy ERP — Development Handoff

Last updated: 2026-09-26

This document is the durable handoff for continuing the ERP build in a fresh ChatGPT conversation.

## Authoritative product source

Google Drive document:

**Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1**

Document ID:
`178UvETYjbLQchhWWSN1o5oSKTHOiWwSCmwReStbM7BI`

Repository architecture references:
- `docs/architecture/ERP_V2_REBUILD.md`
- `docs/architecture/ERP_IMPLEMENTATION_GUARDRAILS.md`
- `docs/architecture/ERP_INTERACTION_WORKFLOW_STANDARD.md`
- `docs/architecture/DASHBOARD_INITIALIZATION.md`
- `docs/architecture/ADR_013_018_FOUNDATION_DECISIONS.md`

## Active development branch

`feature/student-lifecycle` (branched from `feature/dashboard_initialization` at `d4b093a`, including the public Interest RPC receiver fix).

Do not continue ERP work from the old MVP branch.

## Stack

- Next.js 16.3.5 / React 19
- TypeScript
- Supabase Auth + Postgres + RLS
- Tailwind / shadcn
- React Hook Form + Zod
- pnpm
- Supabase migrations + SQL verification tests

Build intentionally uses webpack:
`next build --webpack`

Typecheck intentionally clears stale Next route types and regenerates them before `tsc --noEmit`.

## Current product rules

1. Dashboard/ERP is English-only.
2. Public Home, Interest and Auth/Sign-in support English/Bangla.
3. Light/Dark/System appearance remains supported.
4. Operational values are configurable/versioned policies, never hidden hard-coded constants.
5. Seed values such as batch capacity 12 or teacher pool 30% are defaults only.
6. Historical finalized records retain the exact policy/Fee Plan version that governed them.
7. Staff is the canonical person identity; Teacher is a role/assignment.
8. Programme, Programme Offering and Fee Plan are separate concepts.
9. Normal Admission inherits standard fees from the selected Fee Plan; operators do not retype them.
10. Admission, Enrollment, Billing and Payment are distinct business facts.
11. A receipt is generated only for actual posted payment; unpaid obligations are dues/receivables/invoices/charges.
12. ACTIVE Student counts are based on ACTIVE enrollment, not Prospect or Admission Draft.
13. Sensitive changes require reason + audit; maker-checker applies where appropriate.
14. Posted/finalized history is corrected by reversal/revision/adjustment, not destructive overwrite.
15. Forms validate live with React Hook Form + Zod; submit is disabled until valid + changed + not pending.
16. Loading/pending state is local to route/card/row/button; the ERP shell remains stable.
17. Critical retry/concurrency workflows require idempotency, uniqueness and/or row locking.
18. RLS/database authorization remains the security boundary.

## Current migration chain

- `0001_v2_platform.sql`
- `0002_v2_crm_student_core.sql`
- `0003_v2_staff_workflow.sql`
- `0004_v2_crm_followup.sql`
- `0005_v2_configuration.sql`
- `0006_v2_control_center_editing.sql`
- `0007_v2_user_access_control.sql`
- `0008_v2_programme_offerings_fee_plans.sql` (repository migration; apply and verify in linked environment)
- `0009_v2_fee_plan_local_date.sql` (publish date follows organization timezone)

Verification tests:
- `0001_v2_platform.sql`
- `0002_v2_crm_student.sql`
- `0003_v2_mock_flow.sql`
- `0004_v2_staff.sql`
- `0005_v2_configuration.sql`
- `0006_v2_control_center_editing.sql`
- `0007_v2_user_access_control.sql`
- `0008_v2_programme_fee_foundation.sql` (run after migration 0008)

## Current implemented ERP routes

- `/dashboard`
- `/dashboard/action-center`
- `/dashboard/crm/prospects`
- `/dashboard/crm/prospects/[prospectId]`
- `/dashboard/students`
- `/dashboard/academics/offerings`
- `/dashboard/finance/fee-plans`
- `/dashboard/staff`
- `/dashboard/governance/approvals`
- `/dashboard/governance/audit`
- `/dashboard/governance/rules`
- `/dashboard/settings`

The Sidebar/Header route metadata is centralized in:
`modules/platform/navigation/erp-route-registry.ts`

## Current working verticals

### CRM / Student Bank
- Public Interest creates a Prospect through controlled RPC.
- Permanent Prospect number.
- Prospect list/detail/timeline.
- Controlled Prospect status transitions.
- Audited follow-up workflow.
- Action Center surfaces due follow-ups.

### Staff
- Permanent Staff identity.
- Role assignments.
- Teaching subject qualifications.
- Controlled Staff creation RPC.
- Live-validated Staff form.

### Settings / Control Center
- Versioned Business Rules.
- Editable batch-capacity policy.
- Editable admission-activation policy.
- Editable teacher-compensation policy.
- Operational role-permission editor.
- User-to-operational-role access editor.
- Protected bootstrap ADMIN.
- Direct browser mutation of controlled permission/policy tables revoked.

## Current database workflow functions

Important functions include:
- `bootstrap_admin(text,text)`
- `has_permission(text)`
- `my_erp_context()`
- `create_staff_member(jsonb)`
- `submit_public_interest(jsonb)`
- `record_prospect_followup(jsonb)`
- `publish_business_rule_version(text,text,jsonb,text)`
- `validate_business_rule_payload(text,text,jsonb)`
- `set_role_permissions(text,text[],text)`
- `set_user_operational_roles(uuid,text[],text,uuid)`

## Initial ADMIN bootstrap

The first ADMIN is intentionally not created through public signup or the normal access editor.

1. Create or confirm an Auth user under Supabase Dashboard → Authentication → Users.
2. Use the exact email.
3. Run in Supabase SQL Editor:

```sql
select public.bootstrap_admin(
  'ADMIN_EMAIL@example.com',
  'Abdus Sattar'
);
```

The function creates/updates:
- Profile
- linked Staff identity when absent
- Administration Staff role
- protected ADMIN system-role assignment

It is intentionally revoked from `anon` and `authenticated` API roles.

Then sign in through:
`/auth/sign-in`

Do not create a second Auth user if the intended admin user already exists.

## ADMIN verification query

```sql
select
  u.email,
  p.display_name,
  s.staff_no,
  s.full_name as staff_name,
  r.code as system_role,
  ura.is_active,
  ura.effective_from,
  ura.effective_to
from auth.users u
join public.profiles p on p.id=u.id
left join public.staff s on s.profile_id=p.id
left join public.user_role_assignments ura
  on ura.profile_id=p.id
  and ura.is_active
  and ura.effective_to is null
left join public.system_roles r on r.id=ura.role_id
where lower(u.email)=lower('ADMIN_EMAIL@example.com')
order by r.code;
```

Expected protected role includes:
`ADMIN`

## Current local repository state at handoff

The latest reported local quality gate passed:

- `pnpm lint` ✅
- `pnpm typecheck` ✅
- `pnpm build` ✅

The generated linked Supabase types were refreshed and committed on this branch (`fac4cbd`). They include the RPCs:
- `publish_business_rule_version`
- `validate_business_rule_payload`
- `set_role_permissions`
- `set_user_operational_roles`

Treat generated `types/database.ts` as authoritative. Regenerate it only after applying migration 0008; do not hand-edit it.

## Programme Offering / Fee Plan foundation (2026-09-26)

Migration 0008 adds canonical academic groups, Programme Offerings, immutable published Fee Plan Versions and their charge components. Creation and publication use permission-checked, audited RPCs. Publishing serializes on the offering row, and authenticated clients cannot directly mutate these tables. Migration 0009 aligns the publication date with the organization timezone. A Fee Plan may be published effective today; future scheduling and same-day re-publication require a separate policy/workflow design. No fee amounts are seeded.

The ERP now has Programme Offering creation/list and Fee Plan publication/history screens. Forms use shared Zod contracts with React Hook Form. Until the linked migration is applied and types regenerated, `modules/offerings/database-contract.ts` provides a scoped typed contract for migration 0008 without modifying generated `types/database.ts`.

This workspace has no linked Supabase credentials, local Postgres service, or signed-in ADMIN browser session. Migrations 0008/0009 and test 0008 have **not** been run against a database. Do not mark Settings or the new forms' real-UI verification complete. Apply the migrations in a development environment, run the SQL test, exercise both RPCs with an authorized ADMIN, and regenerate linked database types before Admission.

After confirming the commit is pushed, the old stash created before switching from `rewrite/erp-blueprint-v2` can remain temporarily or be dropped deliberately later. Do not `git stash pop` it over this branch.

## First ADMIN login sequence after database reset/migrations

1. Confirm the Auth user exists in Supabase Authentication.
2. Run `bootstrap_admin` in SQL Editor.
3. Run the ADMIN verification query.
4. Open local app:
   `http://localhost:3000/auth/sign-in`
5. Sign in with the same Auth email/password.
6. Confirm Dashboard and Settings load.
7. Confirm Settings → user access / role permission controls are visible to ADMIN.

## Admission workflow implementation (2026-09-26)

The user confirmed migrations 0008/0009 were applied and ADMIN sign-in works.

New pending migrations:
- `0010_v2_admission_workflow.sql`: offering-linked batch creation, Admission Cases, immutable initial invoices and lines, idempotent state transitions, identity/guardian creation, policy pinning and enrollment.
- `0011_v2_admission_payments.sql`: actual payment, allocation, receipt identity, outstanding balance and payment-backed activation.
- `0012_v2_admission_workspace.sql`: permission-scoped workspace read model.

New routes:
- `/dashboard/academics/batches`
- `/dashboard/admissions`
- `/dashboard/admissions/[admissionId]/print` (admission form; `?receipt=RCT-...` prints an actual posted receipt)

Testable normal flow:
Programme Offering → Fee Plan → Batch → Prospect → Admission Draft → Ready → Accepted → Initial Billing → Active Enrollment (or Pending Payment) → Payment / Receipt → recheck activation if needed.

Draft student/guardian identity can be corrected with reason and audit. Standard fees are read-only. Acceptance issues the permanent Student identity and pins the activation policy. Billing posts the first cycle and one-time components. Activation checks the current batch capacity and pins that capacity policy. Unpaid amounts remain receivables. Payment is separate; posting does not silently activate enrollment. The dashboard now counts Student identities with ACTIVE enrollment.

Payment posting now supports initial and recurring invoices and rejects overpayment against the net balance. Discounts, cancellations, refunds and controlled recurring billing are implemented below. Existing-student readmission, merging and correction of an incorrectly recorded payment remain separate workflows; do not compensate with raw table edits. The initial invoice is due today for one-time/term plans; monthly plans use the later of today or this month's configured due day. Drafts do not reserve seats.

Verification: the full migration chain and all SQL verification scripts, including `0010_v2_admission_end_to_end.sql`, passed in isolated PGlite/Postgres with a minimal Supabase Auth fixture. The harness omitted only the pgcrypto extension declaration because gen_random_uuid is built in. The test covers default credit activation, full-payment gating, policy pinning after later settings changes, idempotent retries, capacity, overpayment and unauthorized workspace access. This is not live Supabase/browser or multi-connection concurrency verification.

`modules/admissions/queries.ts` contains a scoped RPC type extension until linked types are regenerated. Existing generated types remain unchanged.

## Discounts, cancellations, refunds and recurring billing (2026-09-26)

These are included in the current build, per the user's instruction; they are not deferred behind normal-flow acceptance.

Migrations 0013–0016 add immutable adjustment records, billing terms/runs, controlled finance commands, admission integration, and the Finance workspace. Apply all pending migrations through 0016 together. Existing posted invoices/payments are preserved; the only data backfill assigns the existing initial invoices their billing month.

Routes:
- `/dashboard/finance/billing`: Student Accounts, Approvals, Recurring Billing.
- `/dashboard/finance/billing/[invoiceId]/print`: printable current invoice statement, including original payments and subsequent payouts.

Implemented behavior:
- Percentage or fixed tuition discount with an explicit effective billing-date range. Independent approval credits existing eligible invoices and applies to subsequent eligible invoices. Fixed discounts cap at tuition. Overlapping approved periods are rejected; other charge components are not discounted.
- Cancellation with independent approval: either preserve existing charges as debt or credit all remaining net charges. Withdraws active enrollment, updates active-student status and stops recurring billing. Posted history remains. A cancelled unaccepted draft can be restarted from its unconverted Prospect; accepted identities are not duplicated.
- Refund request → independent approval/reservation → actual payout with refund number, method and reference. Only unreserved customer credit supported by the original payment is refundable. Approval alone records no cash movement. Payment receipts retain their original amounts and show subsequent refunds.
- Monthly or named academic-term billing: explicit preview/review/post workflow. Uses pinned Fee Plans, PER_CYCLE components, eligible ACTIVE enrollment and applicable discounts. INITIAL bills the first cycle; recurring months must be later, or term starts must be later than initial issue date. ONE_TIME plans are excluded. Terms stay within the academic year and cannot overlap. Repeated periods cannot produce duplicate invoices. Changed previews are rejected. This is operator-run recurring invoicing, not an unattended scheduler or automatic payment collection.
- Net balances separate original charges, credits, money received, actual refunds, dues, customer credit and reserved refund amounts. Enrollment activation uses the initial invoice's net charge and net actual payment.
- Payment can settle an explicitly selected recurring invoice or retained debt on a cancelled admission. Overpayment is rejected.

All commands enforce database permissions, reason/audit, idempotency and case locking. Sensitive approvals require a different authenticated profile even for ADMIN. Direct financial table writes and direct approval decisions are revoked. Scoped runtime-validated RPC contracts are in `modules/finance/operations`; regenerate linked types after applying migrations, rather than hand-editing generated types.

Verification: all 11 SQL scripts pass in isolated PGlite/Postgres, including new `0013_v2_finance_workflows.sql` and `0014_v2_finance_terms_and_cancellation.sql`. Tests exercise request/approval/payout retries, self-approval denial, overlapping discounts/terms, stale previews, duplicate periods, recurring payments, refund reservations/limits, cancellation credits/retained debt, pre-billing discounts, draft restart, immutable history and unauthorized access. Typecheck, ESLint and production build pass. Real signed-in browser, live Supabase, and multi-connection concurrency verification remain unperformed in this workspace.

## Student lifecycle implementation (2026-09-27)

Active feature branch: `feature/student-lifecycle`.

New migrations:
- `0017_v2_student_lifecycle.sql`: repeated admissions for a permanent Student ID, immutable transfer/identity-merge records, permissioned student commands, independent review, removal of direct identity-table writes.
- `0018_v2_existing_student_admission.sql`: integrates existing identity drafts into the normal Ready → Accept → Bill → Activate workflow; locks the student during transitions and rejects archived identities.
- `0019_v2_student_profile_workspace.sql`: runtime-validated profile read model; financial amounts require `finance.view`.

Open Students → Student ID (`/dashboard/students/[studentId]`) for identity, linked guardians, admission cases, enrollment/transfer history, invoice balances and lifecycle approvals.

Implemented:
- Existing-student enrollment creates a new Admission Case with the same permanent Student ID and primary guardian. Standard fees load from the selected active Fee Plan. It proceeds through the existing review, billing and activation policy; previous debts/discounts remain attached to their original case. New one-time charges remain visible for review. Student identity cannot be overwritten through an enrollment draft.
- The existing database restriction of one active enrollment per student per academic year remains explicit. An open admission in that year must be resolved before readmission; a new year can use the same identity.
- Batch transfers require an independent approver with `admissions.approve`, a different active batch in the same offering, and capacity revalidation. The old enrollment closes as WITHDRAWN with a linked transfer event; a new ACTIVE enrollment replaces it. Fee Plan, invoices and billing continuity remain unchanged. Cross-offering/commercial changes are not performed through transfers.
- Duplicate candidates match normalized name or guardian mobile; matching is never proof of identity. Requester must confirm the same person and provide evidence in the reason. A different reviewer with `students.merge.approve` decides. Source must have no open admissions/active enrollment; target must be canonical in the same organization. Changed identity snapshots invalidate approval.
- A merge archives the duplicate and links it to the canonical identity. Permanent numbers, guardians, prospects, invoices, payments and historical foreign keys are retained. Canonical profile aggregates linked historical records; new enrollment must use the canonical ID. No destructive merge or unmerge is exposed. Nested merge chains are rejected.
- ADMIN receives the new merge-approval permission. Other operational roles can be granted it through Settings. Requests and decisions are audited and retry-safe; the Approval Register links to profile review.

Verification: all 12 SQL scripts pass in isolated PGlite/Postgres with Supabase Auth fixtures. New test 0017 exercises readmission, duplicate-year prevention, self-approval denial, transfer capacity/stale-request checks, immutable financial identity through merging, canonical profile aggregation and finance permission redaction. Typecheck, ESLint and production build pass. Live Supabase/browser acceptance and multi-connection concurrency verification remain pending.

## Academic operations implementation (2026-09-27)

Branch remains `feature/student-lifecycle`, per the user's instruction to continue on it.

Migrations 0020/0021 add academic rooms, immutable curriculum versions, effective-dated weekly routines, dated class sessions, attendance revisions and permission-scoped workspace RPCs.

Routes:
- `/dashboard/academics/operations`: Class Sessions, Routine Templates, Curriculum, Rooms; date-range filter for sessions.
- `/dashboard/academics/sessions/[sessionId]`: pinned plan, session details, roster, attendance draft/submission/review and revision history.

Implemented:
- Room creation with branch and student capacity. Scheduling rejects a room smaller than the configured batch capacity.
- Curriculum publication by batch/subject with chapter/topic/page descriptions and target dates inside the academic year. New publication adds a version; existing sessions keep their exact version. Planned targets are not completed coverage.
- Weekly routines reserve teacher/batch/room slots over an effective date range. Teachers require a teaching Staff role and a subject qualification covering the entire range. Room and teacher branch eligibility are checked.
- Generate real occurrences from routines (bounded to 94 days per synchronous request as a technical workload limit), or schedule a single class. Organization timezone governs local times. Repeated generation skips existing routine dates, including cancelled occurrences. Conflicts reject the entire request. A serialized database scheduling lock protects concurrent checks.
- Retire a routine to stop further generation; existing sessions remain. Cancel an individual occurrence with reason, preserving its original schedule. A session with submitted or approved attendance cannot be cancelled. Rescheduling uses explicit cancellation and a new single occurrence; automated substitution/recovery is not implemented.
- Teachers see their assigned sessions and rosters; session managers and attendance approvers can review all sessions. Attendance recording requires the record permission and an accessible session that has started.
- Attendance uses explicit PRESENT/ABSENT/LATE/EXCUSED choices. First saved draft snapshots the roster and identity labels. Subsequent saves add revisions against an expected base ID, preventing lost updates. Submit sends the latest author's draft to the Approval Register/Action Center. A different authorized approver approves/rejects.
- Latest APPROVED revision is official. A later pending/rejected correction does not replace it. Finalized evidence and earlier revisions remain immutable. No attendance approval is treated as proof of teaching/coverage completion.

Roster boundary: current enrollment storage is date-based. First snapshot includes admission date and excludes ended_on (end-exclusive); same-day transfers therefore belong to the destination for a newly snapshotted roster. A previously saved roster is preserved. Exact within-day enrollment history needs a future effective-timestamp extension if required.

Permissions reuse the existing `academics.view`, `academics.curriculum.manage`, `academics.sessions.manage`, `academics.attendance.record`, `academics.attendance.approve` codes. No service-role key or generated database type edits were introduced. Direct academic mutations are revoked; controlled RPCs enforce reasons, audit and idempotency.

Verification: all 13 SQL tests pass in isolated PGlite/Postgres. New test 0020 covers curriculum pinning, routine/session overlap rejection, retry/duplicate protection, teacher scope, roster completeness, stale draft rejection, independent approval, correction history, cancellation and retirement preservation. Typecheck, ESLint and production build pass. Live Supabase/browser and true multi-connection concurrency acceptance remain pending.

## Immediate next implementation direction

1. Apply pending migrations through 0021 and regenerate linked database types. Follow `docs/architecture/ACADEMIC_OPERATIONS_ACCEPTANCE.md` with separate teacher and reviewer accounts.
2. Build actual class logs, homework and coverage-gap/recovery workflows on the pinned curriculum/session foundation.
3. Build assessments/results and the teacher question-creation/review module. Question creation remains unimplemented; do not confuse curriculum text entry with a question bank or generation portal.
4. Continue broader student lifecycle, finance/accounting and compensation per the blueprint. Preserve historical versions, independent approval and canonical identities.

## New-chat instruction

In a fresh conversation, say:

“Continue the Sohoj Academy ERP build from GitHub branch `feature/student-lifecycle`. First read `docs/architecture/DEVELOPMENT_HANDOFF.md`, the repository architecture docs, and the Google Drive Master Blueprint v1.1. Use the existing blueprint-first architecture and continue from the Immediate next implementation direction. Do not revive the old MVP dashboard/schema.”
