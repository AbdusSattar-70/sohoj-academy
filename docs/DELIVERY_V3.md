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


## Fee Plan operator correction (2026-09-29)

The Fee Plans page now opens a specific Create or Edit form from a register. Tuition must be a positive recurring charge; a zero one-time admission charge can represent a waived admission fee. The current Fee Plan save command in `09_preserve_fee_terms_on_save.sql` retains prior terms internally when charges change, so existing admissions and posted finance facts keep their original source. No version number is part of the operator action. The initial migration's malformed function quoting was also repaired.

The linked database may still run an older `save_fee_plan` or `publish_fee_plan` function. The message “The next Fee Plan must start after the previous version” comes from that older database path and will persist until the V3 migration line is applied to a clean development database. Do not reset the owner's database based only on these UI changes; complete the V3 cutover checks first.


### Fee Plan component guard correction

`10_finalize_fee_plan_after_components.sql` replaces the Fee Plan command for a database that already applied `09`. It inserts components while the replacement plan is DRAFT and activates that plan only after all components exist. The published-component immutability guard stays enabled; existing referenced charge rows are never deleted or modified. On a clean reset, both numbered migrations run in order. On a database that has already applied `09`, migration `10` is the forward fix.


### Prospect conversion placement correction

The admission conversion form lists every ACTIVE programme offering with a currently effective published Fee Plan, including offerings in another class or year. Selecting a Prospect keeps the recorded interest when available, otherwise suggests an offering in the saved class. The operator chooses an active batch for that offering. If the chosen offering changes the Prospect's recorded class or interested offering, the admin must explicitly confirm the corrected placement. `12_prospect_admission_placement.sql` rechecks authorization, organization, offering and batch, records the Prospect's before/after class and offering in the audit trail, then calls the existing admission command in one transaction. The underlying admission command still enforces fee availability, seat capacity and duplicate-case prevention. The form surfaces missing published fees and batches so the admin can finish setup before conversion.


### Admission offering visibility and build repair

The admission workbench now fetches active offerings separately through `admission_offering_options()` in migration `13_admission_offering_visibility.sql`. An offering lacking an effective ACTIVE Fee Plan remains visible with “Publish Fee Plan first” and cannot be chosen until charges are ready. The existing admission command continues to enforce fee, capacity and organization checks. This avoids a blank select that concealed the difference between missing offerings and incomplete pricing. The previously empty `types/database.ts` was restored from the repository's existing generated contract, and the Fee Plan form once again accepts the register's Edit action. These changes require migration 13 before the updated admission page can load.


### Admission register layout

The Admissions landing page keeps the new applicant and enquiry conversion entry points, but presents existing cases as a compact table. The register has In progress, Enrolled and Closed views with counts, programme, batch, status and the next action. Opening a row takes staff to the existing admission case workbench for verification, consent, referral, billing and enrollment; historical records remain available without expanding every case on the landing page. Active enrollment is categorized as Enrolled even if the finance account has a remaining receivable.
