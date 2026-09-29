# V3 build and database transition

Status: active GitHub refactor; **not ready for the database reset or production**. Updated 2026-09-29.

## Starting point

The current branch contains V2 code, 50 migration files numbered through `0052`, and 25 SQL tests. The linked Supabase project contains **test data only**; the owner authorized a clean database reset for V3. The reset has not been performed. The repository history preserves V2 for reference even after its old documentation is removed.

Do not simply delete applied migration files and run `db push` against the existing V2 migration history. The V3 database must be initialized from a reviewed baseline in a clean development environment; the linked project reset happens only after the V3 baseline, bootstrap and verification path are ready.

## Delivery order

1. **Baseline and inventory.** Capture the linked project's actual migration list and roles, compare schema to Git, identify test-only Auth accounts and Storage fixtures, and export a disposable backup for diagnosis. Record V2 route/component/function references before removing code. Do not carry test student, invoice or journal rows into V3.
2. **Clean V3 schema.** Create an independently reviewable initial migration (or separated baseline migration set) for platform, catalog, CRM, admissions, academics and Finance integrity, with no `pg_get_functiondef` text surgery. Small later changes use forward migrations. Generate database types from the V3 database and remove temporary casts as modules move over.
3. **Admin admission vertical slice.** Build direct/prospect/existing Student entry, eligibility explanations, dedicated case detail and action steps, structured referral, physical consent, acceptance, inline invoice/payment and enrollment. Keep Finance the owner of money. Use focused actions and return-to-case behavior.
4. **Admin setup and navigation.** Explicit route ordering, Academy Settings, Academic Directory, offering/batch/Fee Plan registers and small Operating Rules. Search/create reusable records with permissions and duplicate review. Update Help alongside the actual UI.
5. **Teacher vertical slice.** Assigned classes, draft/submit attendance, assessments, questions and logs, plus admin review/finalization/rejection queue. Direct admin entries retain audit without a second approval step.
6. **Finance and remaining modules.** Reconnect discount, cancellation, refund, recurring billing, GL, advances/payables and compensation to the new canonical records. Confirm each scenario and amount; remove V2 implementations only after its V3 replacement works.
7. **Cutover.** On a clean linked development project, rehearse baseline, Auth/bootstrap, roles, RLS, public catalogue and full operator journey. Then reset the owner's test-only linked project, apply V3 migrations, bootstrap the admin, regenerate types and verify the same journey. Record the exact commands and results at that time; no database deletion occurs as part of documentation cleanup.

## Code removal rules

- Build an import/reference graph covering app routes, components, assets, RPCs, tests and scripts. Mark a candidate as active, compatibility, generated or unused.
- Remove demonstrably unused aliases and components, such as the deprecated showcase alias and disconnected old card section, after checking dynamic routes and public asset references. Keep useful redirects (for example `/auth/sign-up` → `/interest`) until an explicit compatibility decision.
- Replace old route/module code in slices. Remove superseded V2 migration files from the **active V3 migration path** only when the clean baseline is ready and the linked test database reset is coordinated. Git history remains available; never rewrite a database still using the V2 migration table.
- Do not remove questions, finance or academic behavior just because its screen is awkward. Feature parity is verified with behavior-focused tests before cutting over.

## Gates for each slice

- A real operator can complete the task without manual cross-page navigation and can understand every blocker.
- Database constraints, RLS, authorization, idempotency, retries, capacity and financial balancing are tested; teacher self-finalization is denied.
- SQL migrations and rollback-only domain scenarios run in CI alongside lint, typecheck and production build. Signed-in admin/teacher browser flows, keyboard/touch use and A4 paper form/actual receipt print pass in the linked development environment.
- Published status docs report **implemented**, **database-tested**, **browser-tested** and **released** separately. Do not call a compiling page operationally complete.


## GitHub branch progress (2026-09-29)

- Operating Rules now has a focused editor showing current values and Save Rule; Access & Security handles staff roles and assignments separately. The existing database history remains internal for audit.
- The admission case shows payment methods and can post money received with a receipt without leaving the case. Student Accounts receives a validated admission return route, preselects the case and returns after a successful side action.
- The current GitHub branch still contains the V2 migration line and maker-checker workflows outside teacher submissions. This UI progress is not a V3 database cutover. Complete the transactional admin commands, clean baseline, case-level Finance adjustments and teacher review scope before the owner resets the test database.
- No build, database migration or end-to-end test was run for these GitHub changes at the owner's request. Do not claim operational readiness from the UI changes alone.
