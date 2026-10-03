# Finance delivery status — 2026-10-03

This is the current status; older roadmap paragraphs describe the state when written. Implemented does not mean hosted/browser acceptance has been performed.

## Delivered this continuation, one feature per commit

| Migration | Feature | Operator page |
|---|---|---|
| 33 | Historical salary agreements and signed earning corrections | Payroll |
| 34 | Recurring expense schedules and duplicate-safe purchase drafts | `/dashboard/finance/recurring` |
| 35 | Receivable aging, commitments, guardian statements and reminder drafts | `/dashboard/finance/receivables` |
| 36 | Actual owner contributions and contributed-capital returns | `/dashboard/finance/capital` |
| 37 | Cost centres, monthly budgets and evidence-based programme contribution | `/dashboard/finance/planning` |
| 38 | Verified bank CSV import, exact matching and release history | `/dashboard/finance/bank` |
| 39 | Classified cash flow, export and print | `/dashboard/finance/cash-flow` |
| 40 | Twelve-month year closing, retained-result transfer and reversal | `/dashboard/finance/year-end` |
| 41 | Current supplier accounts, settlement and separate advances/refunds | `/dashboard/finance/suppliers` |
| 42 | Physical consumable receipt/use/count register and reorder attention | `/dashboard/finance/stock` |
| 43 | Orders, partial received quantities, exact supplier invoice matching and inline settlement | `/dashboard/finance/procurement` |
| 44 | On-demand counter duty and opening-receipt history with dates and pagination | `/dashboard/finance/counters` |

## Explicitly excluded

Digital admission consent is excluded by the owner decision of 2026-10-03. Keep guardian/student paper signatures and physical file-reference recording. Do not add digital consent, uploads or a digital-consent prerequisite as a future delivery gap. Private finance-document evidence is a separate existing capability. Digital finance with paper admission consent is the intended operating model.

## Remaining internal extensions

These are not delivered and must not be advertised as complete: payroll full cancellation/overpayment recovery and configured statutory liabilities; interrupted cashier reassignment, evidenced shortage resolution and transfer reversal; broader legacy-register pagination and failure recovery visibility; advanced asset impairment/revaluation, credit-sale proceeds and construction accounting.

## External dependencies and release acceptance

Actual payment gateway confirmation and SMS/email delivery require selected providers, server credentials, delivery consent and verified callbacks. Statutory payroll rates/filings require confirmed applicable legal rules and accountant sign-off; no rates are invented. A demonstrated database plus private Storage restore requires a designated disposable target and actual hosted backups; a runbook alone is not restore evidence. Hosted concurrency, Auth/RLS/Storage and browser acceptance remain necessary before production use.

The Bengali ERP guide is `/dashboard/help/finance`; its checked-in source is `modules/help/finance-guide.bn.json`. Apply forward migrations to an existing database; do not reset it for this delivery.
