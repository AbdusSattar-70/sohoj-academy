# Admissions operator workflow

This guide defines the staff experience for starting and processing student applications. Applicant and guardian accounts are not required. A person can enquire or apply without signing in; authorized staff verify the details and manage the record in the ERP.

## Start an application

From `/dashboard/admissions`, choose one of three entry paths:

1. **Enter a new applicant online.** Staff record the student and guardian while speaking with them. The system creates the Prospect and its admission draft in one audited transaction. The form requires a selected active Programme Offering, an available batch, guardian contact details, address, and permission to contact. It does not accept admission, post a charge, collect money, or activate enrollment.
2. **Create a draft from an existing Prospect.** Use this for a public interest/admission form or an enquiry already reviewed in CRM. Confirm the intended Programme Offering and batch. The batch list is scoped to the selected offering. If the Prospect has no class, the active offering supplies the class; when a Prospect already has an offering recorded, that offering is the eligible choice.
3. **Print a blank application.** `/dashboard/admissions/application-form` prints an A4 form for the family to complete by hand. Staff must enter the verified details online afterward, print the case consent form, and keep the signed paper with the student file. A paper form does not itself create a Prospect or reserve a seat.

Duplicate open Prospects with the same student name and guardian mobile are surfaced as an error with a direction to continue the existing CRM record. Staff must not create a second identity to avoid a review step.

## Process an admission case

| Stage | Staff action | Result |
| --- | --- | --- |
| Draft | Verify student/guardian details, programme, batch and fee summary. Mark the draft ready only after those details are checked. | Verification is complete; the next step is to record the admission source. |
| Ready · referral | Choose the verified referrer or Organic. This step is shown only after verification. | Referral source is stored in the admission record. |
| Ready · paper consent | Print the case form, have the guardian sign it, file the original physically, then record the signing date and optional paper-file location. No scan or upload is needed. This step is shown after the referral source is recorded. | Acceptance remains unavailable until staff record the paper receipt. |
| Accepted | Accept the case after required consent; the permanent Student identity is created and policy versions are pinned. | Student identity exists; no payment or active enrollment is implied. |
| Initial billing | Post the initial charges from the pinned Fee Plan. | A receivable/invoice exists; this is not a receipt. |
| Payment | Record only money actually received using the finance payment workflow. | An allocation and numbered receipt are recorded. |
| Enrollment | Evaluate the current policy and batch capacity. Collect a required payment first if the policy demands it. | An active enrollment and student count are created only when the checks pass. |

Cancelled cases retain their history. Correct a draft through its audited correction action; do not delete a case or reuse its identity.

## Paper consent handling

- Case-specific print route: `/dashboard/admissions/[admissionId]/print`.
- Blank paper form route: `/dashboard/admissions/application-form`.
- Keep the signed original in the physical student file. The ERP records who received it, the guardian signing date, whether the student also signed, and an optional paper-file location.
- Recording the paper receipt does not move the case to Ready or Accepted. An authorized staff member performs each workflow transition.
- Older cases may show a legacy digital consent receipt; those files remain available through the authenticated document route.
- If an older accepted case has no consent receipt in the ERP, staff can record the already-filed paper consent afterward. Initial billing and enrollment remain blocked until the admission source and consent records are complete.

## Permissions and audit

- `admissions.view`: read the case register and view cases and any legacy digital consent documents.
- `admissions.create`: create staff-assisted intake, create/process admission drafts and record paper consent receipts.
- `finance.payments.post`: record actual payment received.
- Every intake or case transition includes the acting staff profile, request identity and operational reason. Admission/finance authorization and eligibility are rechecked inside the database RPC; client form filters are only guidance.

## Acceptance checks

- [ ] Start from a Prospect with class and offering recorded; confirm only valid batches for that offering are shown.
- [ ] Start from a Prospect with no class but a recorded offering; confirm its batches show and the class is assigned from the offering.
- [ ] Start from a Prospect with neither class nor offering; choose one explicitly and confirm it is recorded before draft creation.
- [ ] Enter a fresh applicant with staff assistance; confirm exactly one Prospect and one admission draft are created and the applicant details print on the case form.
- [ ] Submit the same request twice; confirm it returns the original case. Try a different request for a matching open name/mobile; confirm it directs staff to CRM.
- [ ] Print the blank paper form and verify A4 print layout, handwriting space, declaration and guardian/student signatures.
- [ ] Try Ready → Accept without a referral source or signed consent receipt; confirm the interface explains the missing step and the database rejects direct bypass.
- [ ] Confirm Draft shows only verification. After marking Ready, confirm referral appears; after saving referral, confirm paper consent appears; after recording consent, confirm Accept appears.
- [ ] Record receipt of the physically filed signed form; confirm the case refreshes in place without uploading a file.
- [ ] Complete Accept → Initial billing → actual payment → enrollment activation and verify each state remains distinct.


## Operator screen sequence

Work through the case from top to bottom. Verify student/guardian details and placement first. Record the referral choice and confirm receipt of the signed paper consent. Mark the draft ready for acceptance; in the Ready stage the Accept action appears after those checks are recorded. Acceptance issues the Student ID. Initial billing follows, while payments and adjustments remain in Finance. Enrollment is activated after policy and capacity checks pass.

The case view keeps corrections collapsed until needed and hides billing detail behind the application/fee record disclosure. A successful referral save updates the case view in place without a browser reload.
