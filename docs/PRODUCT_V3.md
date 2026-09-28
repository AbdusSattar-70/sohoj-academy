# V3 product and operator workflow

Status: approved direction for design; implementation pending. Updated 2026-09-29.

## Product goal and current users

An authorized person can complete the normal task at the point where it starts, with clear next actions and without manually navigating to another register. The ERP must guide a new staff member through each decision, show why an action is blocked and preserve the evidence of what happened.

This phase supports two working personas:

- **Bootstrap/super admin:** configures the academy and performs admissions, academic setup, billing, payments, refunds, cancellations, recurring billing, accounting and staff work directly. No second-person approval is required for the admin's own operational actions. Posting and corrections still have confirmation, permissions, audit, idempotency and financial integrity rules.
- **Teacher:** sees assigned classes, records attendance, assessments/results, questions, class logs and other assigned academic work. Teacher submission is pending until the admin reviews and approves or rejects it. Only approved work becomes final/official. A rejected submission remains traceable and may be corrected and resubmitted.

Students and guardians do **not** need accounts. Public interest and admission forms remain account-free. Public homepage design, fonts and colors are outside this workflow redesign; published programme offerings supply their content.

## Navigation by task

Use one ordered route definition for sidebar labels, breadcrumb, active state, permission and group. Show only authorized entries; avoid an unrelated default route when a path is unknown. Display a useful empty state for a group with no available work.

| Order | Group | Entries and purpose |
| --- | --- | --- |
| 1 | Workspace | Overview and My Tasks; outstanding admission and teacher-review actions |
| 2 | Admissions & Students | Admissions, Students, Enquiries; direct intake and genuine CRM enquiries |
| 3 | Teaching & Academics | My Classes, Sessions & Attendance, Assessments, Question Bank, Batches |
| 4 | Finance | Student Accounts, Accounting & Settlements; daily billing, collection and settlement |
| 5 | People | Staff and teaching assignments |
| 6 | Academy Setup | Academic Directory, Programme Offerings, Fee Plans, Operating Rules, Access & Security |
| 7 | Governance | Admin Review Queue for teacher work, Audit Trail |

Help is always available from the shell/footer and the relevant task panel. A teacher sees only assigned work and their submission history; admin-only setup/finance links never appear for a teacher. Navigation is a way to start work, not an obligation to visit each area during one admission.

## Admission: one working page

The Admissions register has **New direct admission**, **Continue an enquiry**, **Admit an existing Student** and **Print blank form**. Each opens a focused entry form. On creation, the operator lands on `/dashboard/admissions/[caseId]`, which remains the working page until enrollment is complete.

| Step | Admin action in the case | Complete when |
| --- | --- | --- |
| 1. Identity | Direct intake enters student/guardian once. Enquiry conversion reviews and corrects inherited details first. Search for existing Student/guardian and possible duplicates. | Verified identity and guardian details saved with source and correction history. |
| 2. Placement | Select academic year/branch/class, an eligible active offering and an available batch. Show fee terms and why excluded choices are unavailable. | Placement and effective published Fee Plan are pinned on the case. |
| 3. Referral | Choose Organic, search existing referrer/staff, or add a verified person inline. Direct intake can do this in its first form. | Canonical referral choice, or Organic, is saved once. |
| 4. Consent | Print the application, collect the guardian signature and file the paper copy physically. Record signing date and file reference inline; student signature is optional when appropriate. | A physical consent receipt is recorded with receiving staff and date. |
| 5. Accept | Review explicit identity, placement, fee, referral and consent checks; confirm acceptance. | Permanent Student ID issued or existing ID retained, with an acceptance event. |
| 6. Bill and collect | Review and post initial bill. If money is received, record actual payment and show its receipt using the Finance service from this case. Approved discount or fee adjustment is also reachable here. | Invoice exists; receipt exists only for posted money. Outstanding dues remain visible. |
| 7. Enroll | Evaluate the configured activation condition and seat availability; resolve any precise blocker in place. | Enrollment is ACTIVE and batch occupancy reflects it. |

Steps are clickable actions with `available`, `blocked`, and `complete` states. Selecting a step opens its panel and places keyboard focus at its heading. Successful actions update the case and open the next available step without a full shell reload. Corrections have a dedicated **Edit details** action, with controlled history after acceptance. Uncommon tasks may open a separate route with a `returnTo` case reference; on completion they return to the case and its next task. Print may open separately and return naturally.

One page is an operator experience, not one database transaction. Acceptance, billing, money received and enrollment are separate recorded business facts. Full batches, stale Fee Plans and changed eligibility must be rejected again by the database, with an exact recovery message in the case.

## Enquiry versus direct admission

- A public or staff-recorded **enquiry** is a CRM Prospect with follow-up history. Converting it links the original Prospect to the admission and keeps its number and timeline.
- A family coming directly for admission creates an **application and case**, not a synthetic Prospect. It has its own intake source and optional referrer. It does not inflate CRM lead/conversion counts.
- An existing Student's new admission keeps their permanent Student ID; the new case/placement/fee terms are distinct.
- A possible duplicate is a review prompt, not an automatic merge. Siblings with the same guardian are not the same Student.

## Teacher work and admin review

The teacher opens **My Classes**, chooses the assigned session or assessment, saves a draft and submits a complete revision. The admin receives one review task with the submitted snapshot, class/batch, teacher and exceptions. Approve finalizes that revision; reject records the reason and returns it for correction. The teacher cannot mark their own submission approved, and later corrections retain the earlier final record.

The same simple `draft → submitted → approved/rejected → corrected submission` model applies where appropriate to attendance, marks/results, question papers and class logs. A question draft or unapproved mark is not published as an official result. The admin does not need a general maker-checker step for their own admissions or finance actions in this phase.

## Settings with low operator effort

Settings are small; frequently edited records live in their own searchable registers rather than one large control center.

| Place | Values | Change behavior |
| --- | --- | --- |
| Academy Settings | Academy identity, branches, contact and print/receipt details | Edit current details with audit. |
| Academic Directory | Academic years, classes/groups, subjects, schools, programme definitions, guardian relationships | Search/select; authorized inline creation; deactivate rather than erase referenced values. Multiple years can be active. |
| Programme Setup | Offerings, public content, batches and Fee Plans | Dedicated create/edit/preview/publish actions. Historical admissions keep the terms used. |
| Operating Rules | Capacity, admission activation, billing day/cycle and relevant compensation percentages | Simple current rule and effective change; transactions retain the governing values. |
| Access & Security | Bootstrap admin, teacher access and assignments, audit/history | Protected admin recovery; database permissions and scope. |

Default routine reasons should be selectable codes/checks. Require a written explanation for exceptions, correction, cancellation, refund or reversal. An audit note is never a substitute for consent, payment evidence, or the required teacher review.
