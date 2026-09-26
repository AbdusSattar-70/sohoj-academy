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

`feature/dashboard_initialization`

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

## Immediate next implementation direction

After ADMIN login and Settings are verified in the real UI:

1. Finish Settings/Control Center verification in the real UI.
2. Apply and verify migrations 0008/0009 for Programme Offering and versioned Fee Plan/Components; regenerate linked database types.
3. Verify the Programme Offering and Fee Plan screens and their audited RPCs in the real UI.
4. Build Admission Case state machine.
5. Auto-inherit Fee Plan during Admission.
6. Add initial Billing/Receivable creation.
7. Evaluate configurable Enrollment Activation policy.
8. Add real Payment → Allocation → Receipt workflow.
9. Only then build downstream Academic/Finance modules that depend on trustworthy enrollment/billing.

## New-chat instruction

In a fresh conversation, say:

“Continue the Sohoj Academy ERP build from GitHub branch `feature/dashboard_initialization`. First read `docs/architecture/DEVELOPMENT_HANDOFF.md`, the repository architecture docs, and the Google Drive Master Blueprint v1.1. Use the existing blueprint-first architecture and continue from the Immediate next implementation direction. Do not revive the old MVP dashboard/schema.”
