# Simple academy finance — authoritative scope

Branch: feature/sohoj_final. Updated: 2026-10-08.

The owner has replaced the advanced-finance roadmap with a small-academy workflow. Student fees/dues, actual collections/receipts/refunds, staff salary and earned teaching/referral rewards, operating expenses, other operating income and a monthly profit/loss view remain. Assets, depreciation, procurement/stock, supplier ledgers, budgets, bank statement matching, cash counters/handovers, fiscal/year/month closing, manual journals and chart-of-accounts management are not operator workflows in this product.

## Operator journey

1. Configure standard fees under Academy Setup. Admission creates the student's invoice and enrollment.
2. Open Student fees & dues to collect money, apply a discount/scholarship and print the actual receipt. A due invoice is not collected money.
3. Open Income & expenses when the academy earns other income or incurs rent, utilities, printing, materials or another operating cost. Select a category and a cash/bank/mobile source. Paid later records a due; later payment settles it without counting another expense.
4. Prepare staff salary from agreed terms and verified work; record actual payments and print payslips. Teaching-share/referral rewards retain their existing controlled calculation and settlement paths.
5. Select a month in Finance overview. Net earned income minus incurred operating costs gives the operating result; actual cash received/paid is shown separately. Student dues and unpaid academy costs remain visible.

Owner money/opening funds are financing, not revenue or profit. Loans/transfers, asset disposals and depreciation are excluded from the operating result. This is an operating-management view, not a statutory/tax/full-accounting report. It is accurate only when all relevant invoices, reductions, salary/reward obligations and running costs have been recorded. Costs are not counted again when their dues are paid. Manual asset/depreciation calculations remain outside the app, as requested.

## Architecture and security

The existing posting engine is an internal implementation detail. Removing it would break linked student invoices, receipts, discounts/refunds, salary and referral settlement integrity. Existing migrations and evidence are retained; this task does not authorize a live reset or historical deletion. Advanced UI routes redirect to the simple workspace; their forms and actions are absent from navigation/help.

New simple reads/mutations use verified ERP accounts and existing database permission boundaries. Mutations require stable retry identities, numeric validation, scoped active payment/category records and immutable audit evidence. No client service key, direct table writes or generic manual journals are introduced. Read lists are paginated and summary totals are independent of the displayed page.

Current report definitions: revenue/fee reductions/expenses are dated by the posted earned/incurred date. Salary belongs to its earned month; actual salary payments belong to their payment date. Capital and internal transfers never inflate operating income. Prior closed periods are not silently unlocked by this change.

## User guide

The in-app Bengali guide at /dashboard/help/finance is authoritative for daily financial operation. Previous documents describe implementation history; their advanced-feature roadmaps are superseded by this scope.

## Verification and rollout

All 46 migrations were loaded in an isolated PostgreSQL-compatible PGlite database. Twenty-three targeted finance checks passed, plus admission/billing, referral collection, salary/payroll settlement and the new `34_simple_academy_finance.sql` fixtures. TypeScript, lint on the changed implementation and a production Next.js build passed. The build used placeholder public configuration; these are not hosted-database or browser acceptance checks.

Pull this branch and run `pnpm exec supabase db push` to apply `46_simple_academy_finance.sql`; then `pnpm build` and `pnpm dev`. No reset, migration-history repair or manual ledger setup is required for a database already aligned with this branch. Do not push before reconciling an existing migration-history mismatch.

Operating entries are immutable. Student/refund/payroll corrections keep their existing dedicated paths; the simple cost/other-income workspace currently does not expose an amount-reversal editor. Do not conceal a mistake by posting an unrelated opposite income or duplicate expense.
