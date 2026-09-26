# Sohoj Academy ERP

Sohoj Academy ERP is a coaching-institute operating system built as a modular monolith with Next.js and Supabase/Postgres.

The authoritative product reference is **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1** in the Sohoj Academy Google Drive. Repository implementation rules are defined in:

- `docs/architecture/ERP_V2_REBUILD.md`
- `docs/architecture/ERP_IMPLEMENTATION_GUARDRAILS.md`
- `docs/architecture/ERP_INTERACTION_WORKFLOW_STANDARD.md`
- `docs/architecture/DASHBOARD_INITIALIZATION.md`

## Product principles

- One source of truth for every important business fact.
- Important actions are reconstructable through immutable audit history and correlation IDs.
- No destructive deletion of operational history.
- Sensitive workflows use explicit approval / maker-checker where policy requires it.
- Critical integrity is enforced in Postgres as well as application validation.
- Operational values are configurable policies, not hard-coded constants.
- Settings and business rules are versioned, effective-dated, reasoned and audited.
- Historical transactions retain the policy / Fee Plan version that governed them.
- Staff is the canonical person identity; Teacher is a role/assignment.
- Programme, Programme Offering and Fee Plan are separate concepts.
- Admission, Enrollment, Billing and Payment are separate business facts.
- A payment receipt is generated only after money is actually posted.
- ERP Dashboard is English-only; public Home, Interest and Auth/Sign-in support English/Bangla.
- Light, dark and system appearance modes are supported.
- WCAG 2.2 AA is the accessibility baseline.
- Mobile-first/PWA-safe architecture is required.
- Loading and mutation feedback stay local to the affected section/button/row whenever possible.

## Technology

- Next.js 16 / React 19 / TypeScript
- Supabase Auth + Postgres + Row Level Security
- Tailwind CSS / shadcn UI
- React Hook Form + Zod
- pnpm
- Supabase SQL migrations and database verification scripts

## Academic operations

On `feature/student-lifecycle`, apply migrations through 0021 and open **Academics → Academic Operations**. Configure rooms and curriculum, create weekly routine templates, generate dated classes, and record attendance for independent review. Assigned teachers see their own sessions; managers and attendance approvers can review the broader schedule.

See [Academic operations acceptance](docs/architecture/ACADEMIC_OPERATIONS_ACCEPTANCE.md). Curriculum plans and attendance are separate from actual teaching coverage. Class logs, recovery, assessments and the question-creation module are not implemented by this slice.

## Student profiles and lifecycle

Branch `feature/student-lifecycle` includes migrations through 0019. Open **Students → Student ID** for the detailed profile, guardian contacts, enrollment history, finance-authorized balances and lifecycle requests.

Create an enrollment draft with an existing Student ID; request a same-offering batch transfer; or submit a verified duplicate identity for independent review. History and permanent IDs are retained. See [Student lifecycle acceptance](docs/architecture/STUDENT_LIFECYCLE_ACCEPTANCE.md) for permissions, boundaries and testing.

## Billing, discounts, cancellations and refunds

Open **Finance → Billing & Adjustments** after applying migrations through 0016.

- **Student Accounts**: select an admission, inspect balances, request tuition discounts or cancellation, collect invoice payments, request refunds, and record approved actual payouts.
- **Approvals**: a different authorized person approves/rejects requests with a reason. Requesters cannot decide their own requests, including ADMIN.
- **Recurring Billing**: choose a month or academic term, preview charges, then post reviewed invoices. Only active enrollments and recurring components are billed; repeat periods are protected against duplicates. This is a controlled operator-run process, not automatic bank collection or an unattended scheduler.

See [Finance acceptance guide](docs/architecture/FINANCE_ACCEPTANCE.md) for setup, permission requirements and expected balances. Original invoices and receipts are never rewritten by discounts or refunds.

## Test the admission process

After pulling `feature/dashboard_initialization`, apply pending migrations through 0016 to the same development Supabase project used by `.env.local`:

```bash
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm dev
```

If the development server is already running on port 3000, use that server or stop it before starting another one.

1. Programme Offerings → publish a Fee Plan.
2. Batches (`/dashboard/academics/batches`) → create an offering-linked batch.
3. Public Interest → create a Prospect.
4. Admissions (`/dashboard/admissions`) → create a draft, review identity/fees, mark Ready and Accept.
5. Post Initial Billing, then Evaluate Enrollment Activation.
6. If the policy requires payment, post actual money received and recheck activation.
7. View the Student register, dashboard count, outstanding balance, audit events and printable admission form / actual receipt.

`supabase/tests/0010_v2_admission_end_to_end.sql` runs development fixtures in a transaction and rolls them back. Run it as database owner in a development database after applying all migrations. It tests state transitions, fee inheritance, policy pinning, retries, full batches, payment gating and overpayment.

