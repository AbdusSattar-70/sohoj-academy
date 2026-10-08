# শিক্ষকের দৈনন্দিন ক্লাস পরিচালনা

Branch: `feature/sohoj_final`। Database migration: `56_guided_teacher_class_workspace.sql`।

## আগে Admin কী প্রস্তুত করবেন

১. Teacher-এর account যাচাই করে একই Staff পরিচয়ের সঙ্গে যুক্ত করবেন। Attendance record permission দেবেন; Teacher নিজের রিপোর্ট নিজে approve করতে পারবেন না।
২. Academic settings-এ বিষয় শেখানোর যোগ্যতা, Teacher ও classroom availability ঠিক করবেন।
৩. Programme, batch, ভর্তি ও enrollment প্রস্তুত করবেন। Classroom-এর আসন ও routine-এর সময় conflict যাচাই হবে।
৪. Weekly routine থেকে নির্দিষ্ট তারিখের session তৈরি করবেন। Teacher, বিষয়, batch, room এবং planned scope সঠিক থাকতে হবে।
৫. Curriculum-এ topic-এর target date থাকলে সংশ্লিষ্ট দিনের topic দেখাবে। শুধু scope দেওয়া থাকলে Teacher সেই scope নিশ্চিত করবেন; পুরো curriculum সম্পন্ন ধরে নেওয়া হবে না।
৬. পরীক্ষা থাকলে Tests & results-এ assessment তৈরি করে Publish করবেন। প্রকাশিত পরীক্ষা ছাড়া system পরীক্ষার reminder বানাবে না।

[শিক্ষা সেটিংস](/dashboard/academics/settings) · [Routine](/dashboard/academics/routine) · [Class calendar](/dashboard/academics/operations) · [Tests & results](/dashboard/academics/assessments)

## Teacher-এর কাজ: একটি class page-এ

[My classes](/dashboard/teacher) খুলে আজকের নির্ধারিত ক্লাসে **Open class** চাপুন।

### ১. ক্লাস শুরু

**হ্যাঁ — ক্লাস শুরু করুন** চাপলে server প্রকৃত সময় সংরক্ষণ করবে। কোনো “আমি শুরু করছি” বাক্য লিখতে হবে না। Refresh বা অন্য device-এ ফিরে এলে সংরক্ষিত সময় পাওয়া যাবে। নির্ধারিত দিনের আগে বা scheduled শুরুর সময়ের আগে Start করা যাবে না; schedule ভুল হলে Admin সংশোধন করবেন।

একজন Teacher-এর একই সময়ে দুইটি running class চলবে না। আগেরটি Finish করতে হবে। ক্লাস শুরু হওয়ার পরে schedule, শিক্ষক বা batch বদলে actual record-এর অর্থ পরিবর্তন করা যাবে না।

### ২. শিক্ষার্থীদের উপস্থিতি

Enrollment অনুযায়ী roster দেখাবে। প্রত্যেক শিক্ষার্থীর জন্য উপস্থিত, অনুপস্থিত, দেরিতে অথবা অনুমোদিত ছুটি নির্বাচন করে সংরক্ষণ করুন। কেউ স্বয়ংক্রিয়ভাবে উপস্থিত হবে না। উপস্থিত সবুজ, অনুপস্থিত লাল; অন্য status-এ নামসহ পৃথক চিহ্ন থাকবে।

Roster ফাঁকা থাকলে Admin batch/enrollment/date যাচাই করবেন। উপস্থিতি না নিয়ে final class report জমা দেওয়া যাবে না। সংরক্ষিত draft পরে সংশোধন করা যায়; submitted evidence Admin decision পর্যন্ত অপরিবর্তনীয়।

### ৩. আজকের পাঠ

আজকের target-date topic থাকলে **সম্পন্ন / আংশিক / পড়ানো হয়নি** নির্বাচন করুন। Scheduled scope অনুযায়ী বাস্তবে কী পড়িয়েছেন তা নিশ্চিত করুন। অসম্পূর্ণ হলে পূর্বনির্ধারিত কারণ নির্বাচন বা প্রয়োজনীয় ব্যাখ্যা লিখুন। অন্য দিনের সব chapter একসঙ্গে completed হয়ে যাবে না।

### ৪. বাড়ির কাজ এবং ক্লাস শেষ

বাড়ির কাজ নেই, অনুশীলনী, পড়ে আসবে অথবা বিবরণ/Google Docs link নির্বাচন করুন। প্রয়োজন হলে পরের ক্লাসের পরিকল্পনা লিখুন। **এখন ক্লাস শেষ করুন** প্রকৃত শেষ সময় সংরক্ষণ করবে। এই button রিপোর্ট অনুমোদন করবে না।

### ৫. যাচাই ও জমা

