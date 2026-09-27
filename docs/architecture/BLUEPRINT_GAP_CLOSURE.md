# Blueprint gap closure — working branch

Updated 2026-09-28. Branch: `feature/blueprint_gap_closure`, based on `feature/dashboard_teacher`. Read the Product Constitution & Master Blueprint v1.1 and the architecture guardrails before extending this branch. This document records implementation status; it does not change product policy.

## Delivered on this branch

| Area | Change | Verification |
| --- | --- | --- |
| Public catalogue | Homepage cards come only from ACTIVE, website-visible offerings. Empty and unavailable states are explicit. Cards show academic year, branch, class/group, linked subjects, published fee summary and application dates. | SQL suite 0027; production build |
| Application windows | Public listing derives OPEN, UPCOMING or CLOSED from the organization's local date. The submit RPC uses the same timezone for authoritative acceptance. | SQL suite 0027 covers open and upcoming states and rejects early submissions |
| Public choices | Active classes, programmes, subjects, schools, lead sources and guardian relationships are read from managed ERP records. The relationship directory has active-only anonymous read policy. Server validation checks selected source and offering. | SQL suite 0027 and typecheck |
| Applicant entry | No applicant sign-up; the old placeholder route goes to account-free interest. Auth copy describes staff access. | Route and typecheck |
| Admission consent | A draft admission case can be printed for paper consent. The A4 form reserves the top 50 mm for academy letterhead, identifies the case, student, guardian, programme, class and batch, displays the pinned fee plan, includes guardian declaration, optional student acknowledgement, signature/date fields, verifier fields and authorized signature/seal. Payment receipts remain separate. | Production build; manual signed-in print review remains |
| Public admission application | Published schedule, requirements and policy are managed on offering controls and shown on the card and account-free application. The admission form collects guardian address, academic background and explicit acknowledgements. Submission creates an immutable application record linked to the Prospect with the published terms and active fee plan version at submission. Staff see the record in CRM. | SQL suite 0027 validates snapshot and admission remains a Prospect; typecheck and build |
| Question bank review | Assigned teaching staff can author MCQ or short-answer drafts in the Question Bank. Submitted revisions require a different authorized reviewer. Rejection keeps the record and opens a new revision; approved questions keep their answer and rationale within the staff workspace. Each command has an audit event and replay identity. | Rollback SQL 0032 covers self review block, rejection/revision, approval, audit and retry; typecheck/build |
| Signed consent register | Admission staff can upload a PDF or photo of the signed paper form to a private bucket before acceptance. The case displays versioned receipts with guardian signing date, file hash and receiving staff. A permissioned route issues a short-lived download URL. No overwrites or ordinary staff deletes are granted. | SQL test 0033 validates receipt and audit in an isolated Storage metadata fixture; live bucket/RLS/upload/download must still be tested |
| Homework follow-up | A submitted class log with homework becomes the assignment for that session. Assigned teachers can check each eligible student as not submitted, needs work or complete; review notes and corrections are append-only. The latest check and full revision history appear on the class session. | SQL suite 0020 covers teacher scope, retries, stale revision rejection and preserved corrections |
| Assessment results | Teachers create dated batch/subject assessments, publish their terms, save one mark per eligible student and submit the roster. A different authorized reviewer approves or rejects the immutable revision. Only approved marks are shown as official; corrected rosters retain prior submissions. | SQL suite 0020 covers complete roster, teacher/reviewer separation and official result; typecheck/build |
| Public placement snapshot | Published cards and admission form show the count of active batches and currently open seats, derived from batch capacity and active enrollments. The copy says placement is confirmed after staff review; applying does not reserve a seat. | SQL suite 0027 covers batch capacity in the public payload |

### Staff print sequence

1. Verify the public Prospect and create an admission draft from the selected batch and fee plan.
2. Open **Admissions → Print Consent Form**, print on academy letterhead or save a PDF, and obtain the guardian's signature and date. The student may sign when able.
3. Record verification and retain the signed paper or PDF against the admission reference under the academy's document handling procedure. The ERP currently prints the form but does not store a signed scan or enforce its receipt before acceptance.
4. Continue **Ready → Accept → Bill → Activate** under the existing admission and finance policy. An admission form does not acknowledge payment; print a receipt only for posted money.

## Remaining blueprint gaps

These items need separate implementation and acceptance work on this branch. Do not describe them as shipped:

1. Public **Apply for Admission** collects the application declarations and terms snapshot. A signed document upload, applicant correction return channel and an individual requirements checklist remain.
2. Programme cards show configured admission requirements, policy, schedule and a current batch seat snapshot. Reviewed publishing/preview controls and a versioned public content contract remain; the seat snapshot does not reserve placement.
3. Signed form attachment and a versioned receipt exist. Test private bucket access and upload/download on linked Supabase, then enforce receipt before acceptance for new cases with a cutover that preserves older historical cases. A staff attestation and uploaded file cannot automatically prove a genuine signature.
4. Academic operations have plans, sessions, attendance review, submitted class logs, per-student homework follow-up, manually authored question bank review and assessment result approval. Coverage gaps/recovery, question-to-paper assembly, assisted question generation and student progress reports remain.
5. Finance covers discounts, cancellations, refunds and operator-run recurring invoices. General ledger/journals, advances/payables, expense reconciliation, teacher compensation calculations and settlements remain.
6. Staff leave/workload, asset/procurement, richer analytics, PWA/offline outbox, observability, browser accessibility/E2E and live Supabase/concurrency acceptance remain.

## Validation and deployment

- Apply migrations in order through `0036` to a **development** Supabase project; inspect `pnpm exec supabase migration list` before `pnpm exec supabase db push`.
- Run all rollback-only SQL scripts, especially `supabase/tests/0027_v2_public_admissions_workflow.sql`.
- Run `pnpm lint`, `pnpm typecheck`, `pnpm build`, then verify the homepage, interest and admission paths while signed in as authorized staff where required.
- Print a real draft with multiple fee components on A4 to check that the declarations, signatures and office-use area remain on the same page. Use the academy's actual letterhead, or print to blank paper and check the 50 mm reserved space.
