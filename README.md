# Sohoj Academy ERP

Sohoj Academy ERP is a bilingual, role-based coaching management platform built as a modular monolith with Next.js and Supabase/Postgres.

The authoritative product reference is **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.0** in the Sohoj Academy Google Drive. Repository changes should follow `docs/architecture/ERP_IMPLEMENTATION_GUARDRAILS.md`.

## Product principles

- One source of truth for important business facts.
- Traceable business actions with immutable audit history.
- No destructive deletion of operational history.
- Approval-based finalisation for sensitive academic and financial workflows.
- Database-enforced integrity for critical rules.
- English and Bangla first-class UI.
- Light, dark and system appearance modes.
- WCAG 2.2 AA accessibility baseline.
- Mobile-first PWA architecture, with offline writes only where operationally safe.
- Modular monolith boundaries so the system can scale without a major redesign.

## Technology

- Next.js 16 / React 19 / TypeScript
- Supabase Auth + Postgres + Row Level Security
- Tailwind CSS / shadcn UI
- Zod validation
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

Or run all three:

```bash
pnpm check
```

Database changes must also be verified with the relevant SQL test/fixture under `supabase/tests/` and realistic mock data.

## Current architecture

The application is being migrated toward these domain boundaries:

```text
modules/
  crm/
  students/
  admissions/
  academics/
  finance/
  staff/
  assets/
  procurement/
  platform/
```

Shared platform responsibilities include authentication, permissions, approvals, auditing, master data, internationalisation, offline/sync infrastructure and reusable UI.

Server-side business workflows should follow:

```text
UI
→ validation
→ authorisation
→ domain service / transactional RPC
→ audit event
→ revalidation
```

Business formulas should not live in React components, and critical integrity must not rely on UI validation alone.

## Database migrations

Migrations are append-only under `supabase/migrations/`. Do not edit a migration that has already been applied to a shared environment. Add a new migration for corrections or new behaviour.

Human-friendly operational identities such as Student IDs and Prospect IDs are immutable and never reused.

## Security

- RLS is the database access boundary.
- The browser must never receive a Supabase service-role key.
- Financial and identity-sensitive operations require explicit server/database controls.
- Approved/final records are corrected through controlled revision, reversal, rejection or adjustment workflows rather than silent overwrite.

## UX acceptance standard

A new employee should be able to determine, without asking a developer:

1. where they are;
2. what they need to enter;
3. why the information is required;
4. what will happen after saving;
5. whether the operation succeeded or failed.

Every important workflow therefore requires visible labels, Required/Optional state, contextual help where necessary, accessible validation, visible success/error feedback, keyboard support and mobile-friendly controls.

## Development status

The ERP is intentionally being built incrementally. A module is not considered production-ready merely because it renders or compiles. It must also satisfy the project guardrails, database integrity requirements, mock-data verification and the four blueprint acceptance questions.

See `docs/architecture/ERP_IMPLEMENTATION_GUARDRAILS.md` for the current implementation rules.
