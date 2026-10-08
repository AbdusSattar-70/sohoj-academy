# Sohoj Academy: final workable release review

Reviewed on 2026-10-08. Branch: `feature/sohoj_final`. Source revision: `19cea4203191bdc149205830c4317a8a9925b187`.

## Release conclusion

The repository contains a substantial working implementation, not just screens or a scaffold. Admission, billing, double-entry accounting, staff onboarding, academic operations and many finance extensions exist. It is **not ready to declare fully workable for daily academy operation** yet: teacher qualification setup is inaccessible through the current app, lint fails, academic reporting remains incomplete, and actual hosted/browser acceptance and recovery evidence are outstanding.

Complete the core academy workflow before adding more advanced accounting. A successful build and SQL fixtures are useful evidence, but do not demonstrate that a receptionist and a newly invited teacher can finish their work in a deployed browser.

This is a review and delivery backlog, not an implementation of the gaps. No production database, Auth account, financial record or deployment was changed during review.

## Scope and evidence

The review covered the repository inventory, public and dashboard route tree, domain modules, configuration, dependency/CI scripts, architecture and operator documents, all migration and SQL-fixture files, and the connected setup → offering → batch → staff → admission → billing → teaching workflows. Findings combine source inspection with the checks below; absent UI/RPC findings are based on the current checked-in route/module/command inventory. This is not a penetration test or a claim of exhaustive proof of every possible execution path.

| Check | Result | What it establishes |
| --- | --- | --- |
| Remote source revision | Verified branch head above; separate detached worktree used | Review is against the remote final branch rather than a different local branch |
| Database install | All **45 migrations** applied in isolated PGlite | SQL installation is internally consistent under the harness |
| Database fixtures | All **33 existing SQL fixtures** passed | Existing fixtures exercise their documented admission, access and finance scenarios |
| Database inventory | **133 public application tables, 198 public functions** in the isolated install | Current footprint; old documentation counts are stale |
| Reusable reference seed | Applied after migration 45 without errors | Automatic reference seed works against the migrated schema |
| Onboarding reproduction | Invited teacher: 1 staff role, **0 subject qualifications**; invited accountant: **0 staff roles** | Concrete qualification and role-mapping gaps described below |
| ESLint | **3 errors, 20 warnings** | Current lint release gate fails |
| Route type generation | Passed | Routes generated successfully |
| TypeScript | `tsc --noEmit` passed | Static types compile |
| Production build | `next build --webpack` passed | Application compiles and generates routes with placeholder Supabase environment |
| Live Supabase/browser/printer/concurrency/restore | Not performed | These remain acceptance gates, not inferred passes |

Database harness details: managed `auth.users`, `auth.uid`, roles and Storage catalog/grants were mocked; the `pgcrypto` extension installation was omitted because this harness does not load it and no digest calls were found in the migrations. Initially fixture 14 failed because the mock lacked managed Storage usage/select/insert grants; correcting the mock made it pass. This was a harness limitation, not a confirmed repository defect. The harness runs as the database owner except where fixtures switch roles; it does not simulate the full hosted Auth/Storage service or simultaneous HTTP requests.

Dependency installation downloaded the locked packages, but the environment's pnpm 11 stopped on its ignored-build policy for `unrs-resolver`. The repository specifies pnpm 10.12.4 and CI explicitly installs that version. Checks were run directly through the installed ESLint, Next and TypeScript binaries. Treat this as an environment/toolchain discrepancy, not evidence that the intended pnpm 10 install fails. Generated environment files were not included in the review commit.

## What already exists

Do not rebuild these features simply because older roadmap paragraphs say they are pending. They still need acceptance where indicated.

