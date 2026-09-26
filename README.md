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

## Local setup

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
