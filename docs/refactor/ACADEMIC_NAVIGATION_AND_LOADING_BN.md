# সহজ শিক্ষা পরিচালনা: কাজ আলাদা, তথ্য প্রয়োজনমতো

## এই branch-এ কী তৈরি হচ্ছে
`feature/academic_operations`-এ প্রোগ্রাম প্রস্তুতি ও দৈনন্দিন ক্লাস পরিচালনার কাজ তৈরি হচ্ছে। বড় ERP-এর সব তথ্য এক পাতায় দেখানো উদ্দেশ্য নয়। শিক্ষক, শ্রেণিকক্ষ, ক্লাসের সময় এবং পরিবর্তনের বার্তা নির্ভরযোগ্যভাবে পরিচালনা করাই বর্তমান কাজ। এক পাতায় ভর্তি, শিক্ষার্থীর উপস্থিতি ও সহজ আর্থিক হিসাব পৃথক পরবর্তী কাজ; এগুলো সম্পূর্ণ হয়েছে বলে দেখানো যাবে না।

## কোথায় কোন কাজ করবেন
| অংশ | কাজ | ঠিকানা |
|---|---|---|
| শুরু | নতুন হলে ধাপ দেখুন; প্রস্তুতি থাকলে সরাসরি কাজে যান | `/dashboard/academics` |
| শিক্ষা সেটিংস | শিক্ষাবর্ষ, বিষয়, প্রতিষ্ঠানের তালিকা, শিক্ষক, শ্রেণিকক্ষ ও সময় | `/dashboard/academics/settings` |
| প্রোগ্রাম | প্রোগ্রামের তথ্য → ফি/ছাড় → ব্যাচ → প্রকাশ/আবেদন | `/dashboard/academics/programmes` |
| ক্লাস পরিচালনা | ক্লাস তৈরি, পরিবর্তন, বিকল্প শিক্ষক, অতিরিক্ত ক্লাস ও প্রতিবেদন যাচাই | `/dashboard/academics/sessions` |

Sidebar-এ শিক্ষা পরিচালনার একটি প্রবেশপথ থাকবে। ভেতরের লিংকগুলো আলাদা পাতায় যাবে; একই কাজ দুই জায়গায় রাখা হবে না। শিক্ষা সেটিংস শুধু তালিকার প্রবেশপথ: যেটি খুলবেন শুধু সেটির তথ্য আসবে।

## নতুন প্রশাসক কীভাবে শুরু করবেন
১. **শিক্ষা সেটিংস → শিক্ষাবর্ষ ও বিষয়** যাচাই করুন। প্রয়োজনীয় seed তথ্য আছে; সবকিছু আবার তৈরি করতে হবে না।
২. **প্রোগ্রাম** খুলে প্রোগ্রামের তথ্য যাচাই করুন। Save-এর পর ফি, তারপর ব্যাচ তৈরির পরের ধাপ দেখাবে। প্রয়োজনীয় প্রস্তুতি ছাড়া প্রকাশ বা আবেদন গ্রহণ database বন্ধ রাখবে।
৩. **শিক্ষা সেটিংস → শ্রেণিকক্ষ** থেকে নাম ও আসন প্রস্তুত করুন। **শিক্ষকের বিষয় ও ছুটি** থেকে qualification নিশ্চিত করুন। **সাপ্তাহিক সময়** দিয়ে teacher ও room-এর available সময় দিন; **ছুটি** থাকলে লিখুন।
৪. **ক্লাস পরিচালনা** খুলে নির্দিষ্ট ক্লাস অথবা weekday tick করে সাপ্তাহিক ক্লাস তৈরি করুন। কোনো প্রয়োজনীয় batch/room/qualified teacher না থাকলে পরের setup-এর সরাসরি লিংক দেখাবে।
৫. শিক্ষক নিজের ক্লাসে প্রতিবেদন জমা দেবেন। প্রশাসকের তালিকায় যাচাই বাকি প্রতিবেদন আগে আসবে। Approve অথবা সংশোধনের জন্য Return করুন।

