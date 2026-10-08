# Development handoff — feature/sohoj_final

## Start here

Current work is on `feature/sohoj_final`. Read [workspace ownership and end-to-end workflow](WORKSPACE_REDESIGN_WORKFLOW_BN.md), [delivery evidence](WORKSPACE_REDESIGN_DELIVERY.md), [operational usability standard](OPERATIONAL_USABILITY_STANDARD.md), and [local acceptance](REDESIGN_LOCAL_ACCEPTANCE.md).

The repository contains migrations 01–55. Use the actual files as the install inventory; older documentation counts are not current. This usability delivery adds no migration and requires no database reset or migration-history repair. Existing installed databases must apply genuinely unapplied SQL, never mark SQL applied merely to hide a mismatch.

## Staff attendance refinement

[Single-day staff attendance](STAFF_ATTENDANCE_WORKFLOW.md) is now entered directly at `/dashboard/attendance`, with today/preselected past date, person, status and clock times. Admin can record themselves or another active staff member. Existing attendance loads for correction; monthly selection is report-only. No migration/reset is required.

## Page ownership

- `/dashboard/crm/manage`: public programme showcase, visibility and application controls. No class/year/subject master forms.
- `/dashboard/academics/settings`: academic and reusable registration lists. Academic links, setup readiness and post-save revalidation use this destination.
- `/dashboard/crm/prospects`: unverified public applications and follow-up. Public preferences are not final placement.
- `/dashboard/academics/planning`: selected room, availability, closure, qualification or teaching-plan section; bounded records.
- `/dashboard/academics/routine`: recurring subject timetable and date-range generation. `/dashboard/academics/operations` and session details record dated class work.
- `/dashboard/admissions`: intake/register; `/dashboard/admissions/[id]`: one case with prerequisite steps, referral, physical consent, fees, finalization, collection and receipt links.
- Header search replaces sidebar search. Record searches use verified server context, permissions and authenticated RLS. Teacher search is constrained to assigned sessions; referrer-only users do not receive the global person directory.

Website management currently manages offering showcase content, not a general homepage/about/FAQ CMS. Keep the existing public appearance, fonts and colours. Do not label academic lists as website content.

## Domain rules

Direct staff intake does not fabricate a Prospect. Student, guardian, staff and referral identities retain their domain contracts; do not rebuild duplicate person models. Physical paper consent needs no scan upload. Failed input is preserved. A saved invoice is not payment; record actual collection and print the resulting receipt. Approved evidence and issued financial history cannot be silently rewritten.

Teaching qualifications, effective availability, room capacity, closures and overlapping bookings are independent validations. Planned time, staff presence, student attendance and approved actual teaching hours are separate. Single-session changes preserve the weekly plan and original history.

Teachers initiate Google Docs questions from scheduled teaching scope; administrators review and attach academy final document links. Google Docs copying and sharing are explicit human actions, not silently automated. Progress reports use approved evidence. Read [questions/progress](QUESTIONS_AND_PROGRESS_WORKFLOW.md) and [academic routine](ACADEMIC_ROUTINE_WORKFLOW.md).

Simple fees, staff/referrer earnings, running income/expenses and operating profit are the operator-facing finance scope. Read [simple finance](SIMPLE_ACADEMY_FINANCE.md) and [Bangla finance guide](FINANCE_OPERATOR_GUIDE_BN.md). Do not revive advanced accounting or assets navigation.

## Security and interactions

Server permissions, controlled RPCs and RLS are authoritative. Requested signup roles do not grant access. Invitations use server-only credentials; never send a service key to a client. Read [account configuration](ACCOUNT_SETUP_CONFIGURATION.md).

Common fields use visible native associated labels, bilingual guidance and optional help. Forms show pending/error/success, preserve invalid values and guard dirty/busy navigation. Explicit close and admission-step actions must honor the same guard. Canonical help is `/dashboard/help`; its former Prospect/scan instructions have been replaced.

## Evidence and limits

Changed source passed TypeScript/lint; source-integrity, navigation, guide-render, bounded-search, slotted-button and safe-return checks passed. Production build passed with placeholder configuration. Isolated PostgreSQL-compatible fixtures cover routine/session/admission/documents/progress and simple finance/security.

These checks do not establish hosted Supabase Auth/email, production PostgREST relationship loading, authenticated role/workspace navigation, mobile behaviour or physical printer alignment. They must be tested in the actual environment. Do not call all 14 acceptance stages complete on the basis of isolated checks. [Delivery evidence](WORKSPACE_REDESIGN_DELIVERY.md) records the remaining limits.

## Commit discipline

One focused implementation/fix, verify, commit, then continue. Publish source per file and verify the Git blob checksum; reject truncated tool output. Run source integrity before build. Do not reset a live database or introduce a competing fee/admission workflow to mask a bug.

## Guided teacher class workspace

Teacher sessions now use a single start → student attendance → dated topics → homework → finish → review/submit workspace. Migration 56 adds durable class clocks and an atomic submission coordinator around existing attendance/class-log review engines. Clock duration alone is not verified/paid workload. Exam question drafts link to a published assessment so ordinary class preparation cannot satisfy exam readiness. Read [the Bengali operator workflow](TEACHER_CLASS_WORKSPACE_BN.md) before extending this path. Existing report corrections and independent review remain available; no second attendance or compensation model was introduced.
