# Paperless finance and workforce management

Branch: `feature/finance_accounting_management`. Base: redesign_refactor, migration 16. This extends the existing ledger, billing and identity architecture; it does not introduce competing student, staff or accounting records.

## Review findings and ordered delivery plan

| Priority | Area | Existing capability | Gap / required outcome |
| --- | --- | --- | --- |
| P0 | Staff attendance | Approved academic session attendance | Staff daily presence, check-in/out, breaks, absence/leave, corrected evidence and monthly own hours are missing. Student attendance is not staff attendance. |
| P0 | Personal workspace | Teacher class lists and own referral statement | A common staff page for attendance, tasks and financial position; teacher shortcuts must lead directly to student attendance. |
| P0 | Compensation terms | Revenue-share teacher policy and approved runs | Fixed/hourly/hybrid terms, agreed pay day and a clearly labelled estimate. Never present an estimate as approved debt or promise payment. |
| P0 | Tasks and accountability | Academic workflow review | Staff assignments, due dates, progress, blocker explanation, completion submission and admin acceptance. Completion percentage is declared progress, not a salary deduction formula. |
| P0 | Payroll | Migration 19: fixed/hourly/hybrid salary preview, posting, payslips and cash/advance settlement | Historical contract recovery, statutory deduction policies and documented payroll corrections remain. No automatic task/absence deduction or second acquisition accrual. |
| P0 | Daily close | Migration 20: denomination count, statement comparison, variance/recount evidence and stale detection | Migration 30 adds recipient receipt/dispute evidence. Migration 31 adds counter responsibility and internal opening-float transfers; ongoing top-ups/return transfers remain. |
| P0 | Month close | Migration 21: monthly P&L, balance sheet, trial balance, cash movement, close/reopen and write guards | Cost-centre/programme filters, classified cash-flow statements and fiscal year-end closing remain. |
| P1 | Expenses and procurement | Vendors, expenses, advances and payables | Inline vendor/category selection, attachments with private storage, reimbursements, recurring rent/utilities, purchase order and receipt matching. |
| P1 | Assets | Permission names exist | Asset register, custody, purchase cost, depreciation, maintenance, disposal and linked ledger evidence. |
| P1 | Collections | Invoices, discounts, scholarships, payment/refund and recurring invoices | Aging buckets, parent statement, arrears tasks, instalment commitments, safe reminders, online payment verification and duplicate transaction protection. |
| P1 | Reporting | Audit day totals and referral net collection | Programme/batch contribution after discounts, teacher expense and referral expense; distinguish accrual profit, collected cash and owner withdrawals. |
| P1 | Reliability | Request IDs, audit, row locks and scoped reads | Bounded paginated registers, recovery after interrupted saves, failed operation visibility, backups and a demonstrated restore procedure. |
| P1 | Paperless consent | Physical consent reference and printable forms | Optional verified digital consent evidence, private document register and retention/access policy. Physical-only consent is still a paper dependency; do not claim it is already paperless. |
| P2 | Planning | Operating policies | Budgets versus actuals, cash runway, cost centres, bank import matching, recurring expense reminders, inventory consumables and supplier statements. |

Implement one coherent feature, commit it, then move to the next. Baseline percentages come from current operating rules and the teacher Revenue Sharing proposal; contract-specific terms must be agreed and recorded, not inferred from job title. Do not reset the live database.

## Daily operation

1. Admin opens workforce operations, records actual staff attendance or absence/leave and assigns work. An attendance correction retains actor, reason and previous values. Staff see only their own data.
2. Each person opens My work: today's record, month present days/hours, assigned tasks, blockers, current agreed compensation basis and actual posted financial statement. Teacher opens My classes → session → student attendance; academic submissions continue through administrative review.
3. Staff reports progress and a blocker note. At 100%, submit completion; the administrator accepts it or returns it with a reason. Reported progress cannot automatically reduce agreed pay.
4. Admission produces the invoice. Cash, bank or mobile money actually received produces a numbered receipt and allocation. Discounts/scholarships are separately labelled reductions, never payments. Due remains due without invented collection.
5. Expense paid now posts cash expense; on-account expense posts payable. Advances remain assets until verified settlement. Referrer reward accrues only on qualifying net tuition collections, with refund corrections.
6. Cashier counts funds and reconciles external statements. Differences stay visible until resolved; no overwriting ledger balances to make a match.