| Area | Present implementation | Main evidence |
| --- | --- | --- |
| Public CRM | Account-free enquiry/application form, acknowledgement, ERP-driven programme cards and subject choices | `app/interest`, `components/public/interest-form.tsx`, `modules/home/program-section.tsx`, `modules/offerings/queries.ts` |
| Directory and setup | Years, classes, groups, subjects, programmes, schools, sources, relationships, setup gates and reusable reference choices | `modules/crm/manage`, `modules/platform/setup`, migrations 08, 13, 45 |
| Offerings/fees/batches | Offering register/edit, public controls, fee plans, permitted discounts, batch create/edit and capacity checks | `modules/offerings`, `modules/admissions/components/batch-register.tsx`, migrations 08–09 |
| Admission | Staff-direct intake, Prospect conversion, identity/placement review, referral, physical paper consent, finalization, permanent student identity and initial invoice | `modules/admissions`, migration 09, fixtures 01 and 04 |
| Student lifecycle | Existing-student draft, transfer, merge, withdrawal/completion and retained finance history | `modules/students/lifecycle`, migration 09 |
| Student finance | Collection, receipts, discounts/scholarships, cancellations/refunds, recurring invoice preview/posting and outstanding balances | `modules/finance/operations`, migrations 09–10, 14 |
| Teaching | Rooms, curriculum versions, routines, dated sessions, attendance review, class logs, homework checks, question-bank review and assessment-result review | `modules/academics`, migration 11 |
| Auth/access | Verified staff requests, invitation/recovery/email change, role/permission editors and an actual sign-out button | `modules/platform/access`, `modules/settings`, `components/erp/erp-account.tsx`, migration 16 |
| Workforce | Own work, tasks, attendance, compensation terms, payslips and own finance | `modules/workforce`, `modules/finance/payroll`, migrations 17–19, 33 |
| Accounting | Journals, account mappings, student receivables, vendor/staff/teacher liabilities, expenses, advances and settlements | `modules/finance/accounting`, migrations 05, 10 |
| Extended finance | Daily/monthly close, purchases, private documents, reimbursements, assets, cash handovers/counters, recurring expenses, receivables follow-up, capital, budgets, bank matching, cash flow, year-end, supplier statements, consumable stock and partial procurement | Finance modules; migrations 20–44; fixtures 10–33 |
| Governance/help | Audit search, approvals, policies, access controls and Bengali finance guide | `modules/governance`, `modules/settings`, `modules/help/finance-guide.bn.json` |

Physical paper admission consent is intentional. The current finance delivery document explicitly excludes digital admission consent. Do not add student/guardian accounts, digital-consent upload or a consent-upload prerequisite to this backlog. Private finance evidence is a different, implemented feature.

## Prioritized missing work

Priority meanings: **P0** blocks the core release workflow or required quality gate; **P1** should be completed for a dependable daily-operation release; **P2** may be deferred with an explicit operating limit; **decision** requires an agreed product scope rather than silently treating a limitation as a bug.

### P0: unblock the basic academy workflow

| ID | Finding and evidence | Required delivery | Acceptance |
| --- | --- | --- | --- |
| F01 | **No current subject-qualification management path for teachers.** `academic_command` requires effective teaching-role and `staff_subject_assignments` records. `academic_workspace` lists teachers with subject assignments. `StaffPage`/`StaffRegister` expose identity and requests but no qualification editor. Migration 16 disables `create_staff_member`, replacing the older path that inserted qualifications. Actual onboarding reproduction created a teacher with zero qualifications. | Add audited admin assignment/edit/retirement of subject qualifications with effective dates; expose current teaching responsibilities and the next setup action. Preserve verified-request onboarding. | Invite a new teacher using the UI, assign an actual subject, schedule a class and let that teacher record it without SQL Editor intervention. Reject expired/unqualified/wrong-branch assignments. |
| F02 | **Lint fails.** `app/auth/update-password/page.tsx:15` and `modules/finance/counters/register.tsx:13` violate `react-hooks/set-state-in-effect`; `modules/finance/operations/collection-form.tsx:9` violates `react/no-unescaped-entities`. CI runs lint before typecheck/build. | Fix the three actual errors; review relevant effect/dependency warnings and remove unused imports where appropriate. Keep rules enabled. | Pinned pnpm 10.12.4 install followed by `pnpm check` passes; account recovery and counter deep-link behavior remain correct. |
| F03 | **Staff responsibility mapping is inconsistent.** `review_staff_access` in migration 16 joins `staff_roles.code = assigned_role`. System roles use `ADMIN`/`ACCOUNTANT`; seeded staff roles use `ADMINISTRATION`/`ACCOUNTING`. Actual invited ACCOUNTANT reproduction created no staff responsibility assignment. Changing operational access in `set_user_operational_roles` does not provide a teaching-qualification lifecycle. | Map access roles to staff responsibilities deliberately; support academic-director/teaching responsibilities as applicable; keep access and qualification separate but consistent. | New accountant has Accounting responsibility; additional admin has Administration responsibility; promotions/reassignments update the intended effective responsibility without duplicate primary roles or stale teaching eligibility. |