সময়, শিক্ষার্থীর উপস্থিতি, পাঠ ও homework যাচাই করুন। **রিপোর্টের খসড়া রাখুন** দিয়ে পরে কাজ চালাতে পারেন। **ক্লাস রিপোর্ট admin-এর কাছে জমা দিন** চাপলে attendance এবং actual teaching report একই database transaction-এ review-এর জন্য জমা হবে। একটি অংশ ব্যর্থ হলে অর্ধেক final submission থাকবে না।

Topics ও homework লিখে page ছাড়ার আগে সংরক্ষণ করুন। Start/End সময় database-এ থাকে; unsaved লেখা নিজে থেকে database-এ জমা হয় না। Browser navigation-এ unsaved/busy guard থাকে। Network-এর ফল অনিশ্চিত হলে **আগের অনুরোধ নিশ্চিত করুন** ব্যবহার করুন; নতুন করে একই কাজ পোস্ট করবেন না।

## সময়ের উদাহরণ

Physics ক্লাসে actual ৮:০৫–৮:৪৫ = ৪০ মিনিট। পরে Mathematics ১০:৩০–১১:১৫ = ৪৫ মিনিট। দুই session-এর মোট ৮৫ মিনিট; মাঝের ১ ঘণ্টা ৪৫ মিনিট teaching hours নয়। Staff দৈনিক উপস্থিতি, actual teaching time এবং student attendance তিনটি আলাদা record।

Clock capture শুধু evidence। Admin actual teaching ও student attendance approve করার আগে verified workload বা পারিশ্রমিক চূড়ান্ত হবে না। Fixed salary-এর নিয়ম আলাদা।

## ভুলে Start/Finish চাপা না হলে

সংরক্ষিত clock থাকলে **সময় সংশোধন প্রয়োজন?** খুলে session-এর তারিখে প্রকৃত start/end ও কারণ দিন। ভবিষ্যতের সময়, শেষের আগে শুরু বা অন্য ক্লাসের সঙ্গে overlapping সময় গ্রহণ হবে না। Submitted/approved সময় সরাসরি rewrite হবে না; review-এর পরে correction report ব্যবহার করুন।

পুরোনো session-এ আগে teaching report তৈরি থাকলে দ্বিতীয় clock শুরু হবে না। Existing report এবং attendance-এর recovery controls দিয়ে কাজ চালানো যাবে।

## আগামী পরীক্ষা ও প্রশ্ন প্রস্তুতি

Dashboard এবং class page-এ আগামী ৭ দিনের assigned class ও published exam reminder থাকবে; একটি response-এ সর্বোচ্চ ২৫টি reminder। একটির details খুলে topic, প্রয়োজনে পৃষ্ঠা এবং নিজের Google Docs প্রশ্ন–উত্তরের link দিন। Admin যেন document পড়তে পারেন সেই sharing permission নিশ্চিত করুন।

প্রথমে draft Save, তারপর **প্রশ্ন admin review-এর জন্য জমা দিন**। Draft, যাচাই বাকি, সংশোধন প্রয়োজন এবং চূড়ান্ত অবস্থা দেখাবে। ফিরে এলে সংশোধনের নির্দেশনা একই জায়গায় পাবেন।

পরীক্ষার document নির্দিষ্ট assessment ID-এর সঙ্গে যুক্ত থাকবে। সাধারণ class document জমা দিলেই পরীক্ষার প্রস্তুতি সম্পন্ন হবে না। Exam reminder একই batch/subject-এর নিজের সর্বশেষ assigned class-এর context ব্যবহার করে; প্রশ্নে পরীক্ষার scope নিশ্চিত করুন। Scheduled class নেই এমন assessment-এর জন্য Admin আগে Teacher-এর class assignment প্রস্তুত করবেন। Google Docs-এর content app নিজে পড়বে/কপি করবে না; Admin existing review workflow-এ academy-owned final প্রশ্ন ও আলাদা answer key-এর link সংরক্ষণ করবেন।

## Admin-এর review

Class page-এর **যাচাই, উপস্থিতির ইতিহাস ও বাড়ির কাজের follow-up** অংশে submitted student attendance ও teaching evidence দেখুন। দুইটি আলাদাভাবে যাচাই/approve করুন; Teacher নিজে approve করবেন না। Reject করলে কারণ দিন, যাতে Teacher correction report জমা দিতে পারেন। আগের approved evidence ইতিহাসে থাকবে।

[প্রশ্ন যাচাই](/dashboard/academics/questions) · [Progress reports](/dashboard/academics/progress)

## বাস্তব যাচাইয়ের সীমা

Database fixture clock persistence, duplicate-request safety, date guard, attendance prerequisite, combined submission, exam linkage এবং permission checks যাচাই করে। Component render checks ও production build আলাদাভাবে চালানো হয়। Hosted Supabase/browser/email acceptance এই isolated tests দিয়ে দাবি করা হয় না।
