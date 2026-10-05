# Delivery status — ৫ অক্টোবর ২০২৬

## Current fresh project
- One application: public CRM + `/dashboard` ERP. No `/academy` preview.
- One schema: modular SQL source, generated `supabase/migrations/01…10`. Legacy chain/seed/types/modules/docs removed; reference only on master.
- Foundation: academy, divisions, verified Auth bootstrap, roles/permissions, immutable audit, retry/stale guards.
- People identity/responsibilities: edit existing identities, active/inactive guard, role-tab paginated search; staff/referrers enter through reviewed access requests. Responsibility is not login permission.
- Directory: shared dropdown records with school source verification, inline create/select, edit/inactive and search.
- Programme definitions: editable UI. Offering/fees/batch/year backend and public catalogue implemented; starter/current offering edit, fees/discounts and existing batch edit UI added; creation and subject/context editors pending.
- Public CRM visual design retained. Catalogue and public form use fresh RPCs. Applications stored as unverified JSON preferences without programme/class placement constraints or Student FK.
- Public submission acknowledgement and staff enquiry list connected. No student account required.

## Remaining implementation
1. New offering/batch creation, subject/context editing and academic-year UI; verified guardian relationship UI.
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