### P1: complete academic operation and truthful reporting

| ID | Finding and evidence | Required delivery | Acceptance |
| --- | --- | --- | --- |
| F04 | **Programme subject selection is not enforced in academic scheduling.** Migration 11 checks that the subject is active in the organization and the teacher qualified, but routine/session/curriculum creation does not require membership in `programme_offering_subjects`. Workspace subject choices are organization-wide. | Filter UI choices by batch offering and enforce the same rule in commands. Define a controlled policy for changing subject membership after teaching history exists. | An unrelated qualified subject cannot be scheduled under a Spoken English offering; legitimate retained historical sessions remain readable. |
| F05 | **No consolidated student weekly/monthly academic progress report.** Assessment results, attendance and homework exist separately; no progress-report route/module or aggregate academic report was found. Student detail exposes identity, contacts, admissions, enrollment and finance rather than a reviewed academic summary. | Add period-based student/batch progress, assessment categories such as CT-1/CT-2/weekly test, grade/weight configuration, reviewed attendance/homework inputs, comments and print/export. Define which components are manual versus derived. | A real enrolled student's report derives only from authoritative records; missing work is distinct from zero/absence; correction history remains traceable; long Bengali names print correctly. |
| F06 | **Question bank is not an exam-paper workflow.** Current commands cover question draft/revision/submission/review; no paper assembly, marks/section ordering or separate student paper/answer key printing was found. | Build an approved-question selector, paper draft, ordering/marks, final review and printable paper/key. Keep unpublished answers out of student-facing output. | Produce one realistic model test from approved questions and print student paper plus separate answer key without manual copy/paste. |
| F07 | **Curriculum progress lacks an operational coverage/recovery view.** Pinned curriculum and per-session progress exist, but no consolidated gap register or recovery action is exposed. `ClassLogForm` defaults every unsaved unit to `COVERED`, which can overstate teaching if left unchanged. | Default units to an explicit unreviewed/not-covered choice, aggregate taught versus planned coverage and schedule/track recovery classes from gaps. | Saving a new log never silently claims all units taught; incomplete units stay visible until evidenced recovery. |
| F08 | **Routine maintenance is incomplete for normal changes.** Current academic actions create/retire routines and create/cancel dated sessions; no explicit reschedule/substitute command or teacher leave/availability workflow was found. Existing submitted/approved attendance blocks cancellation. | Add a controlled replacement/reschedule process, teacher unavailability and substitute selection; preserve original session evidence and approved work. | Handle a teacher's one-day absence and a recurring timetable change without deleting history, double-booking, or requiring database edits. |
| F09 | **Assessment absence/nonparticipation and term correction need explicit handling.** The result contract requires a numeric score for each roster entry; the UI requires marks for every student. Create/publish exist, but draft term editing/cancellation is not exposed by `assessmentCommandSchema`. | Add absent/excused/not-assessed states and an authorized assessment draft-edit/cancel lifecycle. Define correction after publication without overwriting approved results. | An absent student is not forced to receive zero; an erroneous draft date/max marks can be corrected; official results remain auditable. |

### P1: make operator behavior and data reliable

