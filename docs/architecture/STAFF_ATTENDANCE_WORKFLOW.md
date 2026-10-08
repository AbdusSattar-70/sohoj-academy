# Staff attendance — one person, one day

Branch: `feature/sohoj_final`. Entry: `/dashboard/attendance`.

## Operator workflow

1. Admin opens **Daily work → Attendance**. Their linked active Staff identity is selected by default; choose another staff member when needed.
2. The attendance date defaults to today in Bangladesh. Choose a previous date for late entry or correction. Actual attendance is not recorded for a future date.
3. Choose **Present, Absent, On leave or Academy holiday**.
4. Present requires actual **start and end clock times**. There is one attendance date, not three date/time selectors. Absent/leave/holiday need no time and retain no work hours.
5. Optional Break / overnight details stay collapsed. For an overnight shift, select **End time is on the next day**. Record after work finishes; a future end time is rejected.
6. Use a predefined reason, or Other with a short explanation. Save shows loading, prevents a second click and reports the result.
7. Existing records load for the selected person/date. Saving a correction updates that daily record and keeps audit history; it does not create a second attendance. Changing person/date protects unsaved input. Lookup failure blocks save until loading succeeds.
8. Select the next person/date without leaving the page. Use **Attendance reports** only to view monthly records; month selection is not required to create attendance.

Staff and My work report buttons now open this same attendance entry with person/date preselected. Compensation terms remain separate. Student attendance stays on the dated class report; staff presence never substitutes for student attendance or approved teaching hours.

## বাংলা উদাহরণ

Admin নিজের সকাল ৮টা–১০টার কাজ রেকর্ড করবেন: Attendance খুলুন → নিজের নাম → আজ → উপস্থিত → শুরু ০৮:০০, শেষ ১০:০০ → Save attendance। সময় ইতিমধ্যে শেষ হতে হবে। বিরতি না থাকলে আলাদা লিখতে হবে না।

অন্য শিক্ষকের গতকালের ছুটি: তাঁর নাম → গতকাল → ছুটি → সংরক্ষণ। শুরু–শেষ সময় লাগবে না। গতকালের একই রেকর্ড থাকলে সেটি আগে দেখাবে, তারপর সংশোধন সংরক্ষণ হবে। ভুল status দিলে নতুন duplicate তৈরি না করে একই দিনের রেকর্ড সংশোধন করুন।

রিপোর্ট দেখতে Attendance reports খুলুন; মাস দিয়ে records দেখুন। এটি attendance নেওয়ার ধাপ নয়। নিজের নাম না থাকলে Staff & access requests-এ existing identity/account link যাচাই করুন; নতুন duplicate person বানাবেন না।

## Security and verification

Read and write actions require an active verified context with `workforce.manage`. Reads are constrained to staff ID and one date and use authenticated RLS. The existing `workforce_command` retains actual-date/time, active Staff, overlap, uniqueness, request-id retry and audit enforcement. No service-role access or new migration is used.

`node scripts/check-daily-attendance.cjs` checks Bangladesh date/clock conversion, overnight handling, no-time statuses, invalid/future inputs, read/write permissions, direct-entry controls and clock payloads. The extended SQL fixture `supabase/tests/07_staff_attendance_security.sql` verifies bootstrap admin own attendance, another staff member, retries, corrections, hours and unauthorized access. These tests do not replace hosted browser acceptance.
