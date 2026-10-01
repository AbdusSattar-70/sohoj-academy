# Admission, referral and document refinement

## Reported issues and implementation contract

| Area | Problem | Required behavior |
| --- | --- | --- |
| Requests | Case refresh can hang for five minutes | Shared request client, bounded network deadline, recoverable case error |
| Auth | Cookie session warning | Verify identity with getUser; never authorize from stored session user |
| Compensation | Short reason silently rejected | Field-specific reason validation and persistent input |
| Referral | No dedicated account or register | Admin register, verified account invitation, own-referrals portal enforced in database |
| Reward | External-only/manual first-month award | Unified staff/outsider reward on actual net tuition collection, policy-pinned evidence and refund correction |
| Finance | Discount labelled credit | Show discount/scholarship distinctly; preserve balanced contra-revenue accounting |
| Collection | No instant scholarship | Apply permitted invoice adjustment and payment atomically; never invent money received |
| Staff | Narrow incomplete editor, always-open create | Full inline editor; protected identity/access fields read-only; click-to-create |
| Forms | Inconsistent open states/loading | Explicit action panels, retain invalid input, pending feedback and prevent duplicate submission |
| Admission | Status lacks color | Draft/review amber/blue, active green, cancelled red, closed muted |
| Documents | Branding duplicates letterhead, weak layout | Monochrome typography, letterhead space, separate office area and amount in words |
| Family data | Missing student contact/address detail | Optional student mobile/email, present landmark, same-as-present permanent address |
| Preferences | Too much handwriting | Live offerings/subjects tick list, name boxes and selection controls; public choices stay unverified |

Referrers see only student identity/reference, referred programme, applied discount, collection and their reward/settlement. No guardian/private address or unrelated student data. Accounts are admin-verified; requesting or possessing a referrer role never grants access to another person's records. Staff can use their existing account.

Acquisition reward is based on net collected tuition of the first qualifying billing month, preserving the existing acquisition definition. Partial collections accrue proportionately. Refunds/late discounts reduce entitlement with compensating ledger entries, not silent historical rewrites. Teacher teaching/retention compensation remains separate; acquisition must not be counted again in teacher runs. Profit/loss comes from posted ledger revenue minus contra revenue and expenses including accrued referral reward; settlement is not a second expense.

Online intake and paper share contact/address/support fields. Paper does not collect passwords or unnecessary sensitive IDs. Public preferences are never verified placement. Letterhead space is configurable through print CSS; preview before physical printing.

Next work after this scope: teacher dashboard, question bank, routine/session calendar and academic operations; then assets and the remaining Finance review.
