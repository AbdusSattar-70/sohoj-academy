# শিক্ষা পরিচালনা ও ক্লাস পরিবর্তনের নির্দেশিকা

## মূল সিদ্ধান্ত
একটি Academics প্রবেশপথের মধ্যে কাজভিত্তিক তালিকা থাকবে। স্কুল, কোচিং ও প্রশিক্ষণের প্রোগ্রাম আলাদা operational context-এ চলবে। CRM-এর নকশা পরিবর্তন হবে না। শিক্ষার্থী বা অভিভাবকের account প্রয়োজন নেই। ব্যবহৃত তথ্য মুছে নয়, inactive করে রাখা হবে। Admin সরাসরি পরিচালনা করবেন; teacher-এর কাজ admin যাচাই করবেন।

[সহজ navigation ও প্রয়োজনমতো loading নির্দেশিকা](ACADEMIC_NAVIGATION_AND_LOADING_BN.md) অনুযায়ী Settings, Programmes ও Class operation আলাদা পাতায় কাজ করুন।

## প্রথমে কী প্রস্তুত করবেন
১. শিক্ষাবর্ষ, class/group, বিষয় ও programme নাম যাচাই করুন। পরিচিত seed তথ্য edit করা যায়। প্রয়োজনীয় school/area/subject তালিকায় না থাকলে একই কাজের মধ্যে তৈরি করে নির্বাচন করার ব্যবস্থা অনুসরণ করুন।
২. programme-এর বছর, campus, class অথবা training context এবং শুরু/শেষের তারিখ নির্ধারণ করুন। Website প্রকাশ ও আবেদন গ্রহণ আলাদা সিদ্ধান্ত।
৩. standard fee ও অনুমোদিত discount নির্ধারণ করুন; তারপর batch ও আসন সংখ্যা তৈরি করুন।
৪. classroom-এর নাম, আসন সংখ্যা ও ব্যবহারযোগ্য সময় লিখুন। Teacher-এর বিষয় যোগ্যতা ও available সময় নিশ্চিত করুন।
৫. batch-এর দিন ও সময় থেকে routine তৈরি করুন। রবিবার/মঙ্গলবার/বৃহস্পতিবার নির্বাচন করলে সপ্তাহে তিন দিন স্বয়ংক্রিয়ভাবে বোঝা যাবে; আলাদা করে তিন লিখতে হবে না। একই teacher, room বা batch যেন একই সময়ে দুই জায়গায় না থাকে।
৬. ছুটি ও বন্ধের দিন বাদ দিয়ে নির্দিষ্ট তারিখের session তৈরি করুন। সব সময় বাংলাদেশ সময়; database-এ সময় timezone-সহ থাকবে।

## Routine ও session-এর পার্থক্য
Routine হচ্ছে পুনরাবৃত্ত পরিকল্পনা, যেমন প্রতি রবিবার সকাল ৭–৯টা। Session হচ্ছে ১১ অক্টোবর সকাল ৭–৯টার বাস্তব ক্লাস। এক দিনের পরিবর্তন শুধু session-এ হবে। সম্পন্ন ক্লাসের ইতিহাস routine edit করে বদলানো যাবে না। শিক্ষা সেটিংসের সাপ্তাহিক সময় অংশে room ও teacher-এর weekday এবং সময় নির্ধারণ করুন। শিক্ষা সেটিংসের ছুটি অংশে বন্ধের দিন দিন। Create weekly classes-এ দিনগুলো tick করে সর্বোচ্চ ৩২ দিনের routine তৈরি করুন। বন্ধের দিন বাদ যাবে; কোনো দিনের conflict থাকলে পুরো routine save বন্ধ থাকবে। সংশোধন করে আবার দিন। নতুন routine দিয়ে ইতোমধ্যে তৈরি class overwrite হবে না।

## Session desk
[ক্লাস পরিচালনা খুলুন](/dashboard/academics/sessions)। Admin room তৈরি/সম্পাদনা/inactive করবেন, batch, বিষয়, teacher, room ও সময় নির্বাচন করে session তৈরি করবেন। Capacity ও overlapping session database যাচাই করবে। পাশাপাশি অন্য window-তে save হলেও একই resource double booking হবে না। পরিবর্তনে revision মিলিয়ে পুরোনো screen থেকে নতুন তথ্য overwrite বন্ধ থাকবে।

