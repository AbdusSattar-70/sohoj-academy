# Sohoj Academy Digital Campus

Next.js App Router and Supabase ERP with an account-free public website. Branch: feature/redesign_refactor.

Start with [Fresh database setup](docs/architecture/FRESH_DATABASE_SETUP.md), [Workflow](docs/architecture/REDESIGN_REFACTOR_WORKFLOW.md), [Schema](docs/architecture/DATABASE_SCHEMA.md) and [Handoff](docs/architecture/DEVELOPMENT_HANDOFF.md).

This branch has 13 fresh baseline migrations plus the additive `14_referrer_portal_collection_discounts.sql` refinement. The previous historical migrations and obsolete implementations are removed, without an archive. Install on an empty application schema or reset your authorized test project using the setup guide; do not push this baseline onto the old database.

The admission desk supports direct intake or verified Prospect conversion, physical paper consent, referral, permitted discounts, atomic acceptance/invoice, actual payment and enrollment. Admin actions run directly with permission/audit checks; teacher submissions retain administrative review. Fees and rules remain simple current settings with protected historical evidence.

Required configuration is listed in .env.example. Complete academy setup after bootstrap login. Run pnpm build and pnpm dev, then follow [Manual acceptance](docs/architecture/REDESIGN_LOCAL_ACCEPTANCE.md).
