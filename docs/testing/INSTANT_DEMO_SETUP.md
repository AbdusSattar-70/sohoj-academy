# Optional development examples

Automatic seeding now uses reusable production reference data. See [reference data setup](REUSABLE_REFERENCE_DATA.md) for normal installation and immediate configuration testing.

The original fictional workflow examples are preserved at `supabase/seeds/development_demo.sql`. They are excluded from automatic seeding. To use them, install this branch’s migrations in a disposable development Supabase project, create your own Auth account, run `bootstrap_admin`, then execute the complete script manually in that project’s SQL Editor.

The script creates two public demo offerings, fictional fee plans, three batches, six Prospects, five admission cases, student identities, simulated consent/payment records and two pending staff-access requests. It creates no Auth users or passwords. Enrollment follows the current payment policy. A completion marker prevents repeat creation and preserves edits.

Do not run it in an operating academy. Running the reusable reference seed does not delete examples already installed by this optional script. No reset is needed to install reference data in a compatible database.
