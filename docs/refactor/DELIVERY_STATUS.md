# Delivery status — ৫ অক্টোবর ২০২৬

## Current fresh project
- One application: public CRM + `/dashboard` ERP. No `/academy` preview.
- One schema: modular SQL source, generated `supabase/migrations/01…11`. Legacy chain/seed/types/modules/docs removed; reference only on master.
- Foundation: academy, divisions, verified Auth bootstrap, roles/permissions, immutable audit, retry/stale guards.
- People identity/responsibilities: edit existing identities, active/inactive guard, role-tab paginated search; staff/referrers enter through reviewed access requests. Responsibility is not login permission.
- Directory: shared dropdown records with school source verification, inline create/select, edit/inactive and search.
- Programme definitions: editable UI. Offering creation/context/subjects/public copy, initial and current fee components/discounts, batch creation/edit/inactive and multiple academic-year management are available in one Academics setup workspace. Public catalogue uses those same records.
- Public CRM visual design retained. Catalogue and public form use fresh RPCs. Applications stored as unverified JSON preferences without programme/class placement constraints or Student FK.
- Public submission acknowledgement and staff enquiry list connected. No student account required.

## Remaining implementation
1. Verified guardian relationship UI and one-page admission identity/placement.
2. Enquiry follow-up/correction/conversion and one-page direct/existing-student admission with physical paper consent.
3. Atomic invoice/discount/payment/receipt/enrollment workflow and print documents.
4. Teacher/student attendance, assessments/questions/progress, routine/session.
5. Salary/referral payout, running expenses and simple division-specific profit/reporting. Assets/depreciation/deep accounting excluded.
6. Guided initial setup, help and end-to-end local acceptance.

This fresh project is resettable but is not a feature-complete academy ERP. Setup instructions are in ../SETUP.md. Repository changes do not reset a live project.

## Verification
Fresh schema/essential-seed regression fixtures and public enquiry retry/privacy checks passed in isolated PostgreSQL-compatible PGlite. New complete-project route/type generation and TypeScript check passed. Source/migration/type parity checked. Browser acceptance, full production build and hosted reset have not been performed.

## Persistent starter setup
Migration 08 adds 2026/2027 years, four reusable programme definitions, three editable offering/fee/batch setups, local area choices and six official-source school names. Defaults are unpublished until reviewed. Repeated starter seeding preserves operator edits. School forms ask for name, optional area; other fields collapsed and optional. See SEED_DATA.md for use.

## Seed ID validation correction
PostgreSQL database IDs use canonical GUID validation, including deterministic starter IDs; browser-generated request tokens retain strict UUID validation. Existing data and IDs remain unchanged. Programme/offering reads, setup/edit inputs and public-form seed IDs passed isolated SQL-to-Zod checks; malformed IDs were rejected. Complete-project TypeScript check passed. No new migration or reset required.

## People contacts and duplicate assistance
People can be saved with no mobile/email, or with shared family contacts. Permanent Person IDs remain unique; responsibilities do not grant account access. Migration 09 adds permission- and academy-scoped matching (name/mobile/email, maximum 10 records, including inactive identities). The editor offers advisory matches after leaving identity/contact fields, optional existing-person edit, and preserves the ability to save a different person. Matching failure never blocks saving. No automatic merge or account creation. Login provisioning remains a separate upcoming workflow.

People contact checks passed in isolated PostgreSQL-compatible PGlite: blank/shared contacts, unique permanent IDs, exact contact matches, edit exclusion and no login-link creation. TypeScript and production build passed (no hosted database mutation or browser acceptance performed).

## Familiar ERP structure and workflow-owned identity
Grouped desktop collapsible sidebar, accessible mobile navigation, current-route header, dashboard/back links and bilingual setup/help replace the flat preview navigation. A client-safe route registry owns primary route placement. School/Coaching/Training selection filters the offering register in SQL; People/directory remain shared (this UI filter does not replace access control). CRM visuals remain unchanged. Finance/admission remain explicitly pending.
People no longer offers generic creation; database commands also reject a generic new Person. Student/guardian creation belongs to upcoming admission. Public staff/referrer access requests remain unverified claims. Admin-only paginated review matches existing identities and confirms new-person creation, then grants the permitted login role and sends secure setup instructions. Repeated request/review/setup reuses the same identity/account; shared contacts never auto-merge. Server-only invitation configuration is documented in Settings & Help. Email delivery/hosted Auth acceptance has not been executed.

Verification for migration 10: isolated PostgreSQL-compatible checks passed for no public Person/access creation, request deduplication/no overwrite, review/setup retry identity reuse, first-sign-in activation, responsibility filtering, rejected generic creation and anonymous review denial. Production compile/TypeScript passed; browser/mobile visual acceptance and hosted email delivery remain local acceptance tasks.