| ID | Finding and evidence | Required delivery | Acceptance |
| --- | --- | --- | --- |
| F10 | **Read errors can look like empty successful data.** Staff/student/Prospect queries often use `data ?? []` without checking errors. Offering-subject loading catches failures and returns `[]`; public offering reads return null on failure and the homepage maps that to an empty list. | Distinguish genuine empty state from unavailable data. Show a recoverable failure and retain last-known selections; prevent saving a false empty subject selection after a failed read. | Disconnect/deny a relevant read: the operator sees a failure, not “no students” or an apparently empty configured offering. |
| F11 | **Large legacy workspaces remain unbounded.** `finance_workspace()` aggregates all admissions/invoices/payments/refunds/runs; invoice print fetches the whole workspace and finds one invoice. Staff, directory and offering overview reads are also unpaged. New finance registers already provide pagination. | Add paged/searchable legacy registers and record-scoped detail/print RPCs. Keep exact totals and deterministic ordering; avoid silently relying on a service row limit for lookup completeness. | With more than 1,000 directory/history rows, new/old records are findable, totals are accurate, one invoice prints independently and load times stay acceptable. |
| F12 | **Retry protection is inconsistent at the UI boundary.** Many finance forms preserve a request ID, but class-log/assessment actions generate new IDs each attempt; referral server action generates its own ID. Finalization creates a fresh ID on each click, though business-state guards provide additional protection. | Preserve mutation identity for identical retries, add clear uncertain-result guidance and draft recovery for critical operator forms. Do not automatically retry money mutations. | Drop the response after successful save, retry the same input and get the existing result rather than duplicate drafts/revisions/events. Verify financial paths and academic paths separately. |
| F13 | **Areas are seeded but not editable in Manage CRM.** `masterEntities` omits `area`; queries provide areas only as school selectors. Reference seed matches areas by name, so renaming an area then explicitly reseeding can reinsert the old name. | Add audited area maintenance and stable identity for seeded named choices; provide deactivate/reactivate. Preserve school/Prospect history. | Edit/deactivate Narundi through UI; school selection reflects it; repeated reference seeding preserves the intended edited choice without recreating its old label. |
| F14 | **Language toggle coverage is incomplete.** Public form labels include combined English/Bangla; staff register, academic operations, assessment/question screens, account/settings forms and sign-out retain English literals. Finance is more extensively localized. | Finish English/Bangla labels, errors, empty states, date/currency wording and print language policy across the real operator paths. | Switch language during admission, teaching and collection: controls and feedback consistently follow the selected language; user-entered names remain intact. |
| F15 | **Operator guidance describes obsolete behavior.** Help claims direct intake creates a Prospect and case together, contrary to current direct intake. It also generalizes independent financial approval, while current authorized admin actions are direct. README/handoff/setup/schema still mention older branches, 13/15/22 migrations and old table counts; Staff page links to a previous branch. | Establish a current release guide, update in-app help and installation instructions, distinguish historic delivery notes, and link the actual final branch. | A new operator follows one guide to configure, admit, collect and schedule without obsolete actions; an existing installation is updated without reset instructions being mistaken for an upgrade. |
| F16 | **Printing requires confirmed operating format and physical acceptance.** Current admission is intentionally two-page A4; styles reserve 24mm letterhead space, use 20mm on page 2 and fixed 8mm/12mm print margins. This differs from earlier single-page/2-inch-pad preferences. Some academy-name values are unused by paper/statement renderers. | Agree the current form/pad specification, then implement/configure page count, reserved header, margins, academy identity and print language for the actual paper stock. | Print blank and populated application, receipt, statement and progress report on the academy's real pad at 100%; no clipping, overlap, extra chrome or wrong academy identity. Do not automatically revert to an old preference without confirming the current specification. |

### P1 release gates: implemented paths still needing operational proof

