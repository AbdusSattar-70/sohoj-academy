# Development handoff

Current branch: `feature/redesign_refactor`.
Base: `feature/rollback`, commit `67b83a5bef08d4532a7e2c32332c185ee0466569`.
Updated: 2026-09-30.

Read [Redesign workflow](REDESIGN_REFACTOR_WORKFLOW.md) before changing operational behavior. It supersedes conflicting historical documents. No parallel MVP schema, public student account requirement, or independent admin admission approver should be introduced.

## Architecture

Feature modules contain client forms, server actions, schema validation and queries. Supabase RLS protects reads; controlled RPCs validate permission and business invariants, perform transactional mutations and append audit events. New contracts use `modules/platform/rpc-client.ts` or explicit domain types until generated database types are refreshed. Do not bind/unbind Supabase methods without their receiver.

Migrations `01–13` are the rollback baseline. Additive migrations `14–28` implement unverified public intake, admission discounts/finalization, setup/lifecycle controls, staff requests, correction-aware paper consent, generated academy rolls, first-run integrity and additional admission charges. Old migration files are not rewritten.

Internal fee snapshots protect past admissions. The product edits current Fee Plans; do not expose storage version management or same-day publication restrictions again.

## Important surfaces

- `/dashboard/setup`: ordered prerequisite setup and explicit completion.
- `/auth/sign-up`: staff access request, not self-assigned privileged signup.
- `/dashboard/settings/access-requests`: verification/invitation, also linked from Action Center.
- `/auth/confirm`, `/auth/update-password`, `/dashboard/account`: Supabase secure credential lifecycle.
- `/interest`: public preferences; database accepts class/programme/subject mismatches as unverified statements.
- `/dashboard/admissions`: register and direct/enquiry intake with draft/review.
- `/dashboard/admissions/[id]`: actionable case steps, correction, referral, paper consent, allowed discounts, additional charges, atomic final submission, payment and policy-based activation.
- `/dashboard/admissions/application-form`: two-page blank printable form.
- `/dashboard/admissions/[id]/print`: populated form or actual-payment receipt.

## Preserve these invariants

Public applications do not create master data or verified academic links. Direct intake does not create CRM Prospects. Signed paper consent is retained physically; no upload. An identity correction retains prior signed evidence but requires renewed consent before finalizing. Successful final submission creates both identity and invoice, including a due balance when unpaid. A payment always means actual money received. Discounts and posted finance use credits/compensating records. Teacher academic review remains.

Setup is enforced by navigation and admission RPC guards. `returnTo` accepts only known local working routes. Canonical core writes cannot bypass mutation RPCs through authenticated direct table writes. Permanent deletion guards retain identity and financial evidence.

## Verification and deployment boundaries

TypeScript and production compilation are verified in an isolated source snapshot. SQL migration/application fixtures run in PostgreSQL-compatible PGlite; this is not a live Supabase deployment. Production build verification uses mocked Google font downloads because of the execution environment's network restriction; actual font delivery remains unchanged in code.

No live database reset, migration push or real staff email was performed. Configure server invitation credentials, Auth redirects and email templates, then perform local acceptance using [the checklist](REDESIGN_LOCAL_ACCEPTANCE.md). Verify the two-page output in browser print preview with your printer; visual browser rendering was unavailable in the implementation environment.
