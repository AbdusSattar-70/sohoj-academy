# Refactor delivery status — ৫ অক্টোবর ২০২৬

## সম্পন্ন commits
1. Task-based sidebar: explicit group/order; Students → People; Admission/Enquiries/Programmes → Academics; Billing/Settings/Activity groups। Advanced finance entries hidden from navigation, routes still exist pending cutover. CRM visual files unchanged.
2. Fresh foundation SQL source and deterministic generation: academy/divisions/access, people/responsibilities, education/directory master tables and essential seeds. Secure retry-safe create/edit, directory inactive/reactivate and paginated search. This is backend foundation, not a completed new app.

## বর্তমান installation boundary
Generated foundation staged at `supabase/refactor/migrations/`; current app still uses inherited schema. It cannot safely be reset onto this foundation yet. Staging is temporary during atomic contract replacement; final deployment has only one new schema/migration set. Old development history will not be imported. No live database changes made.

## Verification
Isolated PostgreSQL-compatible PGlite passed SQL fixture including person retry, same family phone, multiple responsibilities, permission denial, RLS setup, stale revision, duplicate school, inactive choice filtering, audit attribution and pagination across 25-row boundary. Schema/generated-file parity checked. No Next build/CI/hosted acceptance claimed.

## পরবর্তী কাজ
- Current foundation models → runtime typed context and editable directory/People forms।
- Programme/offerings/batches/fees and division requirements।
- Public CRM data adapter retaining design।
- One-page admission and billing/print, then remuneration/expenses and academic workspace।
- Final fresh baseline cutover and remove legacy code/migrations/docs; publish reset/bootstrap guide then.


## Programme catalogue backend — পরবর্তী delivery

Completed the fresh programme definition/current offering, fee settings/components, subject choices, batch/seat and academic-year database commands. Initial school scope Play–8, coaching 9–12; training uses dates without forcing school class/year. Generated titles/codes reduce typing. Admin actions direct, no approval/version queue. Standard fees editable with stale/retry guards; initial admission billing will snapshot them in its later implementation.

Publication requires tuition settings; opening applications requires an active batch. Inactive runs excluded publicly; quick active/inactive command resets publication/intake, requiring deliberate reopening. Batch capacity has locked seat enforcement and cannot shrink below occupied seats. Fees/components and subject links preserve records through active flags. Search/list and per-run setup use whole-result counts and 25-row pages. Anonymous callers get only curated published catalogue, no mutations.

Isolated fixture 02 passed: adult course without school context, missing-fee publication rejection, invalid discounts, idempotent fees/run saves, one-seat capacity denial, scoped catalogue, inactive visibility, multiple active years, class-scope checks and audit/privilege boundaries. Foundation fixture still passes; generated/source parity passes. Hosted concurrency/browser not tested.

**Still pending:** connected People/directory/programme UI and verified account integration, public CRM adapter, admission/collection/enrollment orchestration, academic record workflows and simple financial reports. This is backend catalogue implementation, not a ready-to-reset full app. No live DB mutation. The temporarily generated file names reflect dependency sequence; final baseline will be consolidated at complete cutover.

## People / directory UI integration — ৫ অক্টোবর ২০২৬

Added temporary `/academy` workspace with authenticated, permission-scoped People, directory and programme-definition screens. People has one identity/multiple responsibilities, full correction and active/inactive controls. Directory covers schools/areas/subjects and shared choices with source verification and retained history. Programme definitions support create/edit/inactive; offering/fees/batch UI is still pending. Search is paginated (25 rows). Forms open on demand, close on success, preserve inputs on validation failure and show pending state. Inline directory creation auto-selects the saved record. Uncertain network results retry the same request ID instead of sending another mutation.

Verified account lookup uses Auth getUser; RPC contracts are generated from the staged SQL. Person responsibilities never grant account permissions. The new screens need a disposable project with the staged fresh schema and initialized admin. They do not operate against the inherited project's schema. Do not run the normal old migration set together with this foundation. The temporary route is removed/replaced at final cutover; it is not a second permanent ERP.

Checks: new workspace TypeScript check and existing isolated SQL regression/seed fixtures passed. Full repository build, browser acceptance and hosted deployment are not claimed. No live database mutation.

Next: offering/fees/batches editor; public CRM adapter; one-page admission/billing/payment/printing; academic workflows and simple income/expense reports; final single-schema cutover and reset/bootstrap instructions.
