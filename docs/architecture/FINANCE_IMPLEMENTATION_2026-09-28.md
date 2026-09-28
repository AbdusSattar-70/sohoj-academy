# Finance integrity and operator workflow

This change extends the finance accounting foundation on `feature/finance_accounting_gap`. The canonical billing and adjustment workflows remain in migrations `0013`–`0016`; accounting and settlement live in `0042`–`0044`.

## Operator sequence

1. Use **Finance → Accounting & Settlements** to create vendors and accounts, request an advance or expense, and prepare a monthly teacher compensation run. The compensation policy is versioned under Governance → Rules.
2. A different authorized staff member reviews each advance, expense, compensation run, adjustment or advance-to-payable application. Approval cannot be performed by the requester.
3. Pay approved advances, post approved expenses, settle non-compensation payables, and settle each teacher's approved compensation. The latter may offset an outstanding teacher advance and pay the remaining cash.
4. Reconcile posted expenses against statement references and cash/bank accounts against a dated statement balance. A difference leaves reconciliation open for investigation.

## Integrity changes in migration 0044

- Compensation lines now retain the source admission ID. Approved compensation creates once-only claim records keyed by teacher and earning source, preventing replay across overlapping runs. A run must cover one calendar month; approval checks for an existing approved period.
- The teacher payable and journal are aggregated per teacher with unambiguous identifiers. The general payable command cannot bypass the teacher compensation settlement path.
- Net collected tuition uses posted payment and refund dates for the local collection month. Referral acquisition and retention lines are considered at their respective collection milestones.
- Advance application to a matching staff/vendor payable requires an independent approval. The approved payable and advance are linked on movement and settlement records; an advance offset is recorded separately from a cash payment.
- Internal ledger synchronization helpers are not callable by public/authenticated clients. Financial writes continue through permission-gated, audited RPCs.

## Verification and deployment

- Migration chain `0001`–`0044` and finance regression `0044_v2_finance_integrity.sql` passed in an isolated PostgreSQL-compatible PGlite run. The regression covers the retired shortcut and a two-actor advance request, maker-checker rejection, approval, payment, ledger and balance.
- The accounting route passed TypeScript, ESLint and a Next.js production build in the isolated source workspace.
- The complete legacy SQL suite still needs consent-aware fixture updates after migration `0040`; the new regression does not substitute for a live Supabase database, RLS and browser acceptance pass. Do not treat the branch as production certified until these gates and a realistic two-teacher compensation run pass against PostgreSQL.
- Apply migrations using `pnpm exec supabase migration list` and `pnpm exec supabase db push` after reviewing pending changes; then run `pnpm build` and test the request/approval/settlement sequence with two distinct staff accounts.

## Admission referral and acquisition reward (migration 0045)

Before acceptance, staff must record **Organic** or **Referred** in the Admission case. A referred student may point to an existing referrer or a new person registered in the same transaction with name, Bangladeshi mobile, relationship and contact note. Active staff can be selected directly. An existing mobile resolves to the existing identity, and a conflicting name requires manual verification. Historic accepted cases are classified from existing teacher referrals when available, otherwise Organic; draft cases require an explicit choice.

A linked teaching staff member flows into the versioned teacher compensation run. An external referrer follows Finance → Accounting & Settlements → External admission referrals: request an acquisition reward from the first local month of net collected tuition, obtain a different authorized approver, then settle the resulting referral payable from cash/bank. The reward uses the active `teacher_compensation.default_policy.acquisition_bonus_percent` at request time and stores the policy version and calculation snapshot. No reward is created for Organic admissions or before money is collected. Each admission can have one approved external acquisition reward; rejected requests may be resubmitted for review. A verified referral cannot be silently changed after acceptance.

The migration adds a dedicated referral liability account (2130) and student acquisition expense account (5200), keeps teacher acquisition in the teaching expense path, and preserves immutable journal history. The referral regression checks the admission acceptance gate, Organic, on-the-fly registration, and existing-person reuse. A complete live database test must also exercise a paid admission, external reward approval, payable settlement, teacher compensation and reversal timing.