Teacher নিজের session দেখবেন। ক্লাসের actual শুরু/শেষ, শেখানো বিষয় ও উপস্থিতি জমা দেবেন। Admin যাচাই করে approve অথবা কারণসহ return করবেন। Approved actual সময় workload; পরিকল্পিত বা cancelled সময় স্বয়ংক্রিয়ভাবে salary নয়। Enrollment ইতিহাস ও attendance roster snapshot পরবর্তী admission integration-এর অংশ। বর্তমান desk session report যাচাই করে, student attendance চালু হয়েছে বলে ধরে নেওয়া যাবে না।

## ক্লাস পরিবর্তন
| পরিস্থিতি | কাজ | বার্তা |
|---|---|---|
| Teacher অনুপস্থিত | Substitute নির্বাচন; পুরোনো ও নতুন teacher সংঘর্ষ পরীক্ষা | সংশ্লিষ্ট teacher ও নির্বাচিত notification contacts |
| Room অচল | অন্য active room নির্বাচন; capacity পরীক্ষা | নতুন room ও সময় |
| সময় পিছিয়ে দেওয়া | নতুন তারিখ/সময় দিয়ে reschedule | পুরোনো ও নতুন সময় |
| ক্লাস হয়নি | কারণ বেছে cancel | cancellation এবং পরে যোগাযোগের নির্দেশ |
| অতিরিক্ত class | cancelled মূল session থেকে linked makeup তৈরি | মূল class-এর reference ও নতুন সময় |

সব পরিবর্তনে কারণ, কে করেছেন এবং আগের/পরের তথ্য audit-এ থাকে। Cancelled session মুছবেন না। Approved report পরিবর্তন করা যাবে না। বন্ধ room inactive করলে তার ভবিষ্যৎ session আগে অন্য room-এ নিতে হবে।

## Email notification
Email account invitation বা password email থেকে আলাদা। প্রতিটি class change একই database transaction-এ notification queue তৈরি করে। সংশ্লিষ্ট teacher-এর email এবং ওই batch-এর সম্মতি দেওয়া notification contacts-কে আলাদা email যায়; কেউ অন্য অভিভাবকের email দেখতে পান না। School-age শিক্ষার্থীর জন্য guardian contact ব্যবহার করুন। Email না থাকা admission-এর বাধা নয়। Mobile/address/fee তথ্য class-change email-এ যাবে না।

Admin batch contact হিসেবে verified email ও notification সম্মতি যোগ করবেন। Contact inactive করলে নতুন message যাবে না। একই event-এ একই email একবার queue হয়। Pending/failed queue শিক্ষা সেটিংসের ইমেইল পাঠানোর অবস্থা অংশে দেখা যায়। ভুল address, consent বা provider configuration ঠিক করে আবার পাঠানোর ব্যবস্থা করতে হবে; save সফল মানেই email delivered নয়। Provider accepted status inbox delivery নিশ্চিত করে না।

Server-এ `RESEND_API_KEY`, verified sender `ACADEMIC_EMAIL_FROM`, এবং দীর্ঘ random `ACADEMIC_NOTIFICATION_SECRET` দিন। Scheduler প্রতি মিনিটে `POST /api/internal/academic-notifications`-এ `Authorization: Bearer <secret>` পাঠাবে। Supabase server-only service key প্রয়োজন; public environment variable-এ রাখবেন না। Browser বা teacher worker চালাতে পারবেন না। Provider idempotency key একটি notification-এর ID; ambiguous failure-এ retry একই key ব্যবহার করবে। Queue claim lease ও attempts থাকবে। ২৪ ঘণ্টার বাইরে uncertain delivery স্বয়ংক্রিয় retry নয়; admin তদন্ত করবেন। এই repository কোনো বাস্তব recipient-কে testing email পাঠায় না।

