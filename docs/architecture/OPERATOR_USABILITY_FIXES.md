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
