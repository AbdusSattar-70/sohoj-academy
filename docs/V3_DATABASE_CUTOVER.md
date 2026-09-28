# V3 database cutover (clean reset)

Updated 2026-09-29. Branch: `feature/refactor`.

## Goal

Replace the long V2 migration chain with seven ordered V3 baseline migrations
named `01_` … `07_`. This is a **schema reset**, not a data migration.

## Prerequisites

- You have a **disposable** Supabase project (or explicit permission to reset
  the linked development database).
- Local repo is on `feature/refactor` and up to date.
- V2 history will be archived under `supabase/migrations_v2_archive/` when you
  run the activation script.

## Active migration set (after activation)

```text
supabase/migrations/01_platform_crm_admissions.sql
supabase/migrations/02_admissions_finance_academics.sql
supabase/migrations/03_academics_public.sql
supabase/migrations/04_finance_and_current_workflows.sql
supabase/migrations/05_direct_admin_finance.sql
supabase/migrations/06_direct_admin_accounting.sql
supabase/migrations/07_attendance_command.sql
```

Source of truth for schema text remains `supabase/baseline_v3/`.

## Operator steps

```bash
git fetch origin
git switch feature/refactor
git pull --ff-only origin feature/refactor

# Promote baseline_v3 → supabase/migrations/01_…07_ and archive V2 SQL
pnpm run activate:v3-migrations
pnpm run verify:v3-baseline

# Reset the linked *development* database only (dashboard or CLI),
# then apply the V3 chain:
pnpm exec supabase migration list
pnpm exec supabase db push

# Fresh types from the clean schema
pnpm exec supabase gen types typescript --linked > types/database.ts

pnpm run build
```

Commit the activated migrations after a successful push if your working tree shows
new `01_`–`07_` files and the V2 archive (so the branch records the cutover):

```bash
git add supabase/migrations supabase/migrations_v2_archive
git status
git commit -m "chore(db): activate V3 baseline migrations 01-07"
git push origin feature/refactor
```

If `db push` reports remote versions that are not in local migrations, the
project still has V2 history. Reset that project first, or link a new empty
project:

```bash
pnpm exec supabase link --project-ref <DISPOSABLE_PROJECT_REF>
pnpm exec supabase db push
```

## After push succeeds

1. Bootstrap admin / organization through the existing ERP bootstrap path.
2. Smoke: Manage CRM directories → offering → fee plan → batch → staff intake
   → case workbench → accept.
3. Teacher path: attendance or class log submit → admin review queue.
4. Record results in `docs/STATUS_V3.md`.

## Non-goals

- Migrating live V2 business rows into V3.
- Running V2 archive files against the clean database.
- Softening RLS or audit for convenience.

## Rollback

- Re-link the previous project, or restore from backup.
- To restore the V2 migration path in Git only: copy
  `supabase/migrations_v2_archive/*.sql` back into `supabase/migrations/` and
  remove the `01_`–`07_` files (prefer a dedicated branch rather than rewriting
  shared history).
