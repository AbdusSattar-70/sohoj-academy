# Reusable production reference data

On `feature/sohoj_final`, migration 45 installs reference choices automatically for a fresh database or an existing compatible baseline. `supabase/seed.sql` contains the same insert-only script for explicit reapplication. No Auth/bootstrap user is needed to seed directories.

```bash
git fetch origin
git switch feature/sohoj_final
git pull --ff-only
pnpm install
pnpm exec supabase db push
pnpm dev
```

Use the Supabase project already linked to this repository. No database reset is needed. If its migration history differs from this branch, resolve that mismatch before applying migrations.

To reapply missing reference choices later, run `pnpm seed:reference`, or execute `supabase/seed.sql` in the linked project's SQL Editor. Existing IDs, labels, descriptions, dates, mappings and inactive records are preserved. Rerunning adds only missing codes (or missing names for years/areas); renaming an area's name can therefore cause its original name to be inserted again on explicit reapplication.

| Directory | Added choices |
| --- | --- |
| Classes | Class 1–12, Training, Job Preparation |
| Groups | General, Science, Humanities, Business Studies, Vocational |
| Subjects | 26 school, language and recruitment subject choices |
| Programmes | School Academic, Annual Exam Readiness, Junior Scholarship, SSC A+, HSC, Spoken English, Boys Evening Care, Job Preparation, Primary Teacher Job Preparation |
| Academic years | 2026 active; 2027 inactive for planning |
| Areas | Gopalpur Bazar, Narundi |
| Lead sources | Organic, Website, Phone, WhatsApp, Facebook, Guardian Survey, Leaflet, Miking, in addition to existing choices |
| Guardian relationships | Legal Guardian, in addition to existing choices |
| Expense categories | Rent, Utilities, Internet, Printing, Stationery, Marketing, Cleaning, Repairs, Transport, Software |

Manage and edit academic/CRM choices through Manage CRM. Deactivate irrelevant classes, subjects or programmes. Catalogue availability does not announce an academy service: only an explicitly configured offering can be published. Expense categories map to the existing general operating expense account 5100; the accountant can change those mappings through category maintenance. No expenses or financial balances are posted.

For an admission test using real reusable configuration, complete academy setup, create an offering for your actual year/branch/class/programme, select its subjects, publish your actual fee plan, then create its batch. Enter a real student only when their details and guardian consent are available. Fees, schedules, classrooms, schools, teachers and verified consent are not inferred by the seed.

The academic years are explicit 2026/2027 choices, not a yearly automation; add future years through Manage CRM. Data is scoped to the SOHOJ organization. It does not create other organizations or branches.

## Optional fictional examples

The old development-only script is preserved at `supabase/seeds/development_demo.sql`; it is excluded from automatic seeding and production commands. Execute it manually in SQL Editor only on a disposable development project after bootstrap. See [development examples](INSTANT_DEMO_SETUP.md). Running the new reference seed does not remove previously created demo records.
