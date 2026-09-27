# Public admissions workflow (account-free)

Authoritative product decisions for branch `feature/workflow_redefine`.
Complements the Product Constitution, [ERP implementation guardrails](ERP_IMPLEMENTATION_GUARDRAILS.md), and [Student lifecycle acceptance](STUDENT_LIFECYCLE_ACCEPTANCE.md).

## Product decision

**No applicant accounts.** Students, guardians, teachers, or any helper submit interest or admission forms without signing in. Sign-in remains for authorized ERP staff only.

This removes applicant-portal complexity while preserving a professional, trustworthy acquisition path:

```text
Browse published offerings (homepage / programme cards)
  → Register Interest (short)  OR  Apply for Admission (fuller)
  → Reference number + printable acknowledgement (not yet admitted)
  → CRM + Action Center verification queue
  → Staff follow-up / corrections / counselling / trial
  → Admission draft from verified data (no retyping)
  → Ready → Accept → Bill → Activate (existing finance rules)
```

## Experiences

| Surface | Audience | Purpose |
| --- | --- | --- |
| Public website | Anyone | Discover programmes; submit interest or admission without an account |
| Staff ERP | Authorized staff | Manage CRM master data, verify submissions, admit, bill, teach |

Shared records; each person sees only what they need. Applicants never see internal CRM notes, other applicants, or staff controls.

## Programme cards (homepage design preserved)

Existing card layout, fonts, and colours stay intact. Content and actions come from ERP.

Each **published** card shows:

| Field | Source |
| --- | --- |
| Public title / description (EN + BN) | Programme offering showcase fields |
| Eyebrow / class label | Showcase eyebrow or eligible class |
| Academic year, branch | Offering context |
| Eligible class / group | Offering eligibility |
| Included subjects | Subjects linked to the offering |
| Schedule / admission window messaging | Offering admission dates + visibility flags |
| Published fee summary | Active Fee Plan (display-safe amounts only) |
| Availability | Derived: Applications open / Applications closed |

### Card actions

- **Register Interest** — opens short interest form with this offering pre-selected.
- **Apply for Admission** — opens fuller admission form with this offering pre-selected.

General navigation entry points may also open the forms without a pre-selected offering (visitor chooses).

### Three independent controls on an offering

| Control | Meaning |
| --- | --- |
| Operational status | `DRAFT` / `ACTIVE` / `RETIRED` — whether the offering runs operationally (Fee Plan published → ACTIVE) |
| Website visibility | Whether the offering appears on public programme cards |
| Accepting applications | Whether new interest/admission submissions may select this offering |

An ACTIVE offering may continue teaching after applications close. Closing applications must not deactivate enrolled students.

Only offerings that are **ACTIVE + website-visible** appear publicly. Closed offerings may show “Applications closed” and must reject new applications.

## Forms (no account)

### Register Interest (lightweight)

- Student name, current class, primary mobile, programme/subject interests
- Optional guardian name, schedule preference, notes, consent
- Pre-selected offering when entered from a card
- Creates / updates a **Prospect** only — no Student ID, no invoice

### Apply for Admission (fuller)

- Purpose: formal application for a specific offering
- Student identity and academic context
- Guardian / submitter relationship (who is submitting; relationship to student)
- Selected offering + relevant subjects
- Supporting information required for that offering
- Consent and review step
- Submission reference + printable acknowledgement stating admission is **not** confirmed

Selecting “Teacher” as submitter **never** grants staff access. Teacher-assisted applications do not create staff privileges or automatic access to later financial/academic records.

### Shared rules

- Spam protection, rate limits, duplicate-submit prevention
- Reference number alone must not expose private student data
- “School not listed” captures a free-text snapshot for **staff review** before adding to the shared school directory (do not auto-insert unlisted schools into master data on public submit)
- If a prior interest exists, staff **link** the admission application after verification — shared phone numbers never auto-merge children

## Status models (kept separate)

