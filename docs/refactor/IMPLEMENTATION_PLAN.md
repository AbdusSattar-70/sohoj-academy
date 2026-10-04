# Implementation, cleanup ও acceptance

Docs first; each completed feature gets one coherent commit। No runtime rewrite delivered by this docs commit। User local acceptance after implementation; never advertise hosted RLS/email/payment/printing tested without execution।

## Delivery sequence
| Phase | Work | Completion gate |
| --- | --- | --- |
| 1 | Inventory keep/reuse/remove; public design capture; new schema/platform/essential seeds | fresh install + own admin, typed contracts |
| 2 | Person identities/relationships, divisions, academic catalogue, inline select/create | same person multiple roles, no duplicate forced identity |
| 3 | Public application adapter + enquiry queue | existing visual design intact, mismatched preferences accepted unverified |
| 4 | One-page direct/prospect/existing-person admission | draft/resume, consent/review, atomic invoice/enrollment, actual receipt |
| 5 | Student collection/discount/refund, running expenses, remuneration/referral | division profit/cash/dues correct; no duplicate earning/payment |
| 6 | Academic operations + consolidated staff/teacher workspace | own-scope, admin review, school/coaching/training requirements |
| 7 | Navigation/search/pagination/print/activity/help, cleanup | single canonical forms, local acceptance checklist |

## Reuse/remove map
Reuse public visual components/assets and suitable shared UI; reuse concepts of RLS/audit/idempotency, not blindly old SQL।
Replace old person duplication, giant workspaces/untyped contracts, inconsistent forms, raw version queues。
Remove advanced asset/depreciation, procurement/stock/counter/budget/year-close screens and their unused database/functions/types/tests/navigation/docs from this new implementation. Keep only dependencies genuinely needed by new billing/expense/remuneration model, not old migration chain.
No legacy compatibility/backfill branch in new baseline; old Git branch supplies history/reference। Old runtime files removed phase-by-phase only once new owning workflow exists, avoid broken imports/routes।
Rewrite inherited setup/reset docs and README for new migration names; legacy financial roadmaps no authority। Schema source/migration composition rule checked so they cannot drift।
No “completed” checklist item until code/database/UI implemented. App and seed examples use one schema contract।

## Acceptance examples
- School minor, coaching student and adult job trainee admissions; no forced adult guardian/class।
- One person school+coaching with separate enrollment invoices; same parent phone for siblings allowed।
- Missing school/referrer inline create with selected result; bad input doesn't erase draft।
- Wrong public academic selection accepted; original snapshot visible, verified placement separately chosen।
- Draft/resume; correct identity renews applicable consent; past step revisit no unauthorized finalization।
- Confirm unpaid/partial/paid under policy; invoice failure rolls back confirmation; collection timeout recover request outcome。
- Duplicate retry/request/paper receipt rejected safely; concurrent last-seat admission serialized।
- Discount/scholarship explicit; recurring invoice due basis; refund adjusts net tuition reward and overpaid award recovery।
- Shared expenses allocation no double count; earned income vs cash vs due clearly distinct।
- Teacher only own assigned records, own salary/referrals; cannot self-approve academic submission; public no ERP access।
- Registers paginate; failed query not empty list; scoped summaries accurate beyond API row limits।
- A4 monochrome letterhead-safe forms/receipts amount-in-words; Back stays working context।
- Browser visual parity public pages; language clean; loading/error/cancel/retry behaviour consistent।

## First implementation direction
Start phase 1: dependency map and fresh schema foundation, then phase 2 directory/person model. Do not add more advanced finance extensions. No live database reset during documentation authoring. Later user-run reset guide must explicitly state target, Auth/Storage handling and bootstrap steps.
