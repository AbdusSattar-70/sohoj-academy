# Operational clarity review — feature/sohoj_final

## Reported examples and implemented changes

| Problem | Change | Security / meaning |
| --- | --- | --- |
| Manage CRM hidden under an academic-directory label | Dedicated CRM sidebar group: Enquiries and Manage CRM & academic lists | Same master-data permission and canonical URL; no duplicate sidebar destination |
| Blank guidance or unclear first action | Immutable bilingual guide catalog and actual React render checks for both languages | Render checks prove content wiring, not authenticated browser acceptance |
| Routine page empty and create action buried among links | Create weekly routine appears before setup links; active setup tab is highlighted, routine links use its canonical sidebar route | Save routine first; use its row to generate dated sessions |
| No clear attendance entry | Dedicated Attendance workspace with role-filtered actions | Staff presence and student session attendance remain separate |
| Admin cannot record own day in My work | Enable recording for workforce.manage while preserving the personal route | Other staff view their attendance; no new self-certification permission granted |
| Student attendance action hidden behind a class title | Explicit Open class & student attendance action on each dated class | Session report uses existing assigned-scope and review permissions |
| Referral earnings compared to attendance's last-month cash | Personal attendance contains attendance figures; earnings tab shows all-period earned, paid and remaining referral amounts | Cash paid in a previous month is not total earned compensation |
| Test misunderstood as a student identity record | Create batch test; explain individual marks within that test | A batch/subject test is shared; each student's marks are separate |
| No selectable assessment scope | Explain missing scheduled teaching and offer role-appropriate recovery | Managers can prepare routine; teacher asks admin for assignment; no bypass of scope validation |

## Operator workflow — বাংলা

১. CRM ও আবেদন → আগ্রহী শিক্ষার্থী: পাবলিক আবেদন দেখুন। CRM ও শিক্ষা তালিকা পরিচালনা থেকে শ্রেণি, বিষয়, বছর, প্রতিষ্ঠান ও প্রযোজ্য registration lists ঠিক করুন। একই তালিকা নতুন করে অন্য জায়গায় তৈরি করবেন না।

২. শিক্ষা প্রস্তুতি → সাপ্তাহিক রুটিন: উপরের সাপ্তাহিক রুটিন তৈরি করুন button খুলুন। Batch, subject, qualified teacher, room, দিন ও সময় দিন। কক্ষ/সময়/যোগ্যতা না থাকলে inline setup actions ব্যবহার করুন। সংরক্ষণের পরে routine row থেকে তারিখভিত্তিক ক্লাস তৈরি করুন। Routine এবং বাস্তবে অনুষ্ঠিত class session আলাদা records।

৩. দৈনন্দিন কাজ → উপস্থিতি: নিজের দিন দেখতে আমার উপস্থিতি; অনুমোদিত ব্যবস্থাপক স্টাফ উপস্থিতি রেকর্ড/সংশোধন করতে পারেন। অন্য স্টাফের জন্য স্টাফ উপস্থিতি থেকে ব্যক্তি নির্বাচন করুন। শিক্ষার্থীর উপস্থিতির জন্য নির্দিষ্ট দিনের class খুলে class report-এ student roster দিন। ক্লাস না থাকলে আগে dated sessions তৈরি করুন। Teacher submission এবং admin acceptance আলাদা।

৪. আমার কাজ ও পাওনা → পাওনা ও পরিশোধ: অর্জিত referral reward, actual paid amount ও remaining balance দেখুন। Attendance-এর সময় বা উপস্থিত দিন মানেই অনুমোদিত salary নয়। Fixed/hourly payroll ও referral bonus আলাদা। বিস্তারিত referral statement-এ eligible tuition collection এবং settlement evidence দেখুন।

৫. পরীক্ষা ও ফলাফল: একটি batch এবং subject-এর জন্য একটি পরীক্ষা তৈরি করুন। পরে roster থেকে প্রত্যেক ছাত্রের marks দিন। এটি প্রত্যেক ছাত্রের জন্য আলাদা পরীক্ষা তৈরির প্রয়োজন বোঝায় না। Teaching scope না থাকলে manager routine প্রস্তুত করেন; teacher assigned batch/subject/class-এর জন্য admin-এর সঙ্গে যোগাযোগ করেন।

Rooms & availability now opens rooms initially, rather than unexpectedly opening programme teaching plans.

## Wider audit: remaining work, not claimed complete

- Many pages repeat a shell location heading and a full page heading; distinguish breadcrumb/location from the primary task title consistently.
- Bespoke legacy messages, enum labels and hints are not all translated; shared guidance is not a replacement for field-level copy.
- Planning navigation still contains many setup destinations; simplify context-relevant links while retaining prerequisite recovery.
- Empty-state copy and submit/review consequences need the same treatment on homework, curriculum, progress, payment and referral history pages.
- Check real user tasks with the local database: own versus other-person earnings, assigned class roster, new admission → session attendance → marks → approved progress.
- Native back/forward, narrow tablet layouts, physical print output and actual email delivery still require target-environment verification.

No new finance model, approval bypass, workspace isolation shortcut or database reset is introduced by these usability fixes.

## Regression commands

```sh
pnpm check:source
node scripts/check-workspace-navigation.cjs
node scripts/check-workflow-guides.cjs
node scripts/check-button-slot.cjs
node scripts/check-workflow-return.cjs
pnpm build
```