## Local setup

### Preview the Programme Offering and Fee Plan screens

In your existing checkout, first commit or stash any uncommitted work you want to keep. Then:

```bash
git switch feature/dashboard_initialization
git pull --ff-only origin feature/dashboard_initialization
pnpm install
```

Make sure `.env.local` points to your **development** Supabase project. In that project's linked checkout, inspect the pending migrations and apply them:

```bash
pnpm exec supabase migration list
pnpm exec supabase db push
```

This applies pending migrations, including `0008` and `0009`, to the linked project. Do not run `db reset --linked` to preview these pages. After applying, run `supabase/tests/0008_v2_programme_fee_foundation.sql` in that project's SQL Editor and regenerate types when the linked CLI is available:

```bash
pnpm exec supabase gen types typescript --linked > types/database.tmp.ts \
  && mv types/database.tmp.ts types/database.ts
pnpm dev
```

Sign in as the bootstrapped ADMIN, then open:

- `http://localhost:3000/dashboard/academics/offerings`
- `http://localhost:3000/dashboard/finance/fee-plans`

Create an offering, then publish its first Fee Plan. Publication is limited to today's organization-local date, and a second version cannot be published on that same date. Creating an offering or plan does not create a student or a charge. Continue through Batches and Admissions for the complete normal flow.

Create a local `.env.local` file containing the public Supabase project values used by this app:

```bash
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
```

Never commit service-role credentials or other secrets.

Install dependencies:

```bash
pnpm install
```

Link the Supabase CLI project when required, then apply migrations and regenerate the checked-in database types:

```bash
pnpm exec supabase db push

pnpm exec supabase gen types typescript --linked > types/database.tmp.ts \
  && mv types/database.tmp.ts types/database.ts
```

Run the application:

```bash
pnpm dev
```

## Quality gate

Before a change is considered ready:

```bash
pnpm lint
pnpm typecheck
pnpm build
```

Or:

```bash
pnpm check
```

Database changes must also pass the relevant SQL verification under `supabase/tests/` plus realistic mock-flow verification.

## Current architecture

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
  finance/
  staff/
  assets/
  procurement/
  settings/
```

Business workflows follow:

```text
UI with live validation
→ local readiness state
→ permission + scope check
→ domain service / transactional RPC
→ database invariant + idempotency/concurrency guard
→ approval when policy requires it
→ audit event + policy/version reference
→ targeted cache invalidation
→ local success/error update
```

Business formulas and operational percentages must not live inside React components.

## Configuration-first operation

Values such as batch capacity, tuition, fee components, admission activation requirements, teacher revenue sharing, acquisition/retention bonuses, discount thresholds and approval rules are configured through versioned policies.

Seeded values such as a 12-student batch limit or 30% teaching pool are initial management defaults only. They are not permanent code constants.

Configuration does **not** weaken integrity. Audit immutability, receipt-only-after-real-payment, no silent posted-finance edits, maker-checker separation where required, RLS and accounting integrity remain non-negotiable.

## Admission and fee inheritance

Normal admission does not ask an operator to retype fee data the ERP already knows.

```text
Class
→ Programme Offering
→ Eligible Batch
→ Versioned Fee Plan
→ Standard charges auto-loaded
→ Approved discount/scholarship/exception
→ Net payable calculated
→ Admission accepted
→ Initial billing posted
→ Enrollment activation policy evaluated
```

An unpaid student can have an outstanding receivable/due. A due is not a receipt.

## Database migrations

Migrations are append-only after they have been applied to a shared environment. Corrections/new behaviour use a new migration.

Human-friendly operational identities such as Student, Staff and Prospect IDs are immutable and never reused.

## Security

- RLS is the database access boundary.
- The browser never receives a Supabase service-role key.
- Role names alone do not grant access; effective authorization is permission-driven and may later include OWN / ASSIGNED_BATCHES / BRANCH / ORGANIZATION scope.
- Financial and identity-sensitive operations require explicit server/database controls.
- Approved/final records are corrected through controlled revision, reversal, rejection or adjustment workflows rather than silent overwrite.
- The bootstrap ADMIN recovery authority is protected from accidental permission lockout.

## UX acceptance standard

A new employee should be able to determine without asking a developer:

1. where they are;
2. what they need to enter;
3. why the information is required;
4. what the ERP already knows and therefore should auto-fill;
5. what will happen after saving;
6. whether the operation succeeded or failed.

ERP forms therefore use visible labels, Required/Optional state, live field validation, cross-field validation, disabled submit until valid/changed, business-context help, accessible errors and localized pending state.

## Development status

The ERP is being rebuilt deliberately on the blueprint-first architecture. A module is not production-ready merely because it renders or compiles. It must satisfy the blueprint, guardrails, database invariants, configuration model, verification scripts and end-to-end workflow semantics.
