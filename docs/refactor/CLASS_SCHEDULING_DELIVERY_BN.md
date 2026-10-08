# ক্লাস পরিচালনা: বাস্তবায়ন ও ব্যবহার

## নির্ধারিত কাঠামো

কী শেখাবেন → কাদের শেখাবেন → কখন, কোথায় ও কে শেখাবেন → বাস্তবে কী হয়েছে। Programme offering, batch, resource availability, routine, dated session এবং teacher report পৃথক records। School ও Coaching-এ class/year ব্যবহার করবেন; Training-এ প্রয়োজন না হলে এগুলো বাধ্যতামূলক নয়। Website প্রকাশ, ভর্তি গ্রহণ এবং routine readiness আলাদা থাকবে। CRM-এর design পরিবর্তন হবে না।

## এই কাজের ধাপ ও commit

১. Scheduling diagnostic preview: তারিখ, weekday, শিক্ষক, room, availability, qualification, capacity, holiday এবং booking conflict-এর নির্দিষ্ট কারণ দেখানো। পাশাপাশি পরপর যুক্ত availability windows থাকলে সেগুলো সম্পূর্ণ সময় cover করছে কি না যাচাই। Preview read-only; Save-এ আবার একই যাচাই হবে।
২. Routine ও Calendar: সাপ্তাহিক পরিকল্পনার তালিকা, আগামী bounded date range-এ ক্লাস তৈরি, ভবিষ্যৎ পরিকল্পনা বন্ধ; ইতোমধ্যে অনুষ্ঠিত ক্লাস অপরিবর্তিত। Calendar-এ teacher নিজের ক্লাস, manager academy-এর ক্লাস দেখবেন।
৩. Programme ও Batch পরিকল্পনা: default দিন ও দিনভিত্তিক সময় আলাদাভাবে সংরক্ষণ; এগুলো booking নয়। বাস্তব subject/teacher/room slot Routine-এ নির্ধারণ হবে।
৪. Session কাজ: enrollment থেকে attendance roster, homework/assessment note, actual সময়, teacher submission এবং স্বাধীন admin review। Approved actual teaching hours আলাদা summary; salary বা staff উপস্থিতির সঙ্গে এক করা হবে না।
৫. Admission integration: batch seat/enrollment contract থেকে dated roster; transfer বা closure-এর পরে পুরোনো attendance অক্ষত। সম্পূর্ণ admission/invoice workflow এই academic কাজের নামে নতুন করে দ্বিতীয় মডেল বানানো হবে না; বর্তমান branch-এর admission delivery status আলাদাভাবে লিখতে হবে।

## প্রাথমিক প্রস্তুতি

[Academic settings](/dashboard/academics/settings) থেকে subjects/years যাচাই করুন। [Programme offerings](/dashboard/academics/programmes) → [Fees](/dashboard/academics/fees) → [Batches](/dashboard/academics/batches)। [Classrooms](/dashboard/academics/settings?section=rooms) এবং [Teacher qualifications](/dashboard/academics/settings?section=teachers) প্রস্তুত করুন। [Availability](/dashboard/academics/settings?section=availability)-তে সঠিক teacher/room, weekday, বাংলাদেশ সময় ও Active status দিন।

Availability থাকলেই যেকোনো সময় ক্লাস নেওয়া যাবে না: নির্বাচিত teacher, নির্দিষ্ট weekday এবং ক্লাসের সম্পূর্ণ সময় cover করতে হবে। Sunday-এর window Tuesday-এর ক্লাস cover করে না। Room-এর window teacher-এর window নয়। ৭–৮ ও ৮–৯-এর দুটি active window যুক্ত হলে ৭–৯ cover করতে পারবে; মাঝখানে gap থাকলে পারবে না।

## ক্লাস তৈরি

[Class operation](/dashboard/academics/sessions) খুলে Single অথবা Weekly classes নির্বাচন করুন। Batch → Subject → qualified Teacher → Room নির্বাচন করুন। Weekly-এর জন্য সর্বোচ্চ ৩২ দিনের interval ও weekday দিন। সময় বাংলাদেশ সময়। Preview/check ফলাফলে প্রতিটি বাধার date/time এবং resource দেখবেন। অন্য resource/time দিন বা সংশ্লিষ্ট setup নতুন tab-এ খুলুন; মূল form-এর তথ্য থাকবে।