## Monthly pay workflow

Configure compensation per staff: fixed monthly, hourly, revenue share or hybrid. Record effective date and scheduled pay day (1–28); corrections apply to unposted work only. Historical payroll retains the term snapshot. Attendance records are evidence, not independently computed teaching sessions: approved teaching workload and revenue share remain the existing engine's basis.

Prepare payroll preview → review attendance, leave and approved workload → add explained allowances/deductions → admin posts once → liability and expense journal → settle cash/bank or advance offset → personal itemised payslip and statement. Staff academic completion review remains; authorised admin financial posting does not require a second administrator. A draft estimate, posted entitlement, settled amount and scheduled pay date must have distinct labels. Scheduled pay date is not a bank payment confirmation.

Revenue-share acquisition must be shown once in referral statements. Teaching/retention pay is separate. Salary plus bonus can be shown as a combined total only after both are posted, for the same period and with no overlapping acquisition entries. If fixed/hourly salary has not been posted, say so explicitly; zero recorded payments are not proof that a person was paid.

## Month close and management accounts

Reconcile receipts/refunds, external accounts, expense documents, advances and payables; review payroll/referral expenses; run trial balance; resolve unexplained differences; close the period. A locked period requires a recorded authorised reopen or a correction in an open period. Never edit/delete posted journal lines. Reports must disclose date range, accounting basis, currency, generated time and filters.

## Interface and security

Admin: attendance register, people/tasks, payroll preview, daily close, receivables, payables and reports. Staff: My work first, own attendance/pay statement, task actions and role-specific tools. Secondary forms open by Create/Edit; errors preserve entered values and pending states prevent repeated clicks. Search/filter/page data at the database boundary.

Use verified identity, active staff/account checks, explicit permissions, RLS and controlled RPCs. Staff cannot set their own pay terms, approve attendance, change another person's task, or read other salaries. New definer RPCs schema-qualify relations, use an empty search path, revoke public/anonymous execution and check the caller. Keep credentials server-only. See [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) and [database functions](https://supabase.com/docs/guides/database/functions).

Paperless readiness requires actual end-to-end consent, receipts, payslips, expense evidence, task review, backup restore, notification delivery and external payment verification. Printable exports remain available as a fallback. Financial and employment statutory treatment requires locally confirmed rules before enabling tax/deduction automation.

## Delivery status

- Documentation: committed first.
- Attendance and own workforce workspace: implemented in migration 17, with own-only reads, corrections, overlap checks and retry protection.
- Tasks and completion accountability: implemented in migration 18, with own reports, administrative acceptance/return, cancellation, audit and paginated current/history lists.
- Accounting save recovery: implemented stable request IDs for unchanged retries, inline action forms, preserved invalid input and signed compensation adjustments. The all-time operating result is labelled explicitly.
- Fixed/hourly payroll: implemented in migration 19, with month/staff uniqueness, stale-preview rejection, immutable term/attendance snapshot, balanced expense/liability posting, cash payment, partial settlement, advance recovery and own-only printable payslips.
- Daily close: implemented in migration 20, with immutable count/statement evidence, denomination validation, variance investigation, fresh-count resolution, reopen and changed-ledger detection. Recording a handover recipient is not receiver acknowledgement.
- Monthly accounts and period controls: implemented in migration 21, with posted-date reports, CSV/print, month-end verification checks, immutable close/reopen snapshots and database write guards.
- Purchases, directory and evidence: implemented in migrations 22–24, with draft/receipt/payable settlement, supplier/category edit/inactivation and private immutable document evidence.
- Purchase returns and expense reductions: implemented in migration 25, with explicit supplier credits, refund receivables and actual refund collection.
- Staff personal-fund claims: implemented in migrations 26–27, with own documents, submission, finance verification/posting and actual reimbursements.
- Asset acquisition, custody, depreciation and disposal: implemented in migration 28; see the detailed convention/limitations below.
- Cash handover recipient acknowledgement: migration 30 adds own receipt/dispute evidence and an administrator register; sender counts and ledger balances stay intact.
- Further roadmap items (budgeting, consumable stock, recurring reminders, external bank imports, restore verification and statutory payroll/asset tax treatment) remain separate work.

## Start using this delivery

