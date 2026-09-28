# Admissions operator workflow

This guide defines the staff experience for starting and processing student applications. Applicant and guardian accounts are not required. A person can enquire or apply without signing in; authorized staff verify the details and manage the record in the ERP.

## Start an application

From `/dashboard/admissions`, choose one of three entry paths:

1. **Enter a new applicant online.** Staff record the student and guardian while speaking with them. The system creates the Prospect and its admission draft in one audited transaction. The form requires a selected active Programme Offering, an available batch, guardian contact details, address, and permission to contact. It does not accept admission, post a charge, collect money, or activate enrollment.
2. **Create a draft from an existing Prospect.** Use this for a public interest/admission form or an enquiry already reviewed in CRM. Confirm the intended Programme Offering and batch. The batch list is scoped to the selected offering. If the Prospect has no class, the active offering supplies the class; when a Prospect already has an offering recorded, that offering is the eligible choice.
3. **Print a blank application.** `/dashboard/admissions/application-form` prints an A4 form for the family to complete by hand. Staff must enter the verified details online afterward and attach the signed form to that admission case. A paper form does not itself create a Prospect or reserve a seat.

Duplicate open Prospects with the same student name and guardian mobile are surfaced as an error with a direction to continue the existing CRM record. Staff must not create a second identity to avoid a review step.

## Process an admission case

| Stage | Staff action | Result |
| --- | --- | --- |
| Draft | Check identity, guardian contact, chosen offering, batch availability and inherited Fee Plan. Print the case-specific consent form or link the signed paper form. | A reviewable, unconfirmed case. |
| Consent | Confirm the guardian signed; upload the scan/photo/PDF and record the signing date. The private file is attached to the case. | Acceptance remains unavailable until consent evidence is recorded. |
| Ready | Mark the verified draft ready for acceptance. Resolve any identity or fee-plan issue first. | The case enters the acceptance review stage. |
| Accepted | Accept the case after required consent; the permanent Student identity is created and policy versions are pinned. | Student identity exists; no payment or active enrollment is implied. |
| Initial billing | Post the initial charges from the pinned Fee Plan. | A receivable/invoice exists; this is not a receipt. |
| Payment | Record only money actually received using the finance payment workflow. | An allocation and numbered receipt are recorded. |
| Enrollment | Evaluate the current policy and batch capacity. Collect a required payment first if the policy demands it. | An active enrollment and student count are created only when the checks pass. |

Cancelled cases retain their history. Correct a draft through its audited correction action; do not delete a case or reuse its identity.

## Consent document handling

- Case-specific print route: `/dashboard/admissions/[admissionId]/print`.
- Blank paper form route: `/dashboard/admissions/application-form`.
- After upload, the page refreshes to show the recorded version. Opened documents are served through an authenticated ERP route that creates a short-lived signed storage URL.
- Uploading a consent file does not move the case to Ready or Accepted. It only records evidence; an authorized staff member performs each workflow transition.
- If the database cannot record an uploaded file, the action removes the temporary private upload where possible and reports whether an administrator must inspect it.

## Permissions and audit

- `admissions.view`: read the case register and open case documents.
- `admissions.create`: create staff-assisted intake, create/process admission drafts and receive consent evidence.
- `finance.payments.post`: record actual payment received.
- Every intake or case transition includes the acting staff profile, request identity and operational reason. Admission/finance authorization and eligibility are rechecked inside the database RPC; client form filters are only guidance.

## Acceptance checks

- [ ] Start from a Prospect with class and offering recorded; confirm only valid batches for that offering are shown.
- [ ] Start from a Prospect with no class but a recorded offering; confirm its batches show and the class is assigned from the offering.
- [ ] Start from a Prospect with neither class nor offering; choose one explicitly and confirm it is recorded before draft creation.
- [ ] Enter a fresh applicant with staff assistance; confirm exactly one Prospect and one admission draft are created and the applicant details print on the case form.
- [ ] Submit the same request twice; confirm it returns the original case. Try a different request for a matching open name/mobile; confirm it directs staff to CRM.
- [ ] Print the blank paper form and verify A4 print layout, handwriting space, declaration and guardian/student signatures.
- [ ] Try Ready → Accept without signed evidence; confirm the UI explains that consent is required and the database rejects direct bypass.
- [ ] Receive a signed form; confirm the case refreshes in place and the private document opens only after ERP permission checks.
- [ ] Complete Accept → Initial billing → actual payment → enrollment activation and verify each state remains distinct.