Teacher ও room-এর availability সত্যিই নিশ্চিত হলে explicit checkbox দিয়ে অনুপস্থিত weekly windows একই transaction-এ যোগ করতে পারবেন। এটি conflict, holiday, qualification বা resource block অগ্রাহ্য করে না। Save ব্যর্থ হলে নতুন windows-ও rollback হবে। ভুল হলে form বন্ধ হবে না, সফল হলে বন্ধ হয়ে list refresh হবে। অনিশ্চিত network result হলে আগের request নিশ্চিত করতে হবে।

## প্রতিদিন

Calendar/আজকের ক্লাস → session work → প্রতিটি শিক্ষার্থীর উপস্থিতি → কী শেখানো হয়েছে, homework/assessment এবং actual start/end → submit। Teacher নিজের assigned session-ই দেখবেন ও submit করবেন। Admin submitted record খুলে attendance ও actual কাজ দেখবেন; approve অথবা reason দিয়ে return করবেন। Teacher নিজের report approve করতে পারবেন না। Approved কাজ সরাসরি edit করা যাবে না।

## ব্যতিক্রম

Teacher বদল, room বদল ও reschedule একটি session-এর action। Cancelled session-এর linked makeup আলাদা dated session হবে। Cancelled বা unapproved কাজ approved teaching-hours summary-তে যাবে না। Holiday routine generation থেকে বাদ যাবে। Routine বন্ধ করা ইতোমধ্যে generated session cancel করার সমতুল্য নয়—সেগুলো পৃথকভাবে cancel/reschedule করতে হবে। Notification queue এবং provider acceptance আলাদা; queue-তে থাকা মানে email delivered নয়।

## নিরাপত্তা ও history

সব mutation verified account, academy scope, permission, request identity, revision ও audit-এর মাধ্যমে। Client preview নিরাপত্তা boundary নয়। Database Save-এ আবার resource ও conflict যাচাই হবে এবং concurrent scheduling serialize হবে। History delete নয়। Attendance date-এ কার্যকর enrollment roster ব্যবহৃত হবে; transfer ভবিষ্যৎ placement বদলাবে, আগের attendance নয়।

## সম্পন্ন কাজ এবং operator-এর সরাসরি পথ

- **Programme offerings → Teaching days**: default weekday tick দিন; দিন/সপ্তাহ system হিসাব করবে। এটি routine নয়।
- **Batches → Manage batches → Days & time**: offering-এর দিন প্রস্তাব হিসেবে আসবে। একই সময় অথবা দিনভেদে আলাদা সময় দিন। তালিকায় সময় এবং occupied/capacity দেখা যাবে।
- **Weekly availability**: Teacher/Room নির্বাচন, প্রযোজ্য দিন tick, বাংলাদেশ সময় দিন। Edit-এ weekday/time/status বদলানো যাবে। সংলগ্ন windows একসঙ্গে cover করবে; gap cover করবে না। তৈরি ভবিষ্যৎ class-এর coverage সরিয়ে ফেলা যাবে না।
- **Weekly routine**: এক subject slot তৈরি করুন। উদাহরণ: Physics রবি ৭–৮; Mathematics রবি ৮–৯ আলাদা routine row। একই batch-এর adjacent slots চলবে; overlapping slots চলবে না। Batch-এর default দিন/সময় form-এ প্রস্তাব হবে; subject slot অনুযায়ী বদলাবেন। **Next period** দিয়ে পরের bounded সময় তৈরি করুন। **Edit future classes** দিয়ে ভবিষ্যৎ তারিখ থেকে teacher/room/weekday/time বদলান। Checkbox-এ cancellation/replacement নিশ্চিত করতে হবে; ব্যর্থ হলে পুরোনো ক্লাসই থাকবে। **Stop** শুধু আরও generation বন্ধ করে—পুরোনো generated sessions নিজে থেকে বাতিল করে না।
- **Class calendar**: Today/Next 7/Next 30 days অথবা নিজস্ব তারিখসীমা। Status filter ও pagination থাকবে। বন্ধের দিন দেখা যাবে। **Open class** দিয়ে সেই class-এর কাজ খুলুন।
- **Class operation**: single class, পরিবর্তন, substitute, room change, reschedule, cancel এবং cancelled class-এর linked makeup। Manager submitted কাজ আগে দেখবেন।
- **Class → Attendance & class work**: teacher নিজের assigned class-এ form খুলবেন। All present দিয়ে শুরু করে ব্যতিক্রম বদলাতে পারেন। প্রত্যেক enrolled student-এর attendance, optional note, teaching report, homework/due date এবং assessment type/note দিন। **Draft** অথবা **Submit for admin review** নির্বাচন করে Save করুন। Actual সময় নিজে নিশ্চিত করে দিন—planned সময় স্বয়ংক্রিয়ভাবে actual ধরে নেওয়া হবে না। ভবিষ্যৎ দিনের attendance বা ভবিষ্যৎ actual end গ্রহণ হবে না।
- **Admin → Open class**: attendance ও রিপোর্ট দেখে Approve/Return। Correction reason teacher-এর class-এ দেখাবে। Returned report শিক্ষক নিজের dashboard-এ পাবেন। Approved report আর edit হবে না। এক শিক্ষক একই actual সময়ে দুটি approved teaching record রাখতে পারবেন না।
- **Teaching hours**: মাসের শুরু থেকে আজ default range। কেবল APPROVED actual সময়; cancelled/draft/submitted কাজ বাদ। এক ঘণ্টা ত্রিশ মিনিট → ১.৫ ঘণ্টা। এটি salary statement নয়।
- **Batch → Students / transfer**: আগে তৈরি active Student identity-কে তারিখসহ batch-এ দিন। একই offering-এর অন্য batch-এ transfer করুন অথবা enrollment close করুন। Effective date-এর আগের roster/attendance থাকবে। Close date থেকে roster-এ থাকবে না। Transfer/close ভবিষ্যৎ দিন দিয়ে এখনই seat খালি করা যাবে না—কার্যকর দিনে করুন। নতুন student identity ভর্তি workflow থেকেই তৈরি হবে; এই পাতায় দ্বিতীয় generic person-create নেই।