1. Apply migrations 17 and 18 without resetting the database.
2. Admin opens People → Staff attendance & terms, chooses the person and month, then records actual attendance and agreed pay terms. Present hours require completed start/end times; corrections require a reason.
3. On the same page choose Assign task, confirm responsibility, instructions and deadline.
4. Staff sign in to My work, inspect their own attendance and posted financial position, update progress/blocker and submit completed work. Teachers use My classes to take student attendance.
5. Admin selects the same person, accepts submitted completion or returns it with an explanation. Completed and cancelled tasks remain in history.
6. Accounting actions open inline; failed validation retains input. After an uncertain network outcome inspect the record; an unchanged retry keeps the same database request identity.

Local acceptance still needed: hosted Supabase Auth/RLS integration, real browser form behaviour, mobile/tablet layout, and complete accounting posting/settlement against your development database. Isolated SQL fixtures cover own-only reads, attendance hour arithmetic, permission denial, idempotent task creation and completion review. TypeScript checks cover the added routes and contracts. No live database has been changed.

## Monthly fixed/hourly payroll (migration 19)

Open Finance → Payroll & payslips → Prepare monthly payroll. Select staff and month; optional allowances and explained earning corrections appear separately. Fixed base is prorated by eligible calendar days from the later of the current agreement or join date. Hourly pay uses recorded PRESENT intervals less breaks. Missing records and task progress do not cause automatic deductions. Corrections reduce remuneration expense; tax, loan liability and advance recovery must not be entered as earning corrections.

Current-month preview is provisional. Post a completed month only after reviewing the frozen preview; changed attendance/terms require a fresh preview. One staff/month can be posted once. Posting creates salary expense and salary payable, not a cash payment. Previously posted evidence cannot be edited/deleted. If the currently configured agreement does not cover the month, stop and resolve historical terms rather than extrapolating a newer salary backwards.

Record actual cash/bank payment and an optional paid staff advance offset in one transaction. Partial payment leaves the remainder due. Paid advances must belong to this staff member and have enough remaining balance. Salary payment debits the payable, not salary expense again. The printable black/white payslip includes earnings, corrections, amount in words, actual payments, offsets and remaining balance; no branding header is printed over letterhead.

FIXED/HOURLY contracts are excluded from teaching-pool remuneration; HYBRID explicitly allows both agreed salary and teaching pool. Acquisition and retention remain separate rewards. Existing teaching-pool posting blocks conflicting fixed/hourly salary posting for the same period. A staff advance creation defect from a nonexistent staff.organization_id reference is corrected by checking branch scope. Payroll records and teaching/referral evidence retain separate detail views. My work combines their posted outstanding liabilities once and shows advances separately; do not add cash and offset totals indiscriminately.

Before production: verify real browser navigation/printing and hosted auth permissions. Isolated tests exercise stale preview rejection, once-only posting, balanced journal creation, partial cash plus advance recovery, unchanged retries and teacher privilege denial. Payroll correction/reversal and historic agreement restoration need a separate controlled feature; do not rewrite posted records.

## Daily cash and statement close (migration 20)

Finance → Daily cash & statement close → Count cash / match statement → choose account/date → review opening, debits, credits and expected closing → enter actual cash denomination counts or actual statement balance → explain differences and record reference, optional recipient and note → save. This creates evidence only; no balancing journal is invented. Ledger-derived debits/credits include financial transfers, not only student receipts or expenses.

A second verified count remains a new immutable record. Add investigation notes, resolve after a fresh matching count/statement, or reopen with a reason. Notes do not erase the latest resolved/reopened state. Backdated ledger postings invalidate both count evidence and a previously resolved balance; review again. Inactive account history stays readable. Original evidence is never overwritten/deleted.

This daily close does not freeze financial posting or create a period lock. A stated handover recipient is recorded by the closing actor. Migration 30 adds authenticated recipient acknowledgement; cashier/till ownership remains separate work. External bank/mobile statements are referenced manually; automatic transaction import/matching is not implemented.

Isolated tests exercise duplicate-count retries, unexplained variance protection, matching recount resolution, notes after resolution, late-posting stale detection, immutable ledger balance and denial of teacher access to academy-wide cash accounts. Hosted browser/mobile and actual bank statement workflows still require local acceptance.

## Monthly reports and period controls (migration 21)

