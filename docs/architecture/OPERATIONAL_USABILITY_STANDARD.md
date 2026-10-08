# Operational usability standard — feature/sohoj_final

## Scope and findings

Keep existing CRM appearance and database workflows. Simplify navigation by responsibility, preserve contextual actions that continue a case, and make consequences understandable. Sidebar labels are an interface convention, not authorization: existing server permissions, RLS and controlled RPCs remain authoritative.

Reviewed entry points: ERP route registry/sidebar/header/account, overview, teacher class workspace, personal work, staff operations/task register, shared ERP fields, academic document actions and route loading/recovery. This is a foundation rollout; it does not claim every legacy form or every page has been rewritten.

| Finding | Implemented treatment |
| --- | --- |
| Academic setup and teaching mixed across groups | Stable ordered Daily work, Academics, People, Fees & expenses, Academic setup, Administration, Support groups |
| Teacher My Classes and Sessions compete as primary destinations | Teacher My Classes is the canonical sidebar entry; the full calendar remains a contextual link |
| Personal pay, reimbursements, attendance and tasks spread across pages | My work has Attendance, Assigned work and Earnings tabs; statements/claims are contextual actions under Earnings |
| Admin assignment buried below attendance | Staff work has a dedicated Assign & review work tab, staff selector and overview shortcut |
| Every personal work area fetched together | Fetch the selected tab only; admin task tab still uses staff workforce context for the recipient directory |
| Parent Staff and nested Staff operations both highlighted | Resolve the deepest registry match |
| Account link duplicated | Footer is the canonical account/logout entry |
| Overview back-links are meaningless for teachers | Back to workspace goes through role-aware landing, with no self-link on overview |
| Role menu could prefetch many server pages | Disable sidebar prefetch; search is client-only |
| Large teacher session cards | Compact dated table; Today/Upcoming/Recent buttons and one Open class action |
| Guidance hidden outside the workflow | Collapsible bilingual page guides, optional tap/focus/hover help, visible action consequences for question/report submissions |
| Inconsistent request feedback | Reuse shared loading buttons and persistent saved/notice banner; logout errors leave user on page |

## Navigation contract

Each permitted route has one primary sidebar destination. Menus are filtered by assigned permission before rendering. Hiding a link is never a security control. Administrators retain academic setup, staff assignment/review, admissions, fees and administration. Teachers land on My classes and use My work for their own tasks/attendance/earnings. Other self-service staff land on My work; staff with operational permissions retain overview. Referrer-only accounts retain their own portal and footer account entry. Combined roles never bypass permissions.

Support routes are added to the registry. Review queue remains reachable from Action centre and contextual workflows, rather than a second review menu. Expand the active group; other groups can collapse. Search labels in the chosen language or English. On mobile, choose a destination then close the drawer. Show name, staff ID and roles once in the account footer.

## Interaction contract

Use existing records before creating choices. Required/optional labels follow selected locale. A short hint is visible; longer help must support tap, focus and hover. Actions describe their actual effect: draft save is not submit; submit is not approval; invoice is not payment; teacher task completion is not admin acceptance. Add meaningful help explicitly; do not manufacture generic descriptions for every input.

Show pending state and prevent double-clicks. Preserve invalid input. Store a stable request identity for retries where supported. A saved banner remains visible after an inline form closes. For the migrated task/document editors, sidebar navigation blocks pending saves and confirms unsaved input. This guard does not replace server idempotency and does not yet cover every legacy editor or browser tab close.

Academic questions originate from teacher routine, not administrator task assignment. Admin staff tasks cover other named responsibilities with due date, instructions, progress, blockers and review. No task percentage automatically adjusts pay.

## বাংলা পরিচালনা

Admin: দৈনন্দিন কাজ → সারসংক্ষেপ → স্টাফকে কাজ দিন; অথবা শিক্ষার্থী ও স্টাফ → স্টাফের কাজ ও উপস্থিতি → কাজ দিন ও পর্যালোচনা করুন। আগে সংশ্লিষ্ট স্টাফ নির্বাচন করে কাজ দেখুন। নতুন কাজ দিতে দায়িত্বপ্রাপ্ত ব্যক্তি, সময়সীমা, প্রত্যাশিত ফল ও নির্দেশনা দিন। জমা কাজ যাচাই করে গ্রহণ বা সংশোধনের জন্য ফেরত দিন।

Teacher: sign in → আমার ক্লাস → আজ → ক্লাস খুলুন। উপস্থিতি ও প্রকৃত পাঠদানের তথ্য জমা দিন। প্রশ্ন নিজের routine থেকে প্রস্তুত করুন। নিজের উপস্থিতি, অন্য নির্ধারিত কাজ এবং পাওনা আমার কাজ ও পাওনা পেজের আলাদা tab-এ পাবেন।

মেনু খুঁজতে বাংলা অথবা ইংরেজি নাম লিখুন। প্রতিটি migrated পেজের উপরের নির্দেশনা খুলে প্রথম কাজ ও পরের ধাপ দেখুন। কাজ চলাকালে অন্য পেজে যাবেন না। ব্যর্থ হলে input রেখে সমস্যাটি ঠিক করুন; ফল অনিশ্চিত হলে বিদ্যমান record আগে দেখুন।

## Remaining rollout

Extend the explicit help catalog to fees, rooms, curriculum, student lifecycle, referral policy and remaining operating forms. Audit legacy forms individually for localization, loading, dirty-state guards, unclear action labels and missing create-on-the-fly choices. Do not mass-delete links: distinguish duplicate primary destinations from context-preserving shortcuts. Full one-page admission/receipt acceptance, mobile print previews, workspace isolation and live-user task completion must be verified on the actual database/browser. No new database migration or financial rewrite is introduced by this rollout.

## Verification

Run `node scripts/check-workspace-navigation.cjs` for permission filtering, unique destinations, role landing and deepest-route regression checks. Changed TypeScript components pass local lint/type checks and `next build --webpack` with placeholder configuration. No live Supabase write or authenticated browser acceptance is represented by these checks.
