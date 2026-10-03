# Lean EduOps — বাস্তবায়ন ও commit পরিকল্পনা

তারিখ: ৪ অক্টোবর ২০২৬। সব implementation milestone নিচে Pending।
[Blueprint](LEAN_EDUOPS_BLUEPRINT.md) | [Operator workflow](LEAN_EDUOPS_WORKFLOWS_BN.md)

## বর্তমান ভিত্তি ও যাচাইয়ের সীমা

Base master commit: `00f11f2358516bc7362e1984836f09584085b4e7`; finance PR #21 merged।
Repository-তে migrations 01–22 আছে। পুরোনো schema/handoff-এর 92 tables/126 functions সংখ্যা pre-16 historical snapshot; current count হিসেবে ব্যবহার করা যাবে না।
Routes-এ academic operations, sessions, assessments ও questions ইতিমধ্যে আছে। Academic engine পুরো absent বলা যাবে না; বাস্তব capability inventory প্রয়োজন।
Purchases বর্তমান journal engine reuse করে। Operational/accounting separation এখন target; implemented claim নয়।
এই ধাপে source files ও architecture docs review হয়েছে; build, live DB, RLS বা runtime behavior verify হয়নি।

## Scope ও ordered milestones

| ক্রম | কাজ ও প্রস্তাবিত commit | Done হওয়ার শর্ত |
| --- | --- | --- |
| 0 | docs: define lean modular EduOps baseline | Blueprint, workflows, roadmap ও entry links committed |
| 1 | docs: inventory existing domain and dependency contracts | Actual table/function counts; module/RPC/route inventory; accounting/consent/tenant dependencies; reuse/refactor decisions with file references |
| 2 | feat: establish organization scope and module controls | Membership-derived tenant, tenant-consistent references, RLS/RPC/files/jobs, per-tenant feature controls; দুই tenant isolation tests pass |
| 3 | refactor: separate operational money from accounting projection | Authoritative money model, stable request identity, transactional outbox, idempotent consumer; accounting-disabled invoice/payment/receipt/refund/expense/settlement pass |
| 4 | feat: unify course creation workflow | Programme reuse + Offering + fees + optional batch single atomic command; draft/open/free-course/capacity/history checks |
| 5 | feat: simplify CRM admission conversion | Direct admission ও verified conversion, optional pay-now, no default consent gate, permanent IDs, duplicate/concurrent capacity protection |
| 6 | feat: complete academic planning and lesson delivery | Existing capability gaps only; plan/routine/topic coverage/attendance/homework; no compensation dependency |
| 7 | feat: connect assessment progress and teacher work | Tagged marks, absent/unmarked distinction, evidence-based progress, tasks and effective compensation snapshots without duplicate accrual |
| 8 | feat: simplify business operations and asset workflows | Purchases/supplier/staff payments/advances, basic assets/maintenance/disposal; single linked outflow, partial settlement and evidence |
| 9 | feat: expose optional accounting integration and reconciliation | Cutover/opening/replay controls, correction events, failed sync recovery, closed-period exception, balanced projection |
| 10 | feat: complete owner onboarding and daily workspace | Bangla/mobile workflow, actionable dashboard, permissions/module-aware UI, organization branding/defaults |
| 11 | test: verify migration and multi-tenant release acceptance | Data-preserving upgrade rehearsal, old/new balance comparison, feature-off behavior, cross-tenant export/file/job tests ও rollback playbook |

Milestone 1 সবচেয়ে আগে; inventory অনুযায়ী পরবর্তী milestones ছোট vertical slices-এ ভাঙতে হবে। Tenant ও operational money foundation stable হওয়ার আগে SaaS shared rollout নয়। Commercial tiers/AI/guardian portal পরে; এগুলো core completion blocker নয়।

## প্রতি feature-এর পদ্ধতি

১. Intended behavior, impacted existing contracts ও acceptance criteria লিখুন।
২. একটি coherent feature implement করুন; additive migration, regenerated types ও all consumers একসঙ্গে।
৩. সংশ্লিষ্ট meaningful SQL/domain tests; UI বদলালে affected owner/teacher flow এবং mobile check।
৪. pnpm project scripts দেখে প্রযোজ্য type/build/lint checks; failure বা unavailable integration clearly record।
৫. Diff review: unrelated files, credentials, duplicate model এবং destructive migration নেই।
৬. Handoff/roadmap-এ actual outcome, commit, checks ও remaining limitations লিখুন।
৭. এক feature এক commit; checkpoint ছাড়া অনেক অসম্পূর্ণ feature জমিয়ে রাখবেন না।

Docs-only commit-এ runtime tests দরকার নেই; relative links, scope, status ও contract consistency যাচাই করতে হবে। Documentation milestone application implementation হিসেবে mark করা যাবে না।

## Migration strategy

Existing deployed baseline 01–22 edit/reset নয়। Next verified ordered migration থেকে additive upgrade হবে; exact filename inventory-এ স্থির করুন।
প্রথমে existing organization/membership schema বুঝুন, তারপর tenant backfill, constraints, permissions ও consumers বদলান। Orphan/ambiguous membership manual reconciliation queue-তে; guess করে organization assign নয়।
Existing invoice/payment/allocation/student IDs/audit/physical evidence/journals preservation mandatory। Legacy journal থেকে operational money backfill-এ source mapping দরকার; original payment এবং its journal একই receipt হিসেবে duplicate নয়।
Dry run copy-তে pre/post row counts, receivable/payable/cash totals, identity references এবং journal balance compare করুন। Backups, reversible deployment sequence ও worker pause/restart plan থাকবে।
Accounting consumer চালুর আগে event cutoff ও opening balance reconcile করুন। Feature-off মানে historical data delete নয়।

## Acceptance scenarios

- Tenant A-এর session, invoice, receipt, private document, report/export বা background event tenant B access করতে পারে না; owner role tenant boundary bypass করে না।
- Accounting off থাকলেও course/admission/invoice/partial collection/receipt/refund/expense/asset purchase/teacher settlement কাজ করে।
- Consumer unavailable হলে transaction ও receipt valid; queue recover হলে একবার journal; repeated event duplicate নয়।
- একই admission/course/payment request unchanged retry-এ একই result; concurrent batch last seat overfill নয়।
- Shared guardian phone দুই sibling auto-merge নয়; direct admission fake Prospect নয়।
- Fee edit old agreement/invoice বদলায় না; discount/refund allocation exceeds limit হলে atomic rejection।
- Cash transfer দুই linked legs; purchase/payment/advance clearing cash দুইবার গণনা করে না।
- Session cancelled বা homework unreviewed progress/earned pay inflate করে না; total-only score থেকে fabricated topic insight নয়।
- দুই organization-এর same course/student-code namespace scoped; same organization permanent ID পুনর্ব্যবহার নয়।
- Backfill/deploy failure হলে supported previous application compatibility বা documented recovery আছে; live reset নয়।

## পরবর্তী নির্দিষ্ট কাজ

Milestone 1: existing database/RPC/domain inventory এবং dependency map। Deliverable-এ exact files ও accounting calls identify করে প্রথম decoupling slice নির্বাচন করতে হবে। এই documentation commit-এর পরে এখনও কোনো schema/runtime পরিবর্তন হয়েছে বলে ধরে নেওয়া যাবে না।
