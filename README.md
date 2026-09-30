# Sohoj Academy Digital Campus

Next.js App Router + Supabase ERP and public website. Current implementation branch: `feature/redesign_refactor`, based on `feature/rollback`.

Start with [Redesign workflow](docs/architecture/REDESIGN_REFACTOR_WORKFLOW.md) and [Development handoff](docs/architecture/DEVELOPMENT_HANDOFF.md). These describe the current operational contract; older architecture documents retain historical context.

## Current workflow

- First-login academy setup before operations.
- Public account-free applications stored as unverified CRM intake.
- Staff access requests verified by super admin; Supabase invitations and password/email setup.
- Direct admission without a manufactured Prospect, or verified conversion of an existing enquiry.
- One-case admission desk: details, referral, physical consent, fee/discount review, final submission, payment and enrollment.
- Current Fee Plans with protected historical admission terms.
- Standard discounts, additional one-time charges, unpaid invoices and actual-payment receipts.
- Two-page A4 application with separate office section and detachable manual money receipt.
- Teacher academic submissions retain administrative review.
- Permanent records remain; settings can be corrected/deactivated. Posted finance uses compensating records.

## Run locally

```bash
git fetch origin
git switch feature/redesign_refactor
git pull --ff-only
pnpm install
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm build
pnpm dev
```

This branch uses migrations `01–28`. For a database already on rollback `01–13`, apply only the new migrations `14–28`. If migration history differs, reconcile the actual schema and branch first; do not mark unapplied files applied or reset automatically.

Required public environment: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_SITE_URL`. Staff invitation delivery additionally requires server-only `SUPABASE_SERVICE_ROLE_KEY`. Configure Supabase Auth redirects and email templates as described in the workflow guide. Never expose the service key using a `NEXT_PUBLIC_` name.

A signed-in bootstrap ADMIN opens `/dashboard/setup` first. Afterwards open `/dashboard/admissions`. New staff request access at `/auth/sign-up`; super admin reviews at `/dashboard/settings/access-requests`.

## Validation

Use `pnpm build` and the SQL fixtures under `supabase/tests` with the repository's Supabase database test environment. Also run the manual desk scenarios in [Local acceptance](docs/architecture/REDESIGN_LOCAL_ACCEPTANCE.md). Supabase email delivery and physical print margins require verification against your own deployment/printer.