## প্রতিবার সব কাজ করবেন না
- নতুন বিষয় যোগ করতে শুধু **বিষয়** খুলুন; প্রোগ্রাম বা class list আসবে না।
- Room inactive করতে শুধু **শ্রেণিকক্ষ** খুলুন। ভবিষ্যৎ class থাকলে আগে সরান।
- আজকের teacher অনুপস্থিত হলে **ক্লাস পরিচালনা → ওই class → শিক্ষক/সময় পরিবর্তন** করুন। Qualification ও সময় যাচাই হবে।
- Email পাঠানোর সমস্যা দেখতে **শিক্ষা সেটিংস → ইমেইল পাঠানোর অবস্থা** খুলুন; class list-এ সব email দেখানো হবে না।
- Teacher-এর জন্য প্রধান কাজ নিজের class ও report। Admin setup করেন; teacher-এর settings access থাকলেও অনুমোদিত reference তথ্যই দেখতে পারবেন।

## তথ্য কখন আসে
নিচের সংখ্যা academic কাজের read বোঝায়; নিরাপদ login ও permission যাচাই আলাদা এবং বজায় থাকবে।

| কাজ | তথ্য পড়া |
|---|---|
| শিক্ষা পরিচালনার শুরু পাতা | কোনো academic register নয় |
| শিক্ষা সেটিংসের মেনু | কোনো settings register নয় |
| প্রোগ্রাম পাতা | নির্বাচিত পরিচালনার programme register |
| একটি settings অংশ | শুধু সেই অংশের register; teacher অংশে প্রয়োজনীয় resource choices এবং register খুললে qualification তালিকা |
| ক্লাস পরিচালনা পাতা | নিজের/অনুমোদিত class list, প্রতি পাতায় ২৫টি |
| ক্লাস তৈরি বা পরিবর্তনের form | তখন batch, তার subject, qualified teacher ও room-এর প্রয়োজনীয় choices |
| Report জমা/যাচাই | নতুন করে setup choices পড়ার প্রয়োজন নেই |

Internal navigation links-এ automatic prefetch বন্ধ। পরিচালনার ধরন filter শুধু প্রোগ্রাম পাতায় থাকবে; যে পাতায় কাজ করে না সেখানে দেখিয়ে বিভ্রান্ত করা হবে না। Tab বদলাতে আগে client component খুলে পরে URL বদলানো হয় না; তাই একই register-এর দ্বিগুণ initial load কমে। Development Strict Mode-এর একই effect replay-তেও register-এর initial request পুনরাবৃত্তি বন্ধ করা হয়েছে। Save-এর পর পুরো ERP layout invalidation নেই; সংশ্লিষ্ট register refresh হয়। Public তথ্য বদলালে সংশ্লিষ্ট public page invalidate হবে।

## ভুল হলে
Form-এর তথ্য থাকবে। চলমান বা অনিশ্চিত save-এর ফল নিশ্চিত না করে অন্য অংশে যাওয়া যাবে না। সংরক্ষণ না করা তথ্য নিয়ে tab বদলালে discard confirmation হবে। Save সফল কিন্তু list refresh ব্যর্থ হলে সেটিকে save ব্যর্থ বলা হবে না। Refresh করে পরের কাজ করুন।

## নিরাপত্তা
UI-তে button লুকানো authorization নয়। সব read/write RPC-তে verified academy scope ও দায়িত্ব পরীক্ষা হয়। Teacher অন্যের session বা notification contacts দেখতে পারবেন না। কোনো server secret browser-এ যায় না। Public CRM-এর design, typography, font ও colour এই পরিবর্তনে বদলাবে না।

## Local চালু করা
```bash
git fetch origin
git switch feature/academic_operations
git pull --ff-only
pnpm install
pnpm exec supabase db push
pnpm dev
```
বর্তমান branch-এর schema থাকলে reset নয়; নতুন `16_focused_academic_reads.sql` যোগ হবে। ১৪–১৫ না থাকলে সেগুলোও আগে apply হবে। অন্য branch-এর ভিন্ন migration history থাকলে repair দিয়ে অনুমান করে applied করবেন না। `docs/SETUP.md` অনুসরণ করুন।