## Offering setup completion
Create offering → set standard fees/discounts → create batch → publish/open applications stays on `/dashboard/academics?tab=programmes`. Missing programme/subject/year can be created and selected inline; year management opens only when requested and supports several active years. Title/code are optional generated defaults. School uses Play–8, Coaching 9–12 and Training course dates without class/year.
Public copy/date fields now persist on creation; English/Bangla copy are editable. Fees can be configured for a new offering with tuition/admission defaults, optional exam/material/other components and explicit allowed discounts; blank amounts are not silently zero. Batch edit preserves occupancy constraints and blocks deactivation of occupied or last intake batch. Context can be corrected before any placement history; later history locks context. Run-before-batch locking serializes context edit versus seat assignment. No posted financial history exists in this branch yet.
Isolated PostgreSQL-compatible checks passed: create/retry, public copy/dates, subjects/setup metadata, first fee plan, batch, public publication, empty-context correction, historical-context lock, last-batch intake guard and multiple active years. TypeScript passed; browser/print and hosted acceptance remain local tasks.

Production build passed for the completed setup workspace. Local hosted/browser acceptance and end-to-end admission remain pending.

## Unified Academics workspace
One sidebar entry replaces three academic links. Programmes, Admissions (explicitly pending) and Academic settings are tabs on `/dashboard/academics`. Academic settings embeds shared choices, reusable programme names and year management. Legacy academic URLs redirect to the matching tab/category. Plain operator wording replaces offering/definition/directory labels; public CRM styling and database model stay unchanged. Unsaved changes require discard confirmation before section switching; pending/uncertain requests block switching. No database migration required for this UI consolidation.

Unified workspace verification: complete route/type generation and production build passed. No database reset/migration added. Browser visual and keyboard acceptance remain local verification tasks.


## Academic operations branch
`feature/academic_operations` adds migrations 12–13, `/dashboard/academics/sessions`, resource availability, dated sessions, bounded weekday routines, closures, teacher report review and a leased notification outbox. See [Bangla operator guide](ACADEMIC_OPERATIONS_WORKFLOW_BN.md) for exact scope and unfinished extensions. Hosted email delivery needs provider configuration and a scheduler; no live email was sent during verification.


## Focused academic navigation and reads
Current routes supersede the earlier all-in-one tabbed workspace: `/dashboard/academics` is a guided start page; settings, programmes and class operation have separate routes. Settings loads only the chosen section. The start page and settings menu do not fetch academic registers; authentication and academy permission checks remain. Programme registers initialize once, including development effect replay. Class lists use migration 16's session-only RPC; scheduling choices load only when a scheduling form opens. Settings registers are paginated, and notification contacts remain admin-only.

Teacher qualification and dated unavailability controls are implemented by migrations 14–15. Student attendance and routine edit/inactive remain pending; the latest direction prioritizes simple navigation before those extensions. Saving no longer invalidates the entire dashboard layout. Public catalogue edits invalidate the public pages while editors explicitly refresh their own register. See [Bangla navigation guide](ACADEMIC_NAVIGATION_AND_LOADING_BN.md).

Focused navigation verification: production build, TypeScript, targeted ESLint and schema/RPC parity checks passed. Isolated SQL checks covered task-only payloads, 25-row pagination, teacher-only session visibility and denied teacher/anonymous settings reads; existing programme/class/notification fixtures also passed. Hosted browser performance and live email delivery were not measured.


## Scheduling and class delivery — migrations 20–25

The older attendance/routine-pending statements above are superseded by this section. [Current Bangla class guide](CLASS_SCHEDULING_DELIVERY_BN.md) is authoritative for this delivery.

Implemented: read-only date/resource/conflict preview; combined contiguous weekly windows; programme weekday defaults; day-specific batch time defaults; multi-day availability with edit/revision/future-coverage guards; separate paginated Routine and Calendar routes; next-period generation; explicit atomic future replacement with rollback and historical preservation; class reschedule/substitute/room/cancel/makeup; dated batch enrollment/transfer/close; teacher attendance/draft/report/homework/assessment notes; independent admin review; verified actual teaching-hours summary; teacher first-page agenda and returned work.

Public CRM design is unchanged. One-page new-student admission, payments/receipts, full assessments/question bank, staff presence and payroll calculation remain outside this academic delivery. Enrollment integration is a controlled contract available to the upcoming admission workflow; do not describe the admission placeholder as complete.

Validation: production build and TypeScript passed; changed-component lint and isolated SQL lifecycle/permission/retry tests passed. No live database reset, hosted migration, browser acceptance or real email was performed.
