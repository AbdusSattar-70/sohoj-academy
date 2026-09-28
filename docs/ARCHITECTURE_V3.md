# V3 architecture and integrity rules

Status: design contract; no V3 schema has been applied. Updated 2026-09-29.

## Modular monolith and ownership

Next.js provides server-rendered workspaces and focused client forms. Supabase Auth identifies staff. PostgreSQL enforces RLS, scoped permissions, constraints and transactional domain commands. Keep each domain's business facts in one place; the admission case may call Finance or Academic commands without writing their tables directly.

| Domain | Canonical facts and responsibility |
| --- | --- |
| Platform | Staff Auth/profile, bootstrap admin, permissions/scope, audit events, idempotency, settings catalog |
| CRM | Genuine enquiries, public applications, interests and follow-ups; optional origin link to admission |
| Students & Admissions | Applicant/guardian details, admission case, evidence, placement, Student identity and enrollment |
| Catalogue & Academics | Years, classes, groups, subjects, programmes, offerings, batches, teaching sessions and approved results |
| Finance | Fee terms, assigned charges, invoices, discount/credit, payment/allocation/receipt, refunds, recurring billing, GL, advances/payables and compensation |
| Publishing | Curated public content from ACTIVE published offerings and application windows |

At the boundary: `UI → shared validation → authorized server command → database transaction → audit/event → focused read model → local UI update`. Domain commands use typed inputs/results and return actionable field errors, blocking conditions, case revision and correlation ID. Avoid clients cast to untyped Supabase for routine mutations and avoid text replacement of stored SQL function definitions.

## Admission source and person data

An admission case has one explicit origin: `DIRECT_STAFF`, `PROSPECT_CONVERSION`, `PUBLIC_APPLICATION`, or `EXISTING_STUDENT`. Its `origin_prospect_id` is nullable and points to a real Prospect only for conversion. The case connects applicant identity, guardian/contact relationship, selected offering/batch, pinned Fee Plan, referral choice, consent receipt and eventual Student ID. New direct applicants are not inserted into the CRM lead table.

Use canonical IDs for school, relationship, referrer, offering and batch where applicable, plus deliberate display snapshots for historical forms. A shared accessible search/select supports **Add new** only for a permitted master type; it checks normalized duplicates before creation. Existing identity matching requires human confirmation and keeps a trace of the choice.

## Transaction and history guarantees

- Keep Programme, Offering, Batch and Fee Plan distinct. A published offering is eligible only with effective fee terms; website visibility and application intake are separate controls.
- Pinned commercial terms, admission decision and effective rule values remain reproducible even when current settings change. Expose a simple **Change effective terms** action; do not make staff operate a technical version register for everyday work.
- Admission, acceptance, invoice, payment, receipt and enrollment are separate facts. An unpaid invoice is a receivable. A receipt exists only after actual posted payment.
- Posted financial facts are corrected by controlled credit, refund, reversal or adjustment with linked original; never by silent overwrite. Journals balance and reconcile to their source facts. No admin approval queue is needed to execute a properly authorized operation.
- Database transactions lock the needed case, batch or balance; idempotency keys prevent double submission and retry duplication. Permanent IDs and official numbers are never reused.
- Teacher submissions are reviewed by the admin before finalization. Original submissions and corrections remain visible; a teacher may edit their draft but cannot self-approve.
- Sensitive actions record actor, time, scope, reason code/free text when required, before/after facts, effective terms and correlation ID. RLS and server checks enforce authority; hiding a button is never the security boundary.

## Shared operator interaction

- The sidebar has explicit ordered groups and one route definition for permissions, label, active state and breadcrumb. Unknown routes do not inherit another module's title.
- Long work has a dedicated detail route with an actionable step list. Each action opens inline, preserves case context, exposes precise blockers and returns to the next task. A cross-domain task preserves `returnTo` and verifies it is an allowed internal route.
- Forms have persistent labels, appropriate live validation, search/select for repeated business values, localized pending state and accessible success/errors. Unsaved data is protected when leaving a draft. Responsive keyboard and touch workflows are acceptance requirements.
- Public forms remain account-free and bilingual; ERP remains English in this phase. Public homepage visual design stays as it is while content comes from published ERP records.

## Security for the current two personas

Bootstrap admin is protected from accidental loss of recovery access. Admin operations execute with permission and scope checks, confirmation for consequential posting, audit and database invariants; no independent approver is required. Teacher access is limited to assigned teaching data and pending submissions. Admin review is the only approval workflow required in this phase. Never ship service-role secrets to the browser. Test RLS with both roles, including direct RPC attempts and unauthorized IDs.
