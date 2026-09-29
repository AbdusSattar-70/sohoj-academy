# Operator friction and V3 redesign response

Updated 2026-09-29. Branch: `feature/refactor`.

This document records live operator pain points reported while running the ERP, maps them to product decisions, and states the V3 response. It complements `PRODUCT_V3.md`, `ARCHITECTURE_V3.md` and `STATUS_V3.md`.

Google Drive is not connected in this environment; product source used here is the repository V3 docs plus the Product Constitution PDF held in the project artifacts.

## Phase boundary (confirmed)

| Role | What they do in this phase | Approval model |
| --- | --- | --- |
| Super / bootstrap admin | Admissions, CRM, finance, directories, publishing, teacher review | Direct action with audit. No maker-checker on admin’s own work. |
| Teacher | Attendance, assessments, class logs, questions | Draft → submit → admin review/approve or reject. Teacher cannot self-approve. |
| Applicant / guardian | Account-free interest or application only | No applicant portal. |

Security is not relaxed: RLS, permissions, audited mutations, server-side validation and immutable financial/academic history remain required. What is removed is **unnecessary human approval on admin-owned operations**.

## Reported issues (operator)

### A. Navigation and “work on one page”

1. Completing admission forces jumps to other pages; after a side task the operator must manually find the case again.
2. Step headers (Verify → referral → consent → accept → bill → activate) look like a checklist but are not actionable; the real work is buried in open forms and collapsible sections.
3. “Correct student or guardian details” appears as an always-open/awkward control instead of a deliberate first verification step for enquiry conversion.
4. New direct admissions should not reuse the “correct from Prospect” path; permanent student/guardian edit belongs after Student creation.

### B. Wrong identity model for online / staff intake

5. Creating a fresh online/staff admission that **always** links or fabricates a Prospect is wrong for direct intake: it creates false CRM conversion work and double entry.
6. Prospect/Enquiry conversion must remain an explicit path: existing enquiry → verified → admission case, preserving the enquiry link without inventing a second identity.

### C. Forms that do not work

7. “New applicant with staff assistance / Enter details online / Already in Prospects / Start from a Prospect” cards/links do not reliably open a dedicated form.
8. “Create a draft from an existing Prospect” often shows **no Programme offering or Batch options** after selecting a Prospect (class/offering filter mismatch or empty workspace data) — operator is blocked.
9. Referrer field forces free text instead of select-from-directory with create-on-the-fly.
10. Accept / Ready reasons force long free text instead of selectable standard reasons plus optional note for exceptions.

### D. Data entry style

11. Across the app, too much typing; preferred pattern is **search/select**, and if missing **create on the fly** for next use (schools, referrers, subjects, etc.).
12. Settings and “version control” surfaces feel heavy and hard to follow for day-to-day operation.

### E. System maturity

13. Workflow feels fragmented and untrustworthy for smooth academy operation — not a single coherent workbench.

## V3 product responses

| Issue | Response |
| --- | --- |
| A1–A2 | **Admission Workbench** at `/dashboard/admissions/[admissionId]`: one case owns the flow. Steps are clickable; only the current actionable step expands a work panel. Side actions use deep links with `returnTo` and always land back on the same case. |
| A3–A4 | Identity correction is step 1 only for **enquiry conversion** drafts. Direct staff intake and public application capture identity on create. Post-acceptance edits use Student register, not the Prospect correction form. |
| B5–B6 | Origins: `DIRECT_STAFF`, `PUBLIC_APPLICATION`, `PROSPECT_CONVERSION`, `EXISTING_STUDENT`. Direct intake must not create a synthetic CRM Enquiry. |
| C7 | Admissions home uses explicit primary actions that open dedicated routes/forms (`#staff-intake`, `#from-enquiry`, blank print form). |
| C8 | Batch list is scoped to the **selected offering**; offering list is scoped to active offerings eligible for the enquiry class (or all active if class unknown). Empty states explain *why* (no fee plan, no batch, wrong class). |
| C9–C10 | Referrer: select Organic / existing person / staff / **register new**. Action reasons: selectable codes for routine steps; free text only when “Other” or exception. |
| D11 | Shared SmartSelect + “create on the fly” pattern for directory entities. |
| D12 | Settings split into small places: Academy, Academic Directory, Programme Setup, Operating Rules, Access — not one mega control center. Prefer current value + audit over multi-step version theatres for admin-phase settings. |
| E13 | Ordered sidebar, focused case routes, unified teacher Admin Review Queue. |

## Recommended settings (short)

Keep settings few and obvious:

1. **Academy Settings** — name, branches, contact, print letterhead defaults.
2. **Academic Directory** — years, classes/groups, subjects, schools, programmes, relationships (select + create on the fly).
3. **Programme Setup** — offerings, public content, batches, fee plans (publish is explicit).
4. **Operating Rules** — capacity, activation policy, billing cycle defaults (current rule; transactions pin values).
5. **Access & Security** — bootstrap admin, teacher assignments, audit.

No separate “centralized settings universe” is required in this phase.

## Database cutover note

V3 schema baseline lives under `supabase/baseline_v3/` as ordered `0001_v3_…` files (equivalent to a clean `01_…` series for a disposable DB). Active app path may still read V2 tables until cutover. Operator may reset the linked **development** database and apply the baseline in order; production is out of scope until acceptance.

## Implementation order (this branch)

1. Document friction (this file) and keep STATUS/PRODUCT accurate.
2. Admission workbench: clickable steps, one active panel, predefined reasons.
3. Fix intake entry points and offering/batch empty-state messaging.
4. Directory create-on-the-fly gaps (referrer already partial).
5. Apply baseline_v3 to disposable DB; SQL/RLS suite; regenerate types.
6. Teacher review queue acceptance; finance V3 reconnection.
7. Browser acceptance for admin admission path end-to-end.

## Non-goals this phase

- Applicant accounts / applicant portal
- Maker-checker on admin admissions and finance
- Silent merge of people who share a phone number
- Full general ledger polish beyond what PRODUCT_V3 already scopes
