# Public admissions acceptance

Manual and automated checks for the account-free public admissions path on branch family `feature/workflow_redefine` / `feature/public-admissions-acceptance`.

Complements [Public admissions workflow](PUBLIC_ADMISSIONS_WORKFLOW.md) and [Student lifecycle acceptance](STUDENT_LIFECYCLE_ACCEPTANCE.md).

## Product path under test

```text
Published programme card
  → Register Interest / Apply for Admission (no account)
  → Prospect + reference number
  → CRM verification queue (school review, follow-up)
  → Admission draft from verified data (existing admission rules)
```

## Automated SQL suite

Run as database owner on a development database after migrations through 0030:

```bash
# example: psql or Supabase SQL editor
\i supabase/tests/0027_v2_public_admissions_workflow.sql
```

`0027_v2_public_admissions_workflow.sql` is rollback-only. It verifies:

1. Offerings are hidden from `list_public_programme_offerings` until website-visible.
2. Website-visible offerings can list while applications remain closed.
3. General interest (no offering) creates a `NEW` prospect with `submission_intent = interest`.
4. Unlisted school names stay as `school_name_snapshot` with null `school_id` (staff review).
5. Admission intent without an offering is rejected.
6. Offering-linked submits are rejected when applications are closed or outside the open window.
7. Admission with an open offering stores `submission_intent` and `interested_offering_id` and writes audit.

Earlier suites (`0003` mock interest, `0010` admission end-to-end) remain required for the full CRM → admission chain.

## Signed-in browser sequence

Use a disposable development org seed (SOHOJ). Do not use production data.

### A. Master data & offering curation

1. Sign in as staff with `system.master_data.manage` and `academics.manage`.
2. Open **CRM → Manage CRM**. Create or confirm class, programme, subject, school entries.
3. Open **Academics → Offerings**. Create an offering (or use an existing ACTIVE one).
4. Open public controls on the offering:
   - Set bilingual showcase title/description/eyebrow.
   - Turn **Website visible** on.
   - Leave **Accepting applications** off first.
5. Confirm the homepage shows only published cards with year, branch, class, subjects, fees and application window; when none are published it shows an empty state.
6. Confirm **Apply** is constrained (applications closed messaging or form rejection).
7. Turn **Accepting applications** on with an open date window that includes today.
8. Confirm Interest and Apply entry points pre-select the offering.

### B. Public forms

1. Open `/interest` without query params → general interest allowed.
2. Open `/interest?offering=<id>&intent=admission` → offering pre-selected; admission requires open offering.
3. Submit with an unlisted school name → prospect appears in CRM with **School needs review**.
4. Submit admission against the open offering → prospect shows intent **admission** and offering label.

### C. Verification queue

1. Open **CRM → Prospects**. Default filter is the verification queue.
2. Filter by intent and **School needs review**.
3. Open a prospect detail: confirm intent, offering, school review flag, original note.
4. Record a follow-up (CONTACTED / COUNSELLING) with next date when required.
5. Confirm Action Center still surfaces open prospect follow-ups for users with `crm.prospects.view`.

### D. Hand-off to admission (existing rules)

1. From a verified prospect, create an admission draft using existing admissions permissions.
2. Do not expect automatic Student conversion from the public form.
3. Complete Ready → Accept → Bill → Activate only under existing finance/admission acceptance docs.

## Non-goals (do not regress)

- Applicant accounts or applicant portal
- Homepage visual redesign
- Silent merge of prospects/students that share a mobile number
- Public exposure of DRAFT / RETIRED offerings

## Exit criteria

- `pnpm run build` passes on the feature branch
- Migrations through `0030` applied on the linked development database
- SQL suite `0027` returns `PASS` and rolls back
- Browser sequence A–C completed once on the linked environment
