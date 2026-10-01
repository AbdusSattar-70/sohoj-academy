# Development handoff

The current branch is `feature/redesign_refactor`. This is a fresh-install schema, not an upgrade replay. Read [Workflow](REDESIGN_REFACTOR_WORKFLOW.md), [Database schema](DATABASE_SCHEMA.md), [Fresh setup](FRESH_DATABASE_SETUP.md), and [Interaction standard](ERP_INTERACTION_WORKFLOW_STANDARD.md).

There are 13 ordered migrations, 90 application tables and 113 functions. Historical concatenated migrations, dynamic function patches, parallel wrapper RPCs, obsolete public application tables, uploaded-consent storage contracts, public content version queues and generic setting registries are removed. Previous implementations are not archived in this branch.

Admin-authorized financial posting, compensation, student transfers and duplicate correction run directly with permission checks and audit evidence. Teacher academic review remains. Public submissions are unverified preferences; direct staff admissions never fabricate a Prospect. Academic directory records are created during setup, not supplied as demo seeds.

The UI uses domain modules, controlled RPC writes and permission-scoped reads. Keep existing public visual styling. Do not add client service-role access or bypass prerequisites to mask errors.

Validation completed during cleanup: all 13 migrations applied in isolated PostgreSQL-compatible PGlite; the three rollback-only SQL fixtures passed; Next route generation and TypeScript passed. This does not establish hosted Supabase Auth/Storage behavior, production build success or browser acceptance. Follow the local acceptance checklist before deployment.
