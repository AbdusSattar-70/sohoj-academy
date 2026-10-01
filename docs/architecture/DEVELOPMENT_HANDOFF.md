# Development handoff

The current branch is `feature/redesign_refactor`. This is a fresh-install schema, not an upgrade replay. Read [Workflow](REDESIGN_REFACTOR_WORKFLOW.md), [Database schema](DATABASE_SCHEMA.md), [Fresh setup](FRESH_DATABASE_SETUP.md), and [Interaction standard](ERP_INTERACTION_WORKFLOW_STANDARD.md).

There are 15 ordered migrations, 92 application tables and 126 functions. Files 01–13 are the clean baseline; 14 is a forward upgrade for already installed projects. Historical concatenated migrations, dynamic function patches, parallel wrapper RPCs, obsolete public application tables, uploaded-consent storage contracts, public content version queues and generic setting registries are removed. Previous implementations are not archived in this branch.

Admin-authorized financial posting, compensation, student transfers and duplicate correction run directly with permission checks and audit evidence. Teacher academic review remains. Public submissions are unverified preferences; direct staff admissions never fabricate a Prospect. Academic directory records are created during setup, not supplied as demo seeds.

The UI uses domain modules, controlled RPC writes and permission-scoped reads. Keep existing public visual styling. Do not add client service-role access or bypass prerequisites to mask errors.

Validation completed during cleanup: all 13 migrations applied in isolated PostgreSQL-compatible PGlite; the three rollback-only SQL fixtures passed; Next route generation and TypeScript passed. This does not establish hosted Supabase Auth/Storage behavior, production build success or browser acceptance. Follow the local acceptance checklist before deployment.

## Current refinement

Read [Admission/referral/print contract](ADMISSION_REFERRAL_PRINT_REFINEMENT.md) and [Form inventory](ERP_FORM_INVENTORY.md). Referrers have scoped accounts, first-month net-collection acquisition evidence and corrected settlement limits. Collection-time discount/scholarship and payment are one transaction. Staff edit is inline; secondary forms open on demand with pending feedback and preserved invalid input.

The server shares a request-scoped Supabase client, verifies cookie identity with getUser, and bounds each fetch at 20 seconds without automatically retrying financial writes. Refresh failure must prompt record inspection before retrying a mutation. A Next development Performance.measure warning cannot be assumed fixed without reproducing it locally.

Current verification: all 14 files applied in isolated PGlite; four rollback fixtures passed, including actual refund payout, corrected acquisition balances, immutable/balanced accounting and own-referrer permission checks. TypeScript passed. Actual React print components were rendered and visually inspected: two-page blank admission, one-page example invoice and one-page Bangla acknowledgement. Hosted Auth/email delivery, browser navigation and physical letterhead alignment still require local acceptance. No live database was reset or migrated.

## Staff access and audit usability

Read [Secure account setup](ACCOUNT_SETUP_CONFIGURATION.md). Staff requests are verified inside the Staff page; the previous Settings request route redirects there. Setup/recovery uses a shared server-only secret-key client with credential checks and professional locale-specific feedback. Wrong live credentials still require the project administrator to correct the environment and restart/redeploy.

Migration 15 adds audit search, bounded pagination and permission-scoped Bangladesh-day operational totals. Correlation and raw change payloads stay in immutable records, not the operator table. Five isolated SQL fixtures now pass, including paged search/no overlap and protected totals.
