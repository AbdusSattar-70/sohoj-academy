# Build-forward review — finance accounting branch

Reviewed 2026-09-28 against Product Constitution & Master Blueprint v1.1, repository architecture guardrails, and `feature/finance_accounting_gap` at `1f0e6e5`. This is an implementation review, not a production acceptance certificate.

## Current evidence

- The accounting route and production build compile in an isolated workspace assembled from this branch's accounting files and the preceding repository source. Migration chain through `0043` applies in isolated PGlite/PostgreSQL compatibility verification; the narrow `0042` ledger invariant script passes.
- The complete SQL suite stops at `0010_v2_admission_end_to_end.sql`: it accepts an admission without the signed consent required by migration `0040`. Existing fixtures need a signed consent receipt or a deliberate pre-cutover case. CI currently runs lint, typecheck and build, but no SQL migration/test gate.
- No linked Supabase Storage/RLS, concurrency, browser workflow or real statement reconciliation acceptance was performed during this review.

## Findings, ordered by release impact

| Priority | Finding and evidence | Required closure |
| --- | --- | --- |
| P0 | `0042_v2_finance_accounting_gap.sql` creates `teacher_compensation_lines` without `admission_id`, then `REQUEST_COMPENSATION` inserts into that column. The request will fail when run; the ledger-only test never exercises it. | Add the canonical admission link with a migration, or remove the column from insert after proving source identity and drill-down. Exercise a complete two-actor compensation run. |
| P0 | `DECIDE_COMPENSATION` builds a `jsonb_agg` expression containing `sum(l.amount)` at the same aggregate level. It also uses `teacher_id=teacher_id` inside a loop whose variable has the same name as the column. The approval branch is untested and cannot be trusted to create the correct teacher payables. | Aggregate teacher totals in a separate grouped relation; use unambiguous aliases/variables; assert exact payable amounts and balanced journals for two teachers. |
| P0 | The finance command has a `SETTLE_PAYABLE` branch but its permission dispatcher does not assign that action any permission, so every call is rejected before reaching settlement. | Authorize the action with the appropriate payment/finance permission and cover partial/full settlement, duplicate retry, overpayment and cross-payee cases. |
| P0 | `teacher_compensation_preview` adds acquisition, retention and approved adjustment lines to every requested period rather than only the relevant earned period. `teacher_compensation_lines` uniqueness is scoped to a run; `teacher_compensation_events.event_key` exists but the request path does not claim it. Re-running a period can pay the same bonus again. | Base earnings on immutable, period-specific paid events; enforce unique event claims across runs and preserve policy/evidence snapshots. Test late payment, repeat run and rejected run replacement. |
| P0 | `finance_net_collected_tuition` filters invoice `billing_period` and counts all payments allocated to those invoices, regardless of the payment posting date. A later collection can retroactively change an earlier compensation calculation. | Define collection-period attribution from actual posted payment/refund dates, allocate tuition after approved credits, pin the calculation at run submission, and test partial payments and subsequent refunds. |
| P1 | `SETTLE_ADVANCE` can debit an arbitrary expense account using a submitted `expense_account_id`, or debit vendor/teacher payable without selecting and reducing a specific payable. It does not require an independent settlement approval. | Link each settlement to an approved expense/payable/compensation fact and matching beneficiary, lock and decrement that obligation, and require controlled review before finalization. |
| P1 | The `/dashboard/finance/accounting` route shows summary cards and lists only. There are no forms/server actions for vendor setup, advance request/approval/payment/settlement, expense approval/posting, payable settlement, compensation calculation/review or reconciliation. Displaying a status does not make the workflow usable. | Build task-oriented, permission-aware interfaces with preview, field validation, reason, local pending state, audit reference and visible next actions. Keep the existing billing/discount/refund UI. |
| P1 | The complete SQL suite is red after consent gate `0040`, and `0042` tests only a synthetic balanced journal, a rejected unbalanced journal and permission seeds. No end-to-end accounting facts, maker-checker or RLS tests cover the new modules. | Update old admission fixtures, add rollback-only integration scenarios and include a migrated database suite in CI. Validate on linked development Supabase before production use. |
| P2 | `BLUEPRINT_GAP_CLOSURE.md` still says accounting/advances/compensation remain and instructs migration through `0041`; its print sequence says consent is not gated, although `0040` gates new cases. | Refresh the handoff/status docs with implemented versus verified state and migration sequence through `0043`. |

## Recommended implementation order

1. **Repair release gates:** update admission test fixtures for consent and run the entire SQL suite; add migration/test execution to CI. Preserve pre-cutover historical cases.
2. **Correct the finance core:** fix compensation schema/approval SQL and payable settlement dispatch. Add transactional tests with two staff actors and exact journal/payable reconciliation assertions.
3. **Make earnings period-safe:** define net collected tuition by actual payment/refund dates, unique bonus events, retention eligibility and policy pinning; test repeated/late/corrected transactions.
4. **Close advances and expenses:** settle advances only against approved source obligations for the same beneficiary, prevent duplicate/cross-document settlement, and reconcile cash movement to statement evidence.
5. **Build the staff interface:** guided workflows for setup, request, review, post, settle and match; surface balance and drill-down source records. Test keyboard/mobile use.
6. **Acceptance:** run linked Supabase migration/RLS/storage tests, concurrent posting/retry tests, real print/receipt checks and a browser end-to-end journey. Update handoff docs only after each gate passes.

## Scope boundary

The existing discount, cancellation, refund and recurring billing workflows remain the source of their business facts. New journals must reconcile to those posted facts, not create a parallel fee balance. Other blueprint work remains: academic coverage/recovery, question paper assembly/assisted generation, progress reports, staff leave/workload, assets/procurement, richer analytics, PWA/offline outbox and observability.
