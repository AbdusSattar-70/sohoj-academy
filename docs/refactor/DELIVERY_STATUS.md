# Delivery status — ৫ অক্টোবর ২০২৬

## Current fresh project
- One application: public CRM + `/dashboard` ERP. No `/academy` preview.
- One schema: modular SQL source, generated `supabase/migrations/01…07`. Legacy chain/seed/types/modules/docs removed; reference only on master.
- Foundation: academy, divisions, verified Auth bootstrap, roles/permissions, immutable audit, retry/stale guards.
- People identity/responsibilities: create/edit, active/inactive guard, paginated search. Responsibility is not login permission.
- Directory: shared dropdown records with school source verification, inline create/select, edit/inactive and search.
- Programme definitions: editable UI. Offering/fees/batch/year backend and public catalogue implemented; full UI pending.
- Public CRM visual design retained. Catalogue and public form use fresh RPCs. Applications stored as unverified JSON preferences without programme/class placement constraints or Student FK.
- Public submission acknowledgement and staff enquiry list connected. No student account required.

## Remaining implementation
1. Offering/year/fees/batches publishing workspace; verified relationship/account assignment UI.
2. Enquiry follow-up/correction/conversion and one-page direct/existing-student admission with physical paper consent.
3. Atomic invoice/discount/payment/receipt/enrollment workflow and print documents.
4. Teacher/student attendance, assessments/questions/progress, routine/session.
5. Salary/referral payout, running expenses and simple division-specific profit/reporting. Assets/depreciation/deep accounting excluded.
6. Guided initial setup, help and end-to-end local acceptance.

This fresh project is resettable but is not a feature-complete academy ERP. Setup instructions are in ../SETUP.md. Repository changes do not reset a live project.

## Verification
Fresh schema/essential-seed regression fixtures and public enquiry retry/privacy checks passed in isolated PostgreSQL-compatible PGlite. New complete-project route/type generation and TypeScript check passed. Source/migration/type parity checked. Browser acceptance, full production build and hosted reset have not been performed.
