# New first-version foundation — staging only

The new SQL source lives under `supabase/schema/`. Generate its install files with `pnpm db:baseline`; check exact parity with `pnpm db:baseline:check`.
Generated files start at 01 and install into a fresh application's public schema.

**Do not run these alongside the inherited migrations. Do not reset a linked project yet.**
The running app still uses the old database contracts. This directory is a temporary build target while those contracts are replaced, not a second deployed schema, parallel MVP, history archive or compatibility layer. At complete cutover the generated replacement will move to `supabase/migrations/`, and obsolete files will be deleted in this branch. No old-data migration is planned.

Currently implemented:
- Academy, three operating divisions, campus, verified server-only bootstrap.
- Deny-by-default RLS, permission checks, immutable request outcomes and actor-labelled activity.
- A shared person identity; responsibilities do not grant account access.
- Retry-safe full person editor, multi-responsibility assignment and paginated people lookup.
- Directory create/edit/inactivate/reactivate with stale revision checks; inline-create response returns selected identity.
- Duplicate-normalized institution names/locality and optional unique EIIN; verified institutions require dated HTTPS source.
- Education levels, Play/Nursery/KG and Class 1–12, three/four-year degree tracks, postgraduate, basic majors/subjects/reasons.
- Multiple active academic years permitted. No guessed institutions, demo payments, automatic intake or public passwords.

Programme/offerings/fees/batches are now implemented by migration 05. Missing at this stage: guardian-link/account provisioning commands, public intake adapter, admission, collection, academic operations, remuneration/expense reports and connected new UI. Seeded education masters are not yet wired into the current old app. No complete fresh-app claim.

A disposable PostgreSQL database with Supabase's managed `auth.users`, `auth.uid()` and API roles can apply generated migrations in filename order, then execute `tests/01_foundation_integrity.sql`. The fixture rolls back all test identities and records. It intentionally requires an unbootstrapped disposable target, never the operating project.

Isolated PGlite verification passed foundation installation, bootstrap privilege checks, RLS enabled on every table, idempotent creation, shared family mobiles, teacher/staff/referrer on one person, normalized duplicate denial, stale edit denial, inactive filtering, whole-result pagination counts, audit actor and outsider rejection. This is not hosted Supabase/Auth/browser acceptance.


Catalogue API: `save_programme`, `save_programme_run`, `save_run_fees`, `save_teaching_batch`, `save_academic_year`, `set_programme_run_active`, `programme_run_setup`, `list_current_programmes`, `public_current_programmes`. Mutations use `p_input` JSON with stable `request_id`, reason and current revision; full edit forms send complete writable fields. Fees use revision 0 on first save. Runs publish only after fees/batch readiness. Public catalogue is not yet adapted to the existing website. SQL regression fixture 02 verifies the new backend contract.
