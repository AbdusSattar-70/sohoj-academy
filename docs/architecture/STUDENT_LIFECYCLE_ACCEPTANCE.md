# Student lifecycle acceptance

## Update

```bash
git fetch origin
git switch feature/student-lifecycle
git pull --ff-only origin feature/student-lifecycle
pnpm install
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm dev
```

If the branch does not exist locally, use `git switch --track origin/feature/student-lifecycle`. Apply all pending migrations through 0019 to the same development Supabase project used by `.env.local`. Use the existing dev server if already running; do not start a second copy. No reset is required.

## Roles

| Activity | Permissions |
| --- | --- |
| Open student profile | `students.view` |
| View financial amounts | `finance.view` in addition to student access |
| Start existing-student enrollment | `admissions.create` and `students.view` |
| Request transfer or duplicate resolution | `students.manage` and `students.view` |
| Decide transfer | `admissions.approve` and `students.view` |
| Decide duplicate resolution | `students.merge.approve` and `students.view` |

Requesters cannot decide their own requests. ADMIN has the new merge-approval permission; use Settings to grant an appropriate operational reviewer role. A second authorized profile is required for approval testing.

## Profile and readmission

1. Complete a normal admission. Open Students and click its permanent Student ID.
2. Verify primary guardian, admission, enrollment and financial history. A student-view-only user must not see financial amounts.
3. Expand **Enroll This Existing Student**. Select an eligible batch. An existing active enrollment/open case in the same academic year must be rejected.
4. Test another academic year, or first complete a controlled cancellation of the earlier case. Create the new draft and follow its Admissions link.
5. Review inherited standard fees and one-time charges, then Ready → Accept → Bill → Activate (or pay/recheck if required by the activation policy).
6. Verify the same Student ID and guardian remain, the new invoice is separate, previous debt remains, and enrollment history contains both cases. Previous discounts do not silently transfer to the new admission.

The current schema permits one active enrollment per student/year. Simultaneous multiple programmes need a separate policy/schema extension.

## Transfer

1. Create a second batch in the same offering with available capacity.
2. On the active admission in the profile, request transfer with a reason. No seat is reserved by the request.
3. Under another authorized account, open the student profile's **Lifecycle Requests & Decisions** section, or follow the Approval Register link.
4. Approve. Verify the old enrollment remains WITHDRAWN, the new one is ACTIVE, occupancy moves correctly and the transfer date is recorded.
5. Verify the same admission, pinned Fee Plan and invoices remain. No extra initial invoice is created. Subsequent recurring billing continues once per period.
6. A full destination, cross-offering destination, self-approval or superseded enrollment must be rejected. A stale request may still be rejected by its reviewer.

Cross-offering transfers can change commercial terms and are intentionally outside this workflow.

## Duplicate review

1. Use disposable development fixtures or genuine verified duplicate records. Do not duplicate a real student simply to test.
2. Open the duplicate's profile. Candidate matches use name or guardian mobile; siblings may match and must not be merged.
3. Source must have no open case or active enrollment. Resolve those through approved cancellation first, with the appropriate financial settlement.
4. Choose the Student ID to keep, explicitly confirm the same person, and record the evidence in the reason.
5. An independent authorized reviewer examines both profile links and approves/rejects. If either identity changed since submission, submit a fresh review.
6. After approval the source is ARCHIVED with a link to the retained identity. The retained profile shows both identities' history and balances. Original guardian links, invoices/payments, prospect links and numbers remain unchanged; new work uses the retained ID.

This is an irreversible identity link through the current UI, not a deletion/reassignment of posted history. A canonical identity already containing linked duplicates cannot itself be merged into another identity. Invoice balances remain separate; linking identities does not automatically offset customer credit against other invoices.

## Verification boundary

`supabase/tests/0017_v2_student_lifecycle.sql` runs rollback-only development fixtures as database owner. Isolated tests passed with all earlier migration/test scripts. Real signed-in browser, linked Supabase and concurrent-connection acceptance must still be performed before operational rollout.
