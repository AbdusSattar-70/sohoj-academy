# Workspace redesign delivery — 2026-10-08

Branch: `feature/sohoj_final`. This file separates implementation and isolated evidence from real-user acceptance. It is not a claim that every legacy form, translation or workspace scope is finished.

| Plan step | Delivery and evidence | Acceptance boundary |
|---|---|---|
| 1. Workflow/ownership | `WORKSPACE_REDESIGN_WORKFLOW_BN.md`; bilingual in-ERP setup/admission/daily guide | Validate wording with actual operators |
| 2. Website vs academic settings | Separate server pages, permission-filtered sidebar entries and focused website payload | Offering showcase only; no full homepage/about/FAQ CMS |
| 3. Relevant page content | Removed duplicated planning links; section-specific actions/instructions; obsolete help replaced; header title no longer duplicates primary heading | Legacy pages beyond reviewed entry points still need visual audit |
| 4. Labels/guidance | Native label association, explicit bilingual text; real React render regressions for reported pages and fields | Original blank-label browser failure not reproduced in the target browser |
| 5. Central search | Header/Ctrl+K/mobile trigger; no sidebar input; bounded role/permission queries for students, guardian contact, enquiries, staff, offerings, classes, batches, admissions, referrers, invoices and receipt references | Teacher records only own session scope text; referrer-only users get permitted page links, not a global directory; no full workspace-filter guarantee |
| 6. Guided setup | Existing prerequisites/recovery preserved; legacy backend destination mapped to academic settings | Actual bootstrap setup/reopen flow requires hosted acceptance |
| 7. Teacher → routine → dates | Existing qualification, availability, conflict and holiday-aware generation tested with academic SQL fixtures; per-section instructions fixed | Test selected real teacher/time-zone/resource records |
| 8. Attendance/session changes | Separate staff/student/actual teaching workflows preserved; reschedule/cancel/makeup review fixtures passed | Staff self-entry depends on permissions; browser roster and actions need actual accounts |
| 9. One admission case | Existing direct/training intake, prerequisite navigation, inline collection/receipt preserved; dirty-step guard added; admission/payment/referral fixtures passed | Live finalization, return-to-case and printer acceptance remain |
| 10. Missing choices | Existing inline school/guardian relationship/referrer mechanisms preserved; academic master editor switching/close guarded | Not every dropdown is creatable; audit missing-choice needs by domain |
| 11. Documents/tests/progress | Existing teacher-initiated Docs submission and reviewed progress fixtures passed; operator guide clarifies batch test vs individual marks | Docs access/sharing and actual review usability remain human acceptance |
| 12. Simple finance/earnings | Existing simple finance/security/payroll/admission/referral fixtures passed; no competing accounting implementation added | Actual balances and profit must be reconciled on the connected environment |
| 13. Interaction/mobile/print | Inline close, master-editor replacement and admission steps protect drafts; routine close/panel changes protected; common feedback/navigation retained | Not all bespoke hints/errors translated; mobile/print and native browser-back need acceptance |
| 14. Authenticated end-to-end | Local acceptance checklist remains explicit; no live database reset/write performed | **Pending:** actual ADMIN/TEACHER/referrer, hosted RLS/PostgREST, School/Coaching/Training isolation, email, tablet/mobile and printer |

## Commits in this delivery

- `4318b8af`: Bengali workflow and page ownership.
- `8ad41d96`: split website and academic settings.
- `81772272`: native labels and bilingual guidance.
- `f45724a2`: header central search and sidebar search removal.
- `3f3bc437`: setup destination correction.
- `c6490305`: search authorization/render regressions.
- `4463ee23`: safe inline close/admission-step navigation.
- `e43f6fc0`: academic draft guards and website subject boundary.
- `3e717fb6`: actual invoice/admission schema search.
- `976984b5`: contextual academic planning instructions and safe editor changes.
- `e6274534`: guardian-contact and receipt-reference searches.
- `f7ad3659`: bilingual operator guide with permission-aware links.
- `61016102`: bilingual task-focused academic help.
- Receipt search additionally checks admission-print permission before returning a link.

## Checks

Source integrity, navigation/permissions, guide/field React rendering, search bounds/roles/schema names, button slot and safe-return scripts passed. TypeScript, changed-file ESLint and production Next build passed with placeholder Supabase configuration. Isolated PGlite academic fixtures 35/36/37, admission 01 and referral security 04 passed. Simple finance harness passed 23 checks plus admission/referral/payroll/simple-finance fixtures.

Mocked search regressions do not establish hosted PostgREST relation responses. Validate guardian-mobile and RCT searches with real records. Isolated SQL tests do not establish real email delivery or browser completion. No live environment credentials were available for those checks.

## Local verification order

1. Pull the branch, install dependencies and run build with your own `.env.local`; no reset is needed for these UI changes.
2. Admin: open Website management and Academic settings; confirm distinct content. Edit a master record, try close/tab switch and choose to keep unsaved input.
3. Search name/Student ID/guardian mobile/admission/invoice/RCT receipt; open results. Teacher must receive only assigned class results; a referrer must not receive academy-wide directory records.
4. Prepare teaching subject, room and weekly availability; save routine and generate dates. Verify one normal date and one closure/conflict.
5. Direct admission and enquiry conversion: prerequisites, physical consent, discounts, final invoice, partial payment, receipt and activation. Confirm direct intake creates no fake enquiry and repeat financial submissions do not duplicate records.
6. Teacher: student attendance/actual work, submit; admin: return/review. Submit Docs question material and approved test results; finalize a progress report.
7. Confirm own earnings vs actual payouts and running expense/profit totals. Test small-screen navigation, printer preview and all three operational scopes.

Remaining gaps above must stay visible until these outcomes are recorded; do not turn a pending live acceptance item into a completed checkbox.
