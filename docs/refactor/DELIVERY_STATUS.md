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
