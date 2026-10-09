# সহজ একাডেমি: সহজ শিক্ষা কার্যক্রম পরিচালনা

## সিদ্ধান্ত ও সীমা

এই পরিবর্তন `feature/sohoj_final`-এর এক academy-এর বর্তমান architecture ব্যবহার করবে। School/Coaching/Training workspace separation যোগ করা হচ্ছে না। Public CRM-এর typography, design ও content contract পরিবর্তন হবে না। Teacher-এর actual class start/end, attendance, homework এবং independent admin review বহাল থাকবে।

## চারটি কাজ

১. প্রস্তুতি: সক্রিয় programme, subjects, batch, শিক্ষক ও যথেষ্ট আসনের room। Room creation-এ শুধু campus, name, seats, active। Teacher subject পরিচিতিতে তারিখ চাইবে না; default আজ থেকে, expiry নেই। অতীতের সীমিত assignment চাইলে advanced option থাকবে।
২. রুটিন: batch → বিষয়, শিক্ষক, room ও সময় → একাধিক দিন tick → সংক্ষিপ্ত preview → রুটিন চালু। প্রতি দিনের জন্য একই তথ্য আবার লিখতে হবে না। আলাদা সময় হলে নতুন class group যোগ করুন। Programme থেকে মেয়াদ আসবে; আজ default start, শেষের তারিখ optional advanced control।
৩. পাঠ পরিকল্পনা: বিষয়ভিত্তিক chapter/topic এবং লক্ষ্য তারিখ। Routine-এ optional teaching plan নির্বাচন করা যায়; generated sessions সেই plan-এর snapshot-এর সঙ্গে যুক্ত থাকে। Topic title শুধু recurring note; এটি তারিখভিত্তিক সম্পূর্ণ syllabus নয়। Routine plan না থাকলেও চলবে।
৪. দৈনিক কাজ: শিক্ষক আজকের ক্লাস খুলবেন → শুরু → student attendance → পরিকল্পিত/বাস্তব পাঠ → homework → শেষ → admin review। Approved actual সময়ই verified workload; cancelled ক্লাস workload নয়।

## Availability ও বন্ধ সময়

সাধারণ room/teacher availability হবে preferred hours—সতর্কবার্তা, admission/routine তৈরির বাধা নয়। Existing records মুছবে না। নির্দিষ্ট বন্ধ সময়/ছুটি `Holidays & unavailability`-তে থাকবে এবং actual class scheduling-এ enforced হবে। একই teacher/room/batch একই সময়ে booked থাকলে save আটকাবে। Inactive resources, campus mismatch, programme dates/subjects, room capacity এবং permissions বাধ্যতামূলক checks।

Availability record দেখানোর নাম হবে “Preferred hours”, effective dates advanced control। এটির বিকল্প closure record-এ শুরু/শেষ প্রয়োজন, কারণ তা বাস্তব সাময়িক বন্ধ। Availability বদলালে existing classes বাতিল হবে না।

## নতুন user-এর উদাহরণ

Morning A-এর English: Mufazzol, Room-01, ৭টা–৯টা, শনি থেকে বৃহস্পতি tick। একটি class group-এই ছয় দিনের routine। রবিবার দ্বিতীয় বিষয়ে ৯টা–১০টা হলে অন্য group যোগ করুন। Subject বদলালে teacher নির্বাচন থাকবে। কক্ষ নেই? একই page-এ কক্ষ তৈরি করে row-তে নির্বাচন করুন।

Preview-তে কত ক্লাস তৈরি হবে, কোন ছুটি বাদ যাবে এবং প্রকৃত conflict সংক্ষেপে দেখাবে। একই সমস্যা প্রতি তারিখে বারবার দেখাবে না। সম্পূর্ণ dated তালিকা collapsible। Preferred hours mismatch থাকলে warning দিয়ে admin save করতে পারবেন। Error হলে input থাকবে। অনিশ্চিত save-এ একই request retry; duplicate তৈরি হবে না।

প্রথম save-এ সর্বোচ্চ আগামী ২৮ দিনের ক্লাস তৈরি হবে। পরবর্তী ক্লাসের জন্য register-এ “আরও ক্লাস প্রস্তুত করুন”; system নিজেই পরবর্তী window নির্বাচন করবে। এটি background scheduler নয়। Calendar-এ date range দেখেই সংশ্লিষ্ট ক্লাস খুঁজবেন।

## Routine পরিবর্তন

Saved routine-এর “তারিখ থেকে পরিবর্তন” action দিয়ে teacher/room/time/subject/plan বদলানো যাবে। নতুন কার্যকর তারিখ আজ বা পরের দিন; ইতিমধ্যে শুরু বা report থাকা ক্লাস পরিবর্তন করা যাবে না। ভবিষ্যতের affected sessions controlled cancellation record রেখে replacement routine/classes তৈরি হবে। Past sessions ও attendance অক্ষত থাকবে। Entire replacement atomic, permission-checked ও audited। ব্যর্থ হলে আগের routine/classes অপরিবর্তিত থাকবে। একদিনের পরিবর্তন calendar-এর ওই session-এর action দিয়ে হবে।

## Interface ownership

Classrooms: physical room records। Preferred hours: optional working preference। Holidays & unavailability: real unavailable dates। Weekly routine: recurring subject classes। Teaching plans: chapters/topics। Class calendar: actual dated classes। Programme teaching dates-এর নাম স্পষ্ট হবে; একে topic plan বলা যাবে না। প্রতিটি page শুধু সংশ্লিষ্ট কাজ দেখাবে।

## বাস্তবায়নের ধাপ

১. এই সিদ্ধান্তের docs commit।
২. Availability advisory, plan linkage, atomic future replacement ও DB regression fixture commit।
৩. Multi-day class groups, compact preview, optional date controls, inline setup, routine edit এবং সংশোধিত বাংলা/ইংরেজি help commit।

Hosted database নিজে reset করা হবে না। নতুন unapplied migration db push করে install করতে হবে। পুরোনো applied migration সম্পাদনা নয়।