| Record | Example states |
| --- | --- |
| Application / Interest submission | Draft (if saved), Submitted, Under review, Corrections requested, Verified, Withdrawn |
| CRM engagement | New, Contacted, Counselling, Trial, Follow-up, Lost, Converted |
| Admission | Draft, Ready, Accepted, Declined, Cancelled |
| Enrollment | Pending activation, Active, Completed, Cancelled |
| Finance | Charges, payments, approved discounts, adjustments, refunds |

Applicant-facing messages may simplify these without exposing internal CRM terminology.

Verification is **not** admission approval. Verification confirms identity, eligibility, and placement readiness. Admission still follows existing acceptance, fee assignment, billing, and activation rules.

## Admin: Manage CRM (master data + public content)

Dedicated ERP entry: **CRM → Manage CRM** (shared master records — not a CRM-only copy).

| Section | Editable information |
| --- | --- |
| Academic years | Names, dates, availability |
| Classes & groups | Class names, ordering, groups (e.g. Science) |
| Subjects | Names, EN/BN labels, availability |
| Schools | School names, locations, active status; approve pending “not listed” names |
| Programmes | Reusable programme definitions and descriptions |
| Programme offerings | Year, branch, eligibility, subject selection, admission windows |
| Website showcase | Public titles, descriptions, icons, display order, visibility, preview |
| Registration settings | Lead sources, relationship options, schedule preferences, form requirements |

### Editing rules

1. Create, edit, reorder, **deactivate** — do not hard-delete operational history.
2. Deactivated choices disappear from new applications; remain visible on historical records.
3. Public content can be prepared and previewed before publishing.
4. Fee / finalized admission terms keep prior versions (historical pinning).
5. Every change requires permission, reason, and audit trail.
6. Fee plans stay under Finance; offerings link to published plans.

### Admin setup sequence before opening applications

1. Academic settings (years, classes/groups, subjects, programmes)
2. Programme offerings (context + subjects + showcase copy)
3. Admission setup (dates, requirements, policy)
4. Fee plans (publish)
5. Batches (capacity)
6. Publishing (website visibility + accepting applications)

## Verification queue

Submitted applications and interests appear in **Action Center** and **CRM → Prospects**, connected to the same records.

Staff may:

- Request corrections (applicant-facing message; original submission preserved; revisions recorded)
- Verify information
- Assign counselling or trial
- Continue to admission
- Waitlist or decline with a recorded reason

Possible duplicates are **reviewed**, never silently merged.

## Permissions (indicative)

| Activity | Permission |
| --- | --- |
| Public submit interest / application | anon (secured RPCs) |
| View / manage prospects | `crm.prospects.view` / manage |
| Manage master data | `system.master_data.manage` |
| Manage offerings / showcase | `academics.manage` |
| Publish Fee Plan | `finance.billing.manage` |
| Create admission | `admissions.create` |

## Non-goals

- Applicant sign-up / applicant portal
- Homepage visual redesign
- Automatic Prospect → Student conversion without admission workflow
- Exposing DRAFT / RETIRED offerings on public surfaces
- Auto-merging students that share a guardian phone number

## Implementation checkpoints

1. **Blueprint** (this document) + README pointer
2. **Manage CRM** master-data editor (years, classes/groups, subjects, schools, programmes) with audit
3. **Offering public controls** (showcase fields, website visibility, accepting applications, subjects on offering)
4. **Homepage cards** driven by published offerings; Interest / Apply entry points; design unchanged
5. **Public forms** constrained to open offerings; school-not-listed pending review
6. **Verification queue** polish in Action Center / CRM
7. Acceptance tests and SQL verification suites

## Related code anchors

- Public interest: `app/interest`, `app/actions/public-interest.ts`, `submit_public_interest`
- Offerings / fees: `modules/offerings`, migrations `0008+`
- CRM prospects: `modules/crm`, `app/dashboard/crm/prospects`
- Master tables + RLS: migration `0001_v2_platform.sql` (`system.master_data.manage`)