## বর্তমান সীমা—অসম্পূর্ণ কাজকে সম্পন্ন বলা যাবে না

এই branch-এ সম্পূর্ণ নতুন-student admission desk, invoice/payment/receipt, grading/question bank এবং salary calculation এখনও আলাদা implementation কাজ। Dated enrollment, batch-seat capacity ও attendance integration-এর controlled RPC এখন প্রস্তুত; ভবিষ্যৎ admission confirmation একই contract reuse করবে। Homework/assessment এখানে session note/type/due date; পূর্ণ assignment submission, question generation বা marks register নয়। Staff উপস্থিতির আলাদা register এখানে তৈরি হয়নি। Website design অপরিবর্তিত।

Schedule পরিবর্তনের email-এর transactional queue আগে থেকেই আছে। Queue হওয়া মানে inbox delivery নয়। Provider configuration ও `/api/internal/academic-notifications` worker schedule প্রয়োজন; Auth account-setup email configuration ক্লাসের email worker-এর বিকল্প নয়। এই কাজ করতে গিয়ে live invitation বা email পাঠানো হয়নি।

Existing batch seats-এ enrollment date আগে ছিল না: নতুন migration historical roster backfill-এ offering-এর start date ব্যবহার করে। নতুন placement-এ explicit effective date থাকবে। Backfill-এ অনুমান করা তারিখ staff যাচাই করবেন; পুরোনো attendance বা payment history এই branch-এ fabrication করা হয়নি।

## ভুল availability message দেখলে

একই নামের শিক্ষক হলে `SA-STF-…` ID মিলিয়ে দেখুন। Window এবং class একই স্থায়ী teacher record-এর হতে হবে; নাম মিললেই এক ব্যক্তি ধরে নেওয়া হবে না।

নতুন branch pull এবং migration push-এর পর **Check dates & availability** বোতাম থাকবে। না থাকলে পুরোনো build চলছে: dev server বন্ধ করে পুনরায় চালু করুন। Check ফলাফলে নাম, date/time এবং সেই weekday-এর active windows দেখবেন। Teacher এবং Room-এর windows পৃথক। নির্বাচিত teacher-এর অন্য দিনের availability এই দিনের class cover করবে না। প্রয়োজন হলে ওই resource-এর window Edit করুন অথবা নিশ্চিত availability checkbox ব্যবহার করুন।

## যাচাই

Production build/TypeScript, targeted lint এবং isolated SQL lifecycle checks চালানো হয়েছে: adjacent windows, gap/inactive/wrong weekday rejection, overlap/capacity/block guards, teacher-only roster, complete attendance before submission, no teacher self-approval, retry without duplicate, approved actual hours, dated transfer history, holiday skipping, routine continuation, failed replacement rollback এবং future replacement without changing approved history। Hosted database push, browser visual acceptance এবং live email delivery করা হয়নি।


Scheduling form-এর উপরে **Missing classroom? Create here** দিয়ে নতুন room তৈরি ও নির্বাচন করতে পারবেন। মূল scheduling input থাকবে। Teacher identity account-request verification থেকেই আসে; generic teacher-create দিয়ে duplicate ব্যক্তি হবে না। নতুন শিক্ষক হলে access request verify এবং subject qualification প্রস্তুত করতে হবে।
