# Sohoj Academy Digital Campus

Next.js App Router and Supabase ERP with an account-free public website. Branch: feature/redesign_refactor.

Start with [Fresh database setup](docs/architecture/FRESH_DATABASE_SETUP.md), [Workflow](docs/architecture/REDESIGN_REFACTOR_WORKFLOW.md), [Schema](docs/architecture/DATABASE_SCHEMA.md) and [Handoff](docs/architecture/DEVELOPMENT_HANDOFF.md).

This branch has 13 fresh baseline migrations plus additive refinements 14 (referrals/collections) and 15 (paged audit activity). The previous historical migrations and obsolete implementations are removed, without an archive. Install on an empty application schema or reset your authorized test project using the setup guide; do not push this baseline onto the old database.

The admission desk supports direct intake or verified Prospect conversion, physical paper consent, referral, permitted discounts, atomic acceptance/invoice, actual payment and enrollment. Admin actions run directly with permission/audit checks; teacher submissions retain administrative review. Fees and rules remain simple current settings with protected historical evidence.

Required configuration is listed in .env.example. Complete academy setup after bootstrap login. Run pnpm build and pnpm dev, then follow [Manual acceptance](docs/architecture/REDESIGN_LOCAL_ACCEPTANCE.md).

## Lean modular EduOps direction

New documentation-first branch: `feature/lean-modular-eduops`, based on merged master. Start with [Product and architecture blueprint](docs/architecture/LEAN_EDUOPS_BLUEPRINT.md), [Bangla operator workflows](docs/architecture/LEAN_EDUOPS_WORKFLOWS_BN.md), and [Implementation milestones](docs/architecture/LEAN_EDUOPS_IMPLEMENTATION_PLAN.md). These define target behavior; runtime/schema changes are pending. Existing setup and accounting contracts remain in effect until tested additive migrations replace the relevant dependencies.