Finance → Monthly accounts & period close → choose month → P&L / balance sheet / trial balance / cash movement. Reports include posted journals only, by accounting date. Opening balances carry all earlier postings; month movements cover that month; balance sheet includes accumulated unclosed result separately from posted equity. Cash movement groups posted source types and excludes net-zero internal transfers; it is not yet an operating/investing/financing cash-flow classification. CSV exports the full trial balance; print uses the selected report without an academy branding header.

Fixed/hourly payroll expense is now dated at the earned month's end, while its settlement remains on the actual payment date. If that earned month was closed, the entire attempted payroll posting rolls back. Revenue-share/referral reward recognition continues under the collection-driven existing engine, independently from fixed payroll.

Before CLOSE, verify all currently active cash/bank/mobile accounts against a matching, current-token month-end count/statement; review payroll, receipts/refunds, expense evidence and outstanding balances. Open receivables/payables/advances may carry legitimately; do not manufacture settlement just to close. The completed-month report must balance and all posted journals must balance. A refreshed preview is mandatory if evidence changes.

CLOSE stores an immutable snapshot and blocks new journal headers and additional journal lines in that month, including controlled financial RPCs and service-role writes through normal triggers. Posting takes a shared month lock; close takes the exclusive lock, so normal concurrent transactions cannot slip through the close boundary. An authorised REOPEN records actor/reason and restores posting, with history preserved. No silent unlock or deletion exists.

Remaining reporting work: cost-centre/programme contribution, budgets, classified cash flow, fiscal year-end transfer of accumulated result, payroll correction/reversal, historical contract restoration, external payment import, handover acknowledgement and assets. Isolated tests verify reporting arithmetic, rejected unverified close, one-time close, blocked backdated posting, authorised reopen and teacher access denial. Hosted concurrency and browser acceptance still need local verification.


## Purchase draft, receipt and supplier settlement — delivery 22

Finance → Purchases & supplier expenses starts a purchase register, filtered/searchable and paginated at 25 records. Create a draft, select supplier and expense category, enter item quantities/unit prices and optional expected delivery. Add a missing supplier within the draft without navigating away or clearing the draft. Saving is a planning record only: no cash, expense or payable is created. Edit unused drafts; cancel unused drafts rather than delete them. Concurrent stale revisions are rejected.

When the full goods/service delivery is verified, open Receive & post, compare quantities and total with the invoice, record the actual receipt/expense date and supplier invoice reference, and select paid now or payable later. Correct the draft before posting if the invoice differs. Paid-now receipt requires payment permission. Posting reuses the existing expense, balanced journal and supplier-payable engine; it does not create a competing ledger. The same normalized supplier invoice reference cannot be posted twice within this purchase register. Closed-period guards apply and a failed receipt rolls back the purchase, expense and journal together.

For an unpaid purchase, Pay supplier records actual partial/full cash or bank payment on this same register. Each payment needs a reference and cannot exceed the current payable balance. It clears liability, not a second expense. Request identities make unchanged retries safe; posted/cancelled purchase evidence is immutable and actor-attributed audit history is retained. Forms close on success, preserve values on errors and disable controls while saving.

Scope: operating expenses and consumables with a single full receipt. Durable assets must not be disguised as operating expenses. Partial goods receipts, purchase returns/credit notes, expense corrections, recurring expenses, staff reimbursements, supplier edit/inactivation, category maintenance, private scanned evidence and actual asset capitalization remain separate upcoming work. Current invoice references are recorded evidence references, not uploaded documents; this milestone alone does not establish paperless evidence retention. Existing direct-expense screens can still post outside this register; invoice uniqueness here does not claim to cover those historical/direct expenses.

## Supplier and category maintenance — delivery 23

Purchases → Suppliers & categories provides searched, paginated directories including inactive history. Create/edit a supplier's name, contact, address, service category and active status. Edit or deactivate expense categories and choose their expense account; permanent category codes cannot be changed. Historical expenses retain their posted ledger account and amounts. Active categories require an active expense account. Stale supplier/category changes are rejected, unchanged retries are idempotent, and all changes preserve actor-attributed audit evidence. No records are deleted.

## Private financial evidence — delivery 24

Purchase rows open Document evidence on demand. Attach PDF/JPEG/PNG up to 5 MB, add an evidence note and retain the original file. An authenticated Route Handler checks origin, expense permission, file size and file signature, calculates SHA-256, prepares a scoped upload ticket and uploads without overwriting. Completion verifies Storage metadata before making the attachment visible. Unchanged retries reuse the ticket and compare existing bytes if upload completion was uncertain. The checksum is calculated by the application upload route; privileged API callers can supply metadata and this is not a notarized third-party attestation.