## ব্যবহারিক উদাহরণ
Morning A, ১২ জনের batch; রবিবার ৭–৯টা Biology, teacher রহিম, room ১। রহিম অসুস্থ: session খুলে substitute teacher করিম নির্বাচন করুন। করিমের ওই সময় আরেক class থাকলে save হবে না। Room ২-এ ১০টি আসন হলে ১২ আসনের batch রাখা যাবে না। Guardian notification contact যুক্ত থাকলে পরিবর্তন queue হয়। পরে class cancel করলে সেটির সঙ্গে নতুন makeup যুক্ত করুন। Teacher report জমা দিলে admin যাচাই করবেন।

## পরবর্তী পৃথক কাজ
- ভবিষ্যৎ routine deactivate/edit করে কেবল অপরিবর্তিত planned session বদলানোর ব্যবস্থা।
- Dated enrollment/transfer history থেকে student attendance roster ও attendance correction।
- এক পাতায় admission, fee/payment ও receipt; notification contacts guardian সম্পর্ক থেকে সম্মতি অনুযায়ী নেওয়া।
- Reminder, দৈনিক teacher agenda এবং returned report notification।
এগুলো বর্তমান branch-এর session-change email ভিত্তির পরবর্তী কাজ; financial accounting বা প্রশ্নব্যাংক এখানে নতুন করে তৈরি করা হচ্ছে না।

## বর্তমানে সম্পন্ন ও সীমা
Room create/edit/inactive, teacher/room weekly availability, holiday/reopen, weekday নির্বাচন থেকে bounded routine generation, date-specific session changes, linked makeup, teacher report ও admin review, guardian email consent/contact inactive এবং transactional email queue সম্পন্ন। Teacher qualification editor ও temporary blockout সম্পন্ন। Student attendance roster ও routine edit/deactivate এখনো সম্পন্ন নয়। এগুলোর জন্য বিদ্যমান class ইতিহাস বদলানো যাবে না। Settings-এর বিষয়, শিক্ষাবর্ষ, স্কুল/কলেজ ও অন্যান্য তালিকা আলাদাভাবে খুলে সম্পাদনা করুন। Class seed-এর জন্য নতুন editable class register পৃথক ভবিষ্যৎ কাজ।

## Local চালু করা
```bash
git fetch origin
git switch feature/academic_operations
git pull --ff-only
pnpm install
pnpm exec supabase db push
pnpm dev
```
Reset প্রয়োজন নেই যদি আগের branch-এর 01–11 migrations ইতোমধ্যে আছে। অন্য schema/migration history থাকলে আগে docs/SETUP.md অনুসরণ করুন; migration repair দিয়ে বাস্তবে না থাকা schema-কে applied বলবেন না।
Email provider-এর নির্দেশনা: https://resend.com/docs/api-reference/emails/send-email এবং https://resend.com/changelog/idempotency-keys । Scheduler চালু না থাকলে queue-তেই message থাকবে। Setup-এর পর নিজের সম্মত test contact দিয়ে hosted delivery যাচাই করুন।

## Teacher qualification ও অনুপলব্ধ সময়
**শিক্ষা সেটিংস → শিক্ষকের বিষয় ও ছুটি → Open register** খুলুন। **Assign subject** থেকে teacher ও subject নির্বাচন করে যোগ্যতা নিশ্চিত করুন। Active qualification ছাড়া ওই বিষয় শিক্ষককে assign করা যাবে না। ভবিষ্যৎ class থাকলে qualification inactive করার আগে substitute দিন অথবা class cancel করুন।

**Add unavailable period** থেকে Teacher অথবা Classroom বেছে বাংলাদেশ সময়ে শুরু/শেষ দিন। নির্দিষ্ট দিনের ছুটি, maintenance বা অন্য ব্যবহার এভাবে আটকানো যায়। একই সময় class থাকলে আগে reschedule/cancel করুন। সময় সংশোধন অথবা inactive করতে তালিকার **Edit / inactive** ব্যবহার করুন। পরিবর্তনে ঐতিহাসিক approved teaching report বদলাবে না। পুরোনো teacher-দের qualification অনুমান করে তৈরি করা হয়নি; পরবর্তী class তৈরির আগে admin যাচাই করবেন।
