# Sohoj Academy ERP — Implementation Guardrails

The authoritative product blueprint is the Google Doc **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.0**. This repository implements it incrementally.

## Non-negotiable engineering rules

1. **Traceability first.** Important mutations must be attributable to an actor, entity, action, time, and reason/context. Cross-table business workflows should share a correlation ID.
2. **No destructive business-history deletion.** Prefer lifecycle status, archive, revision, reversal, void, cancellation, refund, or controlled anonymisation.
3. **Workflow before form.** UI mirrors the user's job-to-be-done, not raw database columns.
4. **No ambiguous fields.** Every operational control has a persistent label, Required/Optional state, helper text where useful, field-level validation, and clear success/error feedback.
5. **Accessibility baseline: WCAG 2.2 AA.** Keyboard paths, visible focus, semantic labels, screen-reader feedback, adequate touch targets and contrast are required.
6. **Canonical master data.** Reusable values (schools, areas, vendors, lead sources, etc.) are referenced by IDs. Free text is kept only when it is truly free text or as an intentional historical snapshot.
7. **Business rules are versioned.** Compensation percentages and academy-wide policies are settings with effective dates and history; active rules are not silently overwritten.
8. **Approval-based finalisation.** Teacher-entered academic records such as attendance/results/questions should support submit → review → approve/reject before becoming final where policy requires it.
9. **Financial corrections are compensating events.** Posted money is never silently edited/deleted. Use reversal/refund/adjustment and preserve the original.
10. **Advances are balances, not final expenses.** Staff, teacher and vendor advances remain outstanding until explicitly settled/refunded.
11. **Plan vs actual is separate.** Curriculum plan, scheduled session, actual coverage, homework and recovery work remain distinguishable and traceable.
12. **Modular monolith.** Keep domain boundaries strong; avoid premature microservices.
13. **Server Actions stay thin.** UI → validation → authorisation → domain service/RPC → transaction → audit → revalidation.
14. **Critical integrity belongs in the database too.** UI validation is not enough for batch capacity, marks bounds, roster membership, duplicate bonuses, receipt identity, etc.
15. **Mock-data verification is mandatory.** A passing TypeScript build does not prove an operational workflow is correct.

## Current implementation order

### Phase 0 — Foundation now
- universal audit-event foundation
- versioned business-rule foundation
- generic approval-request foundation
- canonical School master data
- database-enforced batch capacity/integrity
- accessible/no-ambiguity form foundation
- explicit Supabase error handling
- role-aware navigation and unfinished-feature states
- CI quality gate

### Phase 1 — CRM + Student Core
- prospect/student bank
- public interest-registration portal
- lead source/campaign/interests/follow-ups
- SmartSelect master-data UX
- admission refactor with fee/referral/batch availability
- student timeline/global search

### Phase 2 — Academic Operations
- curriculum structure and plan versions
- chapter/page/topic/learning-outcome coverage
- routine templates vs actual class sessions
- teacher leave/substitution
- session plan vs actual class log
- homework
- coverage gaps and recovery sessions
- question-generation/question-bank approval workflow
- approval-based attendance/results
- academic-health dashboard

Subsequent phases follow the master blueprint: Finance & Billing → Staff/Teacher Compensation → Assets/Procurement → Accounting → Portals/PWA → Intelligence.

## Acceptance test for every feature

A feature is not complete until we can answer **yes** to all four:

1. Can a new employee understand it without verbal explanation?
2. Can management trust the data and financial meaning?
3. Can an auditor reconstruct what happened and who changed it?
4. Can we extend it years later without rebuilding the foundation?