`finance-evidence` is private. Object RLS permits scoped financial readers and ticketed inserts by the uploader; there is no client update/delete policy. Viewing requests recheck access and issue a 60-second download URL, which is a bearer capability until expiry. Corrected documents are additional evidence with an explanation, not replacements. Uploaded files and actor/time/note remain separate from ledger amounts. Purchase evidence is fetched in one batch per 25-row register page. No service role key is required.

Apply migration 24 on Supabase, whose managed `storage` schema already exists. Local SQL fixtures mock the Storage catalog, not the Storage HTTP service; actual uploads, bucket limits, signed downloads and revoked-access behavior must be checked against Supabase locally before release. Pending tickets/orphaned uploads remain retained for administrator investigation; no automated destructive cleanup is introduced. Evidence backup/restore requires Storage-object backups as well as database backups. See https://supabase.com/docs/guides/storage/security/access-control and https://supabase.com/docs/guides/storage/buckets/fundamentals.

## Purchase returns and expense correction — delivery 25

Posted purchase rows expose Returns & expense corrections. Confirm supplier return/credit note or an overstated-expense correction, enter its reference/date/amount and explanation. The original expense and journal stay intact. The unpaid balance is reduced first with a settlement explicitly classified CREDIT_NOTE, with no cash account. A paid portion becomes actual cash refund if received, otherwise Supplier Refund Receivable. Collect later refunds partially from the same purchase row. Over-reduction, over-refund, duplicate credit reference and unchanged retry duplication are blocked; closed-month posting guards apply. A correction that increases cost is a new documented expense, not a rewrite. Full and partial monetary credit notes are supported; physical inventory/partial delivery tracking is separate. Attach the credit note to the purchase's document evidence.

## Staff personal-fund reimbursements — delivery 26

Staff expense claims is available to authorized staff for their own claims and finance managers for the academy register. Save an actual personal-fund expense draft, attach private receipt evidence, declare that no academy advance/other claim funded it, and submit. Staff can edit/cancel only drafts; finance may return submitted claims to Draft with a correction note. Finance verifies and posts one staff reimbursement payable, then records actual partial/full payments. Staff cannot post their own liability or payment and cannot see another person's documents/claims. Managers may record on behalf of staff without a second admin review. Duplicate submitted/posted receipt references for the same staff are blocked. Posted claims are immutable, and settlement does not create another expense. Existing direct-expense history is not covered by claim-specific receipt uniqueness. Advance-funded expenses belong in advance reconciliation, not reimbursement claims.


## Assets, custody and straight-line depreciation — delivery 28

Finance → Assets & custody provides a searched, paginated register and on-demand forms. Create/edit/cancel an unused asset draft: identify the unit or group, serial/tag, location, supplier, fixed-asset account, cost, residual, useful life, acquisition/service date and first depreciation month. An invoice reference may include its supplier line identity for multiple assets. Verify and capitalize once, using paid-now cash or supplier payable. Actual supplier payments may be partial and remain payable even after disposal.

If equipment was already posted as an operating purchase, select that unadjusted purchase as the source. Supplier/cost/acquisition date are inherited; capitalization debits the fixed-asset account and credits the original expense account, reusing the original payment/payable. It never pays the supplier twice. A capitalized purchase cannot subsequently use operating-expense returns: use the asset lifecycle and an explained accounting correction. Posted financial terms are immutable. Name/tag corrections, active/inactive status and custody changes preserve evidence.

Assign/transfer to a staff custodian and location. Staff see only their currently assigned assets and acknowledge the specific current transfer; they cannot capitalize/depreciate/dispose. Administrators record maintenance/inspection notes; the underlying actual maintenance cost uses the expense workflow, not automatic duplicate cost posting. Asset documents remain finance-managed; staff custody views do not expose supplier document downloads. Recent history shows the latest 20 events; the full immutable trail stays in database/audit history.

Depreciation uses full configured calendar months and straight-line cumulative rounding: `(cost − residual) × elapsed_months / useful_life`, rounded to cents, less previous postings. This prevents tiny-value assets from getting stuck at a zero monthly rounding amount. Zero-amount scheduled entries retain schedule evidence without creating an empty journal. Post only the next completed month in order; inactive assets still depreciate. The first month is explicitly configured, normally the next full month after service; there is no daily proration or automated statutory tax rate. Capitalization must occur by the end of that first month and cannot introduce an unposted schedule into already closed months.