| ID | Missing evidence/capability | Completion requirement |
| --- | --- | --- |
| F17 | **Hosted acceptance and automated regression coverage.** Current CI runs lint/typecheck/build only; no database fixture job or browser suite is wired. Existing SQL fixtures do not call the main academic command/result/question/homework workflows. | Add reproducible DB fixture execution to CI, academic/security fixtures and a browser smoke suite. Run deployed Auth invitations/recovery, server actions, Storage upload/download, role restrictions and main workflows. Run simultaneous final-seat admissions, duplicate collection submissions and schedule conflicts. |
| F18 | **Verified backup/restore and release recovery.** No checked-in demonstrated restore/deployment recovery procedure or completed restore evidence was found; existing status explicitly leaves restore outstanding. | Document deployment/env/migration sequence, rollback-by-forward-fix practice, database/Auth/Storage recovery boundaries, backup frequency, restore target and operator contacts. Demonstrate database plus private finance-file restore in an isolated target and reconcile identifiers/balances. |
| F19 | **Operational failure monitoring.** Current route error boundary writes to browser console; no application-wide monitoring/alert/recovery ownership is configured in repository. | Add suitably scoped production error capture, uptime/failed-job monitoring and support references; redact personal data and secrets. Provide a clear uncertain-posting investigation path. |
| F20 | **Public intake abuse controls are incomplete.** Server-side form has a honeypot; RPC has payload bounds and a two-minute same-mobile/same-name duplicate guard. Anonymous RPC callers can bypass the form and vary those values. | Add controls at a boundary that also protects direct RPC usage: appropriate throttling/quotas and deployment abuse handling, without preventing shared-mobile sibling enquiries. Document the actual privacy/contact-consent text and handling. |

### P2 or explicit scope decisions

| ID | Current limit | Recommended treatment |
| --- | --- | --- |
| F21 | **Branch management/isolation is not a completed feature.** Branch entities and some branch checks exist, but no branch-opening management route was found; Settings explicitly withholds scoped assignments until enforcement is complete. `has_permission` ignores assignment branch, and public intake chooses the first active branch instead of deriving routing from the submitted offering. | For a single-campus release, state that limit and keep scoped assignments unavailable. If multi-branch is required, promote to P0: implement branch maintenance, server/RLS/RPC scope, branch-aware intake and independent branch acceptance. A UI filter alone is insufficient. |
| F22 | **One active enrollment per student/year.** A unique index and creation/finalization checks enforce this; student detail documents it. A student cannot concurrently take SSC preparation plus Spoken English/Evening Care in the same year through this model. | Decide whether this is the intended initial scope. If simultaneous programmes are required, promote to P1 and change programme-level enrollment/consent/fees/capacity semantics together rather than removing only the index. |
| F23 | **Routine family communications are manual.** Receivables can copy a reminder draft; no delivered SMS/email attendance/results/fee notification integration was found. | Manual guardian calls/messages can support the first release. Automated sending requires chosen provider, verified contacts, consent, delivery logs and duplicate-safe dispatch; document this as an optional integration until authorized. |
| F24 | **Known finance exception extensions remain.** `FINANCE_DELIVERY_STATUS.md` lists full payroll cancellation/overpayment recovery, statutory liabilities, interrupted cashier reassignment/shortage resolution/transfer reversal and advanced asset accounting. | Avoid claiming these complete. Promote any exception encountered in normal operating policy before launch; defer advanced assets/statutory automation if excluded from the agreed first release. Existing signed payroll corrections, counter returns and year-end reversals must not be listed as entirely missing. |
| F25 | **Recurring work is operator-triggered.** Invoice billing and recurring expenses provide explicit preview/post/create workflows; no checked-in scheduler/worker is present. | An operator calendar/checklist is sufficient initially. If automatic runs are required, add an authenticated scheduler, idempotency, retries/failed-job register and close-period handling. |
| F26 | **Catalogue availability is broader than current published academy services.** Migration 45 adds reusable choices, but deliberately does not create actual offerings, fee plans, batches, rooms, teachers or schools. | Configure only actual services and deactivate irrelevant catalogue entries. Immediate production-safe testing still needs real configured offering/fee/batch and a qualified teacher; do not fabricate students, payments or consent to fill dashboards. |

