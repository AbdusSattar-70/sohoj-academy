# সাপ্তাহিক রুটিন: operator-এর নির্দেশিকা

বিস্তারিত সিদ্ধান্ত: [সহজ শিক্ষা কার্যক্রম পরিচালনা](ACADEMIC_OPERATION_REDESIGN_BN.md)। এটি একটি academy-এর workflow; আলাদা School/Coaching/Training workspace তৈরি করা হয়নি।

## আগে প্রস্তুত করুন

সক্রিয় programme offering → subjects ও standard fees → batch → সক্রিয় শিক্ষক → যথেষ্ট আসনের classroom। Room তৈরি করতে শুধু নাম, campus ও seats দিন। Teacher subject assignment-এ সাধারণভাবে তারিখ লিখতে হবে না। Preferred hours ঐচ্ছিক; পুরোনো availability record থাকলেও সেগুলো routine save আটকাবে না। বাস্তব বন্ধ দিন `Holidays & unavailability` দিয়ে রাখুন।

## রুটিন চালু করুন

১. [সাপ্তাহিক রুটিন](/dashboard/academics/routine) → **সাপ্তাহিক রুটিন তৈরি করুন**।
২. Batch নির্বাচন করুন। আজ default শুরু; programme ভবিষ্যতে শুরু হলে সেই তারিখ আসবে। শেষ তারিখ programme থেকে আসে; বদলাতে চাইলে optional শেষ তারিখ খুলুন।
৩. বিষয়, শিক্ষক, room ও শুরু–শেষ সময় দিন। একই ক্লাসের সব দিন tick করুন। English শনিবার–বৃহস্পতিবার ৭টা–৯টা হলে একটি row-তেই ছয় দিন। অন্য বিষয়/শিক্ষক/সময় হলে নতুন row যোগ করুন। প্রতি সপ্তাহে সর্বোচ্চ ৪০টি day/class entry। কোনো row-তে দিন নির্বাচন না করলে স্পষ্ট নির্দেশনা আসবে।
৪. প্রয়োজনীয় room না থাকলে এখানেই তৈরি করুন। Topic note ঐচ্ছিক। তারিখভিত্তিক অধ্যায়/topic চাইলে ওই row-এর **পাঠ ও পরিকল্পনা** খুলে existing teaching plan নির্বাচন অথবা এখানেই তৈরি করুন। নতুন plan-এর জন্য প্রতিটি topic-এর intended class date দিন। Save করলে plan ওই row-তে নির্বাচিত হবে।
৫. Preview করুন। মোট কত ক্লাস তৈরি হবে এবং প্রকৃত conflict দেখাবে। Preferred hours-এর বাইরে হলে একটি সংক্ষিপ্ত notice দেখাবে—save করতে পারবেন। পূর্ণ date তালিকা দেখতে details খুলুন। ছুটি/বন্ধ দিন ও পেরিয়ে যাওয়া সময় বাদ যাবে।
৬. **রুটিন চালু করুন**। একবারেই normalized weekly routines ও প্রথম সর্বোচ্চ ২৮ দিনের ক্লাস তৈরি হবে। কোনো অংশ ব্যর্থ হলে পুরো কাজ rollback হবে; input থাকবে। ফল অনিশ্চিত হলে একই request confirm করুন, তথ্য বদলাবেন না।
৭. [ক্লাস ক্যালেন্ডার](/dashboard/academics/operations) খুলে সংশ্লিষ্ট date range নির্বাচন করুন। শিক্ষক নির্দিষ্ট দিনের ক্লাস খুলে শুরু, attendance, planned/actual teaching, homework, finish ও admin review-তে submission করবেন।

## Routine পরিবর্তন

Register-এর একটি দিনের row-তে **তারিখ থেকে পরিবর্তন** চাপুন। এটি ওই দিনের recurring class-এর পরিবর্তন; অন্য দিনের row নিজে থেকে বদলাবে না। নতুন start date ও প্রয়োজনীয় teacher/room/time/topic plan দিন, preview করে চালু করুন। ঐ তারিখ থেকে untouched future classes cancellation record রেখে replacement হবে; past classes অক্ষত থাকবে। ইতিমধ্যে শুরু/attendance/report থাকা ক্লাসে পরিবর্তন আটকাবে—পরবর্তী কার্যকর তারিখ বাছুন। ব্যর্থ হলে পুরোনো routine এবং future bookings বহাল থাকবে।

একটি মাত্র দিনের substitute/reschedule/cancel/makeup [ক্লাস ক্যালেন্ডার](/dashboard/academics/operations)-এর ওই class থেকে করুন। Register-এর **আরও ক্লাস প্রস্তুত করুন** পরবর্তী bounded period নিজে নির্বাচন করে; আলাদা date range লিখতে হয় না। এটি background automatic scheduler নয়।

## কী বাধ্যতামূলক

Booking conflict, active identity, correct campus, programme subject/date, room capacity, real closures এবং scheduling permission। Preferred hours ও subject qualification advisory। Teaching plan ছাড়া routine চলবে, কিন্তু teacher-এর কাছে তারিখভিত্তিক topics আসবে না। একই recurring note প্রতিদিন আসতে পারে; সেটি পূর্ণ dated topic plan নয়। Completed class-এর plan snapshot বদলাবে না; নতুন classes-এর জন্য নতুন plan নির্বাচন করুন।

Migration 61 প্রযোজ্য। Applied migration edit বা database reset দরকার নেই; genuinely unapplied migration `db push` দিয়ে install করুন।
