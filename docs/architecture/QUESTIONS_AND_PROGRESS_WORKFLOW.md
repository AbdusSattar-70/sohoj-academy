# Routine-based questions and student progress reports

Teachers prepare questions from their own scheduled class, without administrator task assignments. The scheduled session supplies batch, subject, teacher and planned curriculum. They select a planned topic or enter a chapter/topic/page reference, save a Google Docs link as Draft, then submit. The administrator returns it with a correction note or records separate academy-owned final question and answer-key links and finalizes. Documents are not fetched, copied or shared automatically; admin must verify academy ownership and restricted Drive sharing. Final records are immutable. Corrections create another submission; old question-generator records are retained as history and its authoring RPC is disabled.

Progress reports select student, batch and date range. Attendance uses the latest approved revision per session. Assessment results use the latest approved revision per assessment; drafts, pending reviews and missing marks are never converted into zero. Topic coverage uses approved teaching logs; homework submission is reported separately from assessment marks. Preview/draft snapshots retain source identities and preparation time. Teachers can generate and submit only for batches they teach; admin reviews, refreshes approved evidence and finalizes. Final reports are immutable and printable in black and white on letterhead with a reserved header. A new report is needed for later corrected evidence; no silent overwrite.

Periods are bounded to 93 inclusive days; list pages hold 25 records. Authors can edit their Draft/Returned submission, submit for review and see feedback. Reviewers can return teacher submissions or finalize, with server and database permission checks. A teacher cannot finalize their own work. Authorized admin can generate/finalize a progress report directly. Academic evidence is independent of teaching-hour/fee posting.

## বাংলা পরিচালনা

শিক্ষক: আজকের/আসন্ন ক্লাস খুলে “প্রশ্ন প্রস্তুতি” নির্বাচন → অধ্যায়/টপিক অথবা পৃষ্ঠা দিন → Google Docs-এ প্রশ্ন ও উত্তর তৈরি করুন → Draft সংরক্ষণ → Review-এর জন্য জমা দিন। আলাদা কাজ assign করতে হবে না। Admin সংশোধনের মন্তব্য দিলে একই submission-এ সংশোধিত link সংরক্ষণ করে আবার জমা দিন। Final হলে নতুন correction submission তৈরি করবেন।

Admin: Questions পেজে Submitted filter → document খুলে যাচাই → প্রয়োজন হলে Return → academy-owned Drive-এ question ও answer key আলাদা final copy রাখুন → restricted sharing/academy copy নিশ্চিত করে Final করুন। ERP-এর access ও Google Drive-এর sharing আলাদা; ERP role দিয়ে Drive document private হয় না।

Progress reports: ব্যাচ ও শিক্ষার্থী নির্বাচন → সপ্তাহ/মাসের শুরু/শেষ দিন → Preview তৈরি → approved attendance, marks ও পাঠের অগ্রগতি দেখুন → শিক্ষক মন্তব্য/বাড়ির সহায়তার tick দিন → submit। Admin approved evidence আবার দেখে Final করুন → Print। অনুপস্থিত result মানে “এখনো অনুমোদিত ফল নেই”; শূন্য নয়। শতাংশ কেবল পাওয়া অনুমোদিত নম্বরের অনুপাতে; পরীক্ষার নির্ধারিত denominator বদলে বানানো grade দেওয়া হবে না। Attendance, topic coverage এবং পরীক্ষার score আলাদা দেখাবে। Letterhead-এ প্রিন্টের আগে browser header/footer বন্ধ করুন।

## Deployment and verification

Apply `54_routine_google_docs_questions.sql` then `55_student_progress_reports.sql` with `pnpm exec supabase db push`. No reset, email provider or Google API credential is required. Google Docs access must be shared with the reviewer manually. Teacher must have an active linked staff identity and scheduled session. Curriculum topics are optional; free chapter/page references remain available. Report student choices are searched in the selected assigned batch, 50 per page; report registers use 25 rows.

The isolated SQL fixture `37_question_documents_progress_reports.sql` covers teacher submission/return/final review, exact-request retries, missing-result handling, approved evidence, own-review rejection, immutable finals and RPC/write grants. Local type/lint/build checks do not replace live Supabase/Drive/browser acceptance.
