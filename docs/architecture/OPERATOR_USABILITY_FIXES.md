# Operator usability fixes

Implement and publish each item as a separate commit on `feature/redesign_refactor`.

1. Audit actor attribution and trace filtering: show name, assigned role and staff/profile ID. Capture future identity snapshots; resolve historical missing role labels without modifying immutable rows. Correlation groups one workflow request and its related events.
2. Billing account search: display matching selectable results, preserve explicit account selection and show balances. Rename the operation to Search student accounts.
3. Student lifecycle: expose authorized withdrawal/closure with a recorded reason and preserved financial history.
4. Printing: return links, structured monochrome invoice and two-page admission/consent form inspired by the supplied acknowledgement slips. Never fabricate receipt, seal, signature or received payment.
5. CRM responsibility: Owner is the staff member responsible for following up, not the compensated referrer. Provide assignment controls.
6. Master data: show the register first, expand create/edit only on request, retain invalid inputs.
7. Programme offerings: inline editor instead of modal; programme name is the default display name; keep optional custom title. Close only on success, preserve failures.
8. Overview: actionable metrics and working-page navigation.
9. Business rules: edit current operating settings in a friendly form while retaining immutable historical snapshots internally.

Invitation deployment requires a server-only Supabase service-role key, an explicit site URL, allowed Auth callbacks and working invitation/recovery email templates. Secrets must never use a NEXT_PUBLIC prefix. No real email or live database changes are performed by this source implementation.

## Implemented delivery

All nine items above now have separate commits. Migrations 23–28 add audit identity snapshots and linked traces, account search identities, audited enrollment closure, CRM follow-up assignment, programme-name defaults, and editable operating-rule setup.

Audit history is never backfilled by altering events. Historical actor identities without snapshots are labelled as historical lookup. Future FINALIZE events share a correlation ID across acceptance, discount and billing. Actor profile UUID and staff UUID/number remain inspectable.

Owner now means **Follow-up staff**. It does not mean referrer. A verified conversion assigns its handling staff when responsibility was unassigned. Referrer compensation stays in the admission workflow.

Withdrawal/completion runs directly from Enrollment History on the student page. Closing stops future recurring billing, releases the seat and retains all existing dues; cancellation credits/refund payouts are separate financial decisions.

Offering/batch forms use inline editors. Titles default to the programme name in the database as well as the UI. Master-data create/edit is opened on demand. Failed save attempts retain values; successful saves close the working panel with a register-level message.

The monochrome form/invoice layout follows the supplied acknowledgement slip's header, numbered sections and bordered information rows. It does not assert a signature, seal or unreceived payment. Browser printing was unavailable in this execution environment; verify blank/populated admission forms at A4, 100% scale and browser headers/footers off. Long content must remain readable, and the admission form must occupy two pages.

Operating-rule editors expose current capacity, admission requirements and compensation settings. Missing supported rules can be created. Earlier snapshots stay internal for historical accounting/admission integrity; no separate administrator approval is introduced.