## Delivery sequence

Each implementation step should be independently committed to `feature/sohoj_final`, with its validation result recorded. No clean database reset is needed for this review. New schema fixes should append migrations after 45; do not rewrite applied migrations to make upgrade history appear simpler.

1. **Quality and staff setup:** F02, F01, F03. Exit: a fresh verified teacher/accountant can operate through the app; required checks pass.
2. **One real academy workflow:** configure actual offering/fees/batch/room; fix F04 and highest-impact F10/F12 cases; run F17 admission → invoice → partial collection → activation → class → attendance → homework → assessment end to end.
3. **Academic completion:** F05–F09. Exit: weekly/monthly progress and one model-test paper can be produced from reviewed work, with absences and recovery handled honestly.
4. **Operator readiness:** F13–F16, bounded high-volume paths in F11, remaining F10/F12 cases. Exit: Bengali/English workflows and the current paper pad work for the actual receptionist and teacher.
5. **Release proof:** F17–F20. Exit: hosted regression, security/concurrency checks, deployment procedure, monitoring and successful restore evidence.
6. **Scope-dependent extensions:** resolve F21–F26 explicitly. Implement promoted items before launch; record deferred operating limits in the release notes.

## Minimum acceptance scenarios for the final workable release

Use a disposable acceptance project for deliberately false identities and simulated payments. Production reference data stays reusable; acceptance transactions do not become real production accounts.

| Scenario | Required result |
| --- | --- |
| Fresh install and existing-baseline upgrade | Migrations install cleanly; reference seed preserves edits; no invented credentials or transactions; setup reopens completed steps |
| New teacher and accountant | Request → verify → secure setup → responsibilities/qualifications → intended workspace; no self-promotion; teacher cannot call finance/admin mutations |
| Public application | Open offering/subjects render; accepted unverified preferences remain in original snapshot; CRM acknowledges honestly; submission abuse/error behavior is distinguishable |
| Direct and Prospect admission | Direct intake does not invent a Prospect; conversion retains original request; placement/fee/referral/paper consent reviewed; correction invalidates stale consent |
| Admission and money | Finalization issues one identity/invoice; partial/full payment, allowed adjustment and refund balance correctly; repeated/interrupted requests do not duplicate money; full batch prevents extra activation |
| Teaching | Qualified teacher schedules only an offered subject; routine conflict, absence/substitute and reschedule are handled; attendance/class log/homework/results flow to independent review |
| Reporting | Approved marks, absence and incomplete work remain distinct; correct weighted report/grade and gap recovery; approved questions produce an answer-free student test paper |
| Finance daily/monthly close | Opening cash → collection → expenses → handover/count → close; posted journals balance; period lock rejects prohibited posting; payroll/supplier corrections retain originals |
| Permissions and scope | Admin/operator/teacher/accountant/referrer see intended work; unauthorized direct URLs/RPCs/Storage fail; branch restrictions tested if enabled |
| Failure and recovery | Read outage does not impersonate emptiness; uncertain save can be inspected; restored database/files reconcile with receipts, invoices and audit |
| Language and printing | Phone-sized workflow works; selected language is consistent; long names/addresses fit the agreed actual print stock and page count |

## Completion definition

The project is final-workable when P0 items are fixed, applicable P1 work and release gates pass, F21/F22 and printing scope are explicitly settled, actual academy configuration exists, and the owner/operator/teacher can finish the acceptance scenarios without developer database intervention. Record the deployed commit, migration versions, test date/results, remaining limits and recovery ownership in release notes.

A deferred payment gateway, automatic SMS, advanced asset accounting or digital admission consent is not automatically a blocker for an agreed single-campus, cash/manual-communication, paper-consent release. Missing teacher setup and incomplete academic progress reporting directly affect the core coaching-center product and should be addressed before more finance expansion.
