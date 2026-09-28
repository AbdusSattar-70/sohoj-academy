# V3 clean baseline

This directory is the reviewed V3 schema baseline for a **clean database**.

## Apply order

Run these files in filename order:

1. `0001_v3_platform_crm_admissions.sql`
2. `0002_v3_admissions_finance_academics.sql`
3. `0003_v3_academics_public.sql`
4. `0004_v3_finance_and_current_workflows.sql`

The files are generated from the repository's reviewed V2 schema history and the current V3 forward changes. They contain schema objects, permissions, functions, constraints, indexes, triggers and system configuration only.

They must **not** be applied to the linked V2 project while its existing `supabase_migrations` history is present.

## What this baseline intentionally does not contain

- Student, guardian, enquiry, admission, invoice, payment, journal or other business test rows.
- Auth users.
- Storage fixtures.
- A data migration from V2 into V3.

## Why the source history is retained in Git

The old `supabase/migrations/*.sql` files remain available for reference and forensic review. The V3 baseline is the schema artifact intended for a future clean project/reset.

## Before activation

1. Apply the four baseline files to a disposable clean Supabase database.
2. Run all V3 SQL tests plus RLS/authorization tests.
3. Generate `types/database.ts` from that clean database.
4. Run lint, typecheck, production build and browser acceptance.
5. Only after those gates pass, replace the active `supabase/migrations` path and rehearse the owner's authorized test-project reset.

The baseline is therefore **prepared, not released**.
