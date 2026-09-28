# V3 clean baseline

This directory is the reviewed V3 schema baseline for a **clean database**.

On branch `feature/refactor`, promote these files into the active migration path with:

```bash
pnpm run activate:v3-migrations
pnpm run verify:v3-baseline
```

That writes:

| Baseline source | Active migration |
| --- | --- |
| `0001_v3_platform_crm_admissions.sql` | `01_platform_crm_admissions.sql` |
| `0002_v3_admissions_finance_academics.sql` | `02_admissions_finance_academics.sql` |
| `0003_v3_academics_public.sql` | `03_academics_public.sql` |
| `0004_v3_finance_and_current_workflows.sql` | `04_finance_and_current_workflows.sql` |
| `0005_v3_direct_admin_finance.sql` | `05_direct_admin_finance.sql` |
| `0006_v3_direct_admin_accounting.sql` | `06_direct_admin_accounting.sql` |
| `0007_v3_attendance_command.sql` | `07_attendance_command.sql` |

and moves prior V2 SQL into `supabase/migrations_v2_archive/`.

## Apply on a disposable clean database

1. Confirm you are **not** using production, or you have authorized a full reset of a development project.
2. Reset the database (Supabase dashboard → Database → Reset, or new project).
3. From the repo root on `feature/refactor`:

```bash
pnpm run activate:v3-migrations
pnpm run verify:v3-baseline
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm exec supabase gen types typescript --linked > types/database.ts
pnpm run build
```

See `docs/V3_DATABASE_CUTOVER.md` for the full operator checklist.

## What this baseline intentionally does not contain

- Student, guardian, enquiry, admission, invoice, payment, journal or other business test rows.
- Auth users.
- Storage fixtures.
- A data migration from V2 into V3.
