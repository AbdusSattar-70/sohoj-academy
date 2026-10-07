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
