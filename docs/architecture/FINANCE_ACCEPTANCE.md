# Finance acceptance guide

## Update locally

From the existing repository, with local changes committed or saved deliberately:

```bash
git switch feature/dashboard_initialization
git pull --ff-only origin feature/dashboard_initialization
pnpm install
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm dev
```

Apply all pending migrations through 0016 to the same development project used by `.env.local`. Do not reset the database. If the development server is already running, use its existing localhost URL; stop that terminal with Ctrl+C before starting another copy.

## People and permissions

Use the signed-in ADMIN to request actions. A different real authorized staff account must decide them; do not disable maker-checker for testing. For a second account, confirm its Auth user and linked Staff/Profile exist, then use Settings → user access / role permissions to assign an appropriate operational role. ADMIN bootstrap is not required for an operational reviewer.

Required permissions:

| Activity | Permissions |
| --- | --- |
| View Finance workspace | `finance.view` |
| Request discount, define term, preview/post recurring billing | `finance.billing.manage` |
| Approve/reject discount | `finance.discounts.approve` |
| Request cancellation | `admissions.create` |
| Approve/reject cancellation | `admissions.approve` |
| Collect money, request refund, post actual payout | `finance.payments.post` |
| Approve/reject refund | `finance.payments.reverse` |

## Complete one realistic development scenario

1. Configure an Offering, monthly Fee Plan (for example BDT 2,500 recurring tuition and BDT 100 one-time admission charge), and Batch. Create a Prospect and complete Admission → Ready → Accept → Initial Billing. Activate according to the pinned policy; pay first if that policy requires payment.
2. Open Finance → Billing & Adjustments → Student Accounts. Select the admission and collect the full BDT 2,600. Verify the permanent receipt and zero due.
3. Request a 20% tuition discount whose date range includes the initial invoice's billing period (the first day of its month). Under a different authorized account, open Approvals and approve. Expect original charges 2,600, credit 500, net charges 2,100, paid 2,600 and customer credit 500. The BDT 100 admission charge is unchanged.
4. Request a BDT 500 refund from the original receipt. Have the independent reviewer approve. Expect reserved refund 500, actual refunds zero, customer credit still 500.
5. After actually returning money in the development scenario, record the approved payout with method and reference. Expect actual refunds 500, reserved refund zero, customer credit zero. The original receipt still says 2,600 received. The payout has its own RFN number. The software records this fact; it does not transfer money through a bank.
6. In Recurring Billing choose the next month within the academic year and preview. Expect tuition 2,500 minus discount 500 = 2,000; the one-time charge is excluded. Post the reviewed invoices. Preview the same month again: that admission is no longer eligible. Collect a payment against this recurring invoice and verify its separate balance.
7. Request cancellation with **Credit all remaining charges** and approve independently. Expect the enrollment withdrawn, no future recurring charges, all net invoice charges credited and any net money retained shown as refundable customer credit. Refund each original payment only up to its remaining amount and available unreserved invoice credit.
8. On another case, cancel with **Keep outstanding charges payable**. The enrollment stops, but due remains and can still be collected. No cancellation credit is invented.
9. Print an invoice account statement and original receipt. Compare their current refund status, the Student register/dashboard active count, Approval Register and Audit Trail.

Also test TERM plans by creating a non-overlapping academic term inside the year, beginning after the initial invoice's issue date, then selecting that term in Recurring Billing. ONE_TIME plans never enter recurring runs.

## Important behavior

- Discount date ranges match billing-period dates. Initial/monthly periods use the first day of the month; named terms use their start date.
- Approved discounts cannot overlap. A fixed amount is capped at the tuition component total. It does not waive other fees.
- A cancellation request has no effect until approved. Pending refund requests do not reserve credit; approved refund authorizations do.
- Money cannot be refunded merely because it was paid: an approved discount or cancellation must first create sufficient credit.
- Customer credit is maintained per invoice. It is not automatically transferred to other invoices.
- Posting payments does not silently activate enrollment. Recheck admission activation if the case is pending payment.
- Billing runs require explicit review and posting; this release does not install cron or auto-debit customers.
- A cancelled accepted identity remains permanent. Re-enrolling an existing student is a separate workflow; do not create duplicate identities to bypass it.

## Automated verification

Run the SQL files in `supabase/tests` as database owner on a development database after applying all migrations. Fixtures run inside transactions and roll back. Tests 0013 and 0014 cover finance workflow invariants and abuse/error paths. Local isolated verification is not a substitute for this signed-in, linked-environment acceptance sequence.
