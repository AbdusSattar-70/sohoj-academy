# Public admissions workflow (account-free)

Authoritative product decisions for the account-free public path, continued on `feature/blueprint_gap_closure`.
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
| Operational status (`DRAFT` / `ACTIVE` / `RETIRED`) | Teaching and internal operations |
| Website visibility | Whether the offering may appear on public programme cards |
| Accepting applications | Whether public forms may select this offering for new interest/admission |

An offering may stay **ACTIVE** for existing students after applications close. Closing applications must not deactivate enrolled students.

Only **ACTIVE** offerings that are explicitly website-visible appear publicly. Closed offerings can show “Applications closed”; they cannot accept new applications.

## Public forms (no sign-in)

### Register Interest

Short form. Offering optional (general interest allowed).

### Apply for Admission

Fuller form. **Open offering required.**

Both forms:

- Create a **Prospect** (not a Student)
- Return a reference number
- Capture consent to contact
- Keep unlisted school names as prospect snapshot text for staff review; public submission does not create a school record
- Never auto-merge on shared phone numbers

If a prior interest exists, staff **link** the admission application after verification — shared phone numbers never auto-merge children.

## Verification is not admission

Verification confirms identity, eligibility, and placement readiness. Admission still follows existing acceptance, fee assignment, billing, and activation rules.

## Manage CRM (master data)

Staff with `system.master_data.manage` edit shared directories used by public forms and offerings:

| Entity | Notes |
| --- | --- |
| Academic years | Active calendar years |
| Classes / groups | Eligibility structure |
| Subjects / programmes | Curriculum catalogue |
| Schools | School names, locations, active status; approve pending “not listed” names |
| Lead sources / relationships | CRM capture vocabulary |

Every change requires permission, reason, and audit trail.
Fee plans stay under Finance; offerings link to published plans.

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
7. Acceptance tests and SQL verification suites (`docs/architecture/PUBLIC_ADMISSIONS_ACCEPTANCE.md`, `supabase/tests/0027_v2_public_admissions_workflow.sql`)

## Related code anchors

- Public interest: `app/interest`, `app/actions/public-interest.ts`, `submit_public_interest`
- Offerings / fees: `modules/offerings`, migrations `0008+`
- CRM prospects: `modules/crm`, `app/dashboard/crm/prospects`
- Master tables + RLS: migration `0001_v2_platform.sql` (`system.master_data.manage`)