Before month close, all acquired assets due that month must have scheduled depreciation posted. Asset writes and period close share an ordered advisory-lock boundary; journal period guards and explicit zero-entry checks reject closed months. Disposal requires all completed depreciation months, records actual received proceeds (zero for a write-off), removes asset cost/accumulated depreciation and posts gain/loss against net book value. Asset history and unpaid supplier liabilities remain. Disposal is based on actual proceeds received; credit-sale debt collection, impairment/revaluation, tax books, assets-under-construction, supplier returns with unpaid capital liabilities and stock/quantity movements are separate extensions, not silently approximated.

Operational walkthrough: create draft → attach invoice → verify/capitalize → assign custodian → staff acknowledges → log inspections → post monthly depreciation → settle supplier balance as paid → dispose with evidence when necessary. The academy's existing P&L/balance sheet/cash movement automatically include the resulting journals.


## Cash handover recipient confirmation (migration 30)

Finance → Daily cash close records the sender count and designated staff recipient. Finance → Cash handover receipts is the recipient inbox and administrator register, paginated at 25 rows. The designated active staff account counts the cash and records Received (must match the sender amount) or Disputed with their actual amount and an explanation. The sender cannot confirm their own handover. A named recipient with no active linked account cannot confirm; provision the account before using authenticated handover.

Receipt evidence is immutable, own-only for staff and visible to reconciliation administrators. Stable request identities make unchanged retries safe. A dispute does not correct the close, resolve a cash variance or change the ledger; finance investigates and records a new count/handover when needed. The original dispute remains. Receipt acknowledges the historical cash custody event even if later backdated journals change reconciliation; ledger freshness remains on Daily close. Bank/mobile statement records do not represent physical cash receipt and do not appear here.

This completes receiver acknowledgement only. Till ownership, opening float, handover amount separate from whole counted cash, and formal dispute-resolution cases remain extensions. Current handover signifies the entire recorded actual cash count; do not use it for partial transfers. Hosted account/RLS and browser acceptance remain local checks.

The Bengali operator guide is available inside ERP at `/dashboard/help/finance`. Its canonical content is `modules/help/finance-guide.bn.json`; run `node scripts/sync-finance-guide.mjs` after editing it to synchronize the repository Markdown guide.


## Counter ownership and opening float (migration 31)

Finance → Cash counters & opening float registers a dedicated CASH account (existing unused account or inline account creation), an editable name and active/inactive state. The ledger account identity stays fixed. Admin/reconciliation permission opens one duty per counter and one per active linked cashier. Opening money is transferred from a funded academy cash/bank/mobile account to the dedicated counter account; an already open counter cannot be a funding source. Remaining cash carries to the next duty; a zero additional float requires no journal. Existing-account funding is not initial owner-capital recognition.

All controlled journal calls now acquire period/shared and sorted account locks through an internal wrapper before posting. Counter funding reads balances under those same locks, preserves journal uniqueness and cannot overdraw its source through this command. The renamed journal engine remains uncallable by authenticated/anonymous clients. Period guards remain effective. This does not introduce an academy-wide prohibition on overdrafts in older expense/payment commands.

The assigned active cashier receives the historical opening count or appends a dispute. A later matching recount is appended, never overwrites the dispute. The sole admin may be the cashier and receive their own opening count. This is different from sender-to-another-person handover acknowledgement. Closing requires a matching opening receipt and a fresh, non-handover, zero-variance current-day daily close recorded after opening; changed ledger evidence is rejected. Closing keeps cash in the counter and does not invent a return payment.

Roles continue to determine who can post financial operations. Registration creates a dedicated mapped payment method, enabled only after matching opening receipt and disabled on close. The journal wrapper rejects ordinary counter transactions with no open received duty, and non-reconciliation actors can post only to their assigned active cashier counter. Assignment does not grant payment permissions; existing operation permission gates remain. Operators must select the counter method/account. Register is 25/page; recent duty panels show the latest 10 scoped duties. All duty/receipt audit evidence remains. Inactivate only with no open duty. Cash return/top-up transfers, interrupted duty reassignment, automatic counter selection on every legacy posting screen and fully paginated long-term duty statements remain extensions. See the Bengali operator guide section 21a for examples.
