# Paperless finance and workforce management

Branch: `feature/finance_accounting_management`. Base: redesign_refactor, migration 16. This extends the existing ledger, billing and identity architecture; it does not introduce competing student, staff or accounting records.

## Review findings and ordered delivery plan

| Priority | Area | Existing capability | Gap / required outcome |
| --- | --- | --- | --- |
| P0 | Staff attendance | Approved academic session attendance | Staff daily presence, check-in/out, breaks, absence/leave, corrected evidence and monthly own hours are missing. Student attendance is not staff attendance. |
| P0 | Personal workspace | Teacher class lists and own referral statement | A common staff page for attendance, tasks and financial position; teacher shortcuts must lead directly to student attendance. |
| P0 | Compensation terms | Revenue-share teacher policy and approved runs | Fixed/hourly/hybrid terms, agreed pay day and a clearly labelled estimate. Never present an estimate as approved debt or promise payment. |
| P0 | Tasks and accountability | Academic workflow review | Staff assignments, due dates, progress, blocker explanation, completion submission and admin acceptance. Completion percentage is declared progress, not a salary deduction formula. |
| P0 | Payroll | Teacher approved runs, payables, settlements | Monthly fixed/hourly payroll with term/attendance snapshots; unpaid leave rules; itemised deductions; preview, admin posting, payslip, payment and advance offset. No second acquisition accrual. |
| P0 | Daily close | Balanced journals, actual collections and account reconciliation | Cash count, till/opening float, expected/actual/difference, cashier handover and unresolved variance register. |
| P0 | Month close | Ledger and accounting summary | Trial balance, period locking, authorised reopen, P&L, balance sheet and cash flow with date/account filters. Current all-time summary is not a monthly management report. |
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

Revenue-share acquisition must be shown once in referral statements. Teaching/retention pay is separate. Salary plus bonus can be shown as a combined total only after both are posted, for the same period and with no overlapping acquisition entries. Until fixed/hourly payroll is delivered, explicitly show that it has not been posted; do not display zero as proof of payment.

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
- Fixed/hourly payroll, daily close, reporting/period lock, assets and other gaps: separate subsequent features; do not label them implemented until their posting and recovery paths exist.

## Start using this delivery

1. Apply migrations 17 and 18 without resetting the database.
2. Admin opens People → Staff attendance & terms, chooses the person and month, then records actual attendance and agreed pay terms. Present hours require completed start/end times; corrections require a reason.
3. On the same page choose Assign task, confirm responsibility, instructions and deadline.
4. Staff sign in to My work, inspect their own attendance and posted financial position, update progress/blocker and submit completed work. Teachers use My classes to take student attendance.
5. Admin selects the same person, accepts submitted completion or returns it with an explanation. Completed and cancelled tasks remain in history.
6. Accounting actions open inline; failed validation retains input. After an uncertain network outcome inspect the record; an unchanged retry keeps the same database request identity.

Local acceptance still needed: hosted Supabase Auth/RLS integration, real browser form behaviour, mobile/tablet layout, and complete accounting posting/settlement against your development database. Isolated SQL fixtures cover own-only reads, attendance hour arithmetic, permission denial, idempotent task creation and completion review. TypeScript checks cover the added routes and contracts. No live database has been changed.
