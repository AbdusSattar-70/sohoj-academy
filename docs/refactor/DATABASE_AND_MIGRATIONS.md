# নতুন database ও migration contract

## Fresh installation
নতুন first version-এর জন্য inherited 01–44 migration chain implementation phase-এ প্রতিস্থাপিত হবে; পুরোনো development history import/backfill নয়। এই docs commit পুরোনো migration delete বা database reset করেনি। নতুন schema complete না হওয়া পর্যন্ত inherited app-কে নতুন schema-compatible বলা যাবে না।

Existing project-এর ক্ষেত্রে reset local/linked target স্পষ্ট করে user-run setup guide থাকবে। নতুন project সবচেয়ে পরিষ্কার alternative। Application reset Auth identities/Storage files সবসময় মুছে দেয়—এমন অনুমান নয়; intended bootstrap identity রেখে বা নতুন verified admin তৈরি করে আলাদাভাবে cleanup করতে হবে। Secrets commit নয়। Replacement baseline old schema-তে db push বা migration repair দিয়ে applied সাজানো নয়।

## Proposed files ও dependency
| ক্রম | File | দায়িত্ব |
| --- | --- | --- |
| 01 | 01_academy_divisions_and_access.sql | academy, campus, divisions, profile/access functions |
| 02 | 02_people_and_relationships.sql | person/contact, guardian/student/staff/referrer identities |
| 03 | 03_academic_directory_and_programmes.sql | education level, class/degree/major, subjects, programmes/offerings/batches, fee setup |
| 04 | 04_crm_applications.sql | unverified applications/snapshot, follow-up |
| 05 | 05_admissions_and_enrollments.sql | drafts, verified placement, physical consent, admission/enrollment |
| 06 | 06_billing_collections_and_refunds.sql | invoice lines, discounts, collection/allocation, receipt/refund; atomic admission finalizer |
| 07 | 07_staff_remuneration_and_referrals.sql | salary/workload terms, award/payable/payment |
| 08 | 08_running_expenses.sql | category, actual expense, paid/unpaid/partial settlement, shared allocation |
| 09 | 09_academic_operations.sql | routine/session, attendance, homework, assessment/question/review/progress |
| 10 | 10_security_audit_and_integrity.sql | final grants/RLS, triggers/indexes, audit and cross-record integrity |
| 11 | 11_essential_setup_data.sql | editable system/master seeds; bootstrap no public password |

এই names proposed; actual dependencies অনুযায়ী split হবে। 01 access function future table reference করবে না। 05 admission table আগে তৈরি; invoice-dependent finalizer 06-এ। 07 workload calculation 09-এর records পরে ব্যবহার করলে function installation order সমন্বয় করতে হবে। প্রতিটি table creation-এ RLS enable/revoke; final grants-এর আগেও client write খোলা নয়।

## Core logical records
Academy → divisions/campuses; Person → contacts/relationships + student/staff/referrer roles।
Programme → offering → batch; enrollment links person/student + offering/batch/division।
Application original JSON snapshot, optional verified linkage; draft admission verified identities + placement।
Invoice owns immutable fee/component/discount snapshot; payment owns actual amount/method/reference; allocations link invoices। Refund links original receipt/allocation। Consent owns identity revision/date/file reference।
Staff/referral earning entitlement has basis/policy snapshot; payable ও actual settlement পৃথক।
Expense incurred date/amount/category/division; settlement আলাদা। Shared expense has allocation lines; sum cannot exceed expense।
Audit actor/person/role/action/entity/time/reason; request ID internal trace/retry, default audit columns নয়।

## Integrity
Division derived/validated from offering/invoice; unrelated division ID client override নয়। Currency initial BDT; decimal arithmetic authoritative। Batch active capacity lock; school roll unique per configured school-year/section context, stable student number lifelong। Active academic years একাধিক হতে পারে।
Soft inactive stops new use, history readable। Unused draft can cancel; permanent records/posted evidence destructive delete নয়।
Fee changes current setup; previous invoice snapshot unchanged। Operator-facing version queues নেই; internal revision/stale-check দরকার।
Recurring student invoices explicit month/term/course schedule, duplicate period guard; background inferred collection নয়।
Universal class requirement নয়; degree year/semester and major optional/required by programme template।

## Maintainable SQL source
`supabase/schema/{platform,people,academics,crm,admissions,billing,workforce,security}/`-এ readable current definitions; `supabase/migrations/` deployable ordered changes। প্রথম implementation-এ deterministic composition/check process নির্ধারণ করতে হবে—দুটি manually divergent source নয়।
একই baseline-এ repeated patch/redefinition নয়। ছোট function: validation, scoped lookup, balance, post, audit। Giant multi-action function থাকলে dispatch ছোট হবে; কাজ domain functions-এ।
Baseline release-এর পরে applied migrations edit নয়; subsequent ordered migrations। Types regenerated from new schema, handwritten shadow contracts নয়।
