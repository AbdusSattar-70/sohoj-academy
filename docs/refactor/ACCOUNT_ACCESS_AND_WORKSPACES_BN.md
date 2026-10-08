# Account, দায়িত্ব ও কর্মক্ষেত্র পরিচালনা

Branch: `feature/academic_operations`। বর্তমান নতুন schema-এর জন্য migrations 26–27। Database reset করবেন না।

## কেন এই পরিবর্তন

পুরোনো master branch-এর `components/erp/erp-account.tsx`-এ sign out এবং `modules/settings/components/role-permission-editor.tsx` ও `user-access-editor.tsx`-এ দায়িত্ব ও account access নিয়ন্ত্রণ ছিল। Fresh branch-এর sidebar-এ logout বাদ পড়েছিল এবং workspace preference শুধু programme register filter করছিল। এই পরিবর্তনে সেই প্রয়োজনীয় account controls বর্তমান schema ও সুরক্ষার সঙ্গে যুক্ত হয়েছে। পুরোনো finance/schema আবার আনা হয়নি।

## প্রথমে প্রশাসক যা করবেন

1. [Settings & Help](/dashboard/settings) খুলুন।
2. [দায়িত্ব, অনুমতি ও কর্মক্ষেত্র](/dashboard/settings/access) নির্বাচন করুন। এই পেজ শুধু ADMIN খুলতে পারবেন।
3. **TEACHER → Edit permissions** খুলে প্রয়োজনীয় কাজের tick দিন। সাধারণ শিক্ষকের জন্য **View academic work** ও **Record own attendance and submit class work** যথেষ্ট। Subject তালিকা দেখানোর জন্য **View shared academic choices** রাখতে পারেন।
4. **Verified accounts** তালিকায় ব্যক্তিকে নাম, email বা staff number দিয়ে খুঁজুন।
5. **Edit access** খুলে দায়িত্ব ও অনুমোদিত School/Coaching/Training কর্মক্ষেত্র নির্বাচন করুন।
6. Account চালু থাকবে কি না নির্বাচন করে পরিবর্তনের কারণসহ Save করুন। Input ভুল হলে form খোলা থাকবে; error সংশোধন করে আবার Save করুন।

Role পরিবর্তন ওই দায়িত্বের সব account-এ প্রযোজ্য। Account-এর workspace নির্বাচন শুধু সেই ব্যক্তির জন্য। এক ব্যক্তি একাধিক কর্মক্ষেত্রে কাজ করতে পারবেন; নতুন পরিচয় বা staff ID প্রয়োজন নেই।

ADMIN-এর recovery role ও administrator account এই editor দিয়ে পরিবর্তন করা যায় না। অন্য কাউকে ADMIN করার public/operational shortcut নেই। Account-এর দায়িত্ব পরিবর্তন মানেই subject qualification বদলানো নয়; শিক্ষক কী বিষয় পড়াতে পারবেন তা [Teacher preparation](/dashboard/academics/settings?section=teachers)-এ প্রস্তুত করুন।

## শিক্ষক কী দেখবেন ও করবেন

সাধারণ teacher permission নিয়ে:

- Login-এর পর অনুমোদিত কর্মক্ষেত্র নির্বাচন করবেন।
- Dashboard-এ নিজের আজকের ক্লাস ও ফেরত দেওয়া প্রতিবেদন দেখবেন।
- নিজের calendar, assigned classes এবং approved actual teaching hours দেখবেন।
- `academics.teach` অনুমতি থাকলে নিজের open class-এ attendance, homework/assessment note ও actual teaching time লিখে draft/save/submit করবেন।
- অন্য শিক্ষকের report জমা, নিজের report approve, role/account permission পরিবর্তন বা standard fees edit করতে পারবেন না।
- `academics.teach` সরালে নিজের ক্লাস দেখতে পারবেন, কিন্তু কাজ edit/submit করতে পারবেন না। খোলা পুরোনো form দিয়েও database এই নিষেধ কার্যকর করবে।

Class management এবং report review সাধারণ শিক্ষককে দেবেন না। বিশেষ দায়িত্বপ্রাপ্ত ব্যক্তিকে ADMIN প্রয়োজন বুঝে আলাদা করে অনুমতি দিতে পারেন। Report review-এর জন্য বর্তমানে class management ও report review দুটো অনুমতি দরকার। নিজের report-এর self-approval নিষেধ তখনও থাকবে।

OPERATOR/ACCOUNTANT/REFERRER নামগুলো নিজে থেকে নতুন financial বা referral feature তৈরি করে না। এই branch-এ বাস্তবে থাকা কাজের permissions-ই তালিকায় আছে। অনুপস্থিত payroll/admission/payment module এই পরিবর্তনের অংশ নয়।

## নতুন account request-এর পর

[Account access requests](/dashboard/people/access)-এ পরিচয় ও প্রয়োজনীয় দায়িত্ব যাচাই করুন। প্রয়োজন হলে আগের পরিচয় link করুন; setup instructions পাঠান। Account তৈরি/link হলে **Assign account roles & workspaces** থেকে দায়িত্ব ও কর্মক্ষেত্র নিশ্চিত করুন।

নতুন account-এর জন্য automatic সব কর্মক্ষেত্র অনুমতি দেওয়া হয় না। কর্মক্ষেত্র না থাকলে login হলেও operational workspace খুলবে না; প্রশাসকের কাছে assignment চাইতে হবে। Setup email এবং operational permissions আলাদা কাজ। শুধু email পাঠানো মানেই সব তথ্য দেখার অনুমতি নয়।

এই migration-এর আগে থাকা verified account-এর workspace access upgrade-এর সময় বজায় রাখতে সব বর্তমান division backfill হয়েছে। প্রশাসক এই তালিকা অবিলম্বে প্রয়োজন অনুযায়ী সীমিত করবেন। এটি পরবর্তী নতুন account-এর default নয়।

## School, Coaching ও Training আলাদা রাখা

Login-এর পর অনুমোদিত workspace নির্বাচন করুন; sidebar থেকে পরে switch করতে পারবেন। Switch করার আগে চলমান request-এর ফলাফল নিশ্চিত করতে হবে; unsaved form থাকলে discard confirmation দেখাবে।

নির্বাচিত workspace অনুযায়ী:

- Programme offerings ও তার fees/batches;
- Routine, class calendar, dated sessions;
- Student enrollment/transfer ও attendance;
- Approved teaching-hours report;
- Workspace-সম্পর্কিত People তালিকা;
- Batch notification contacts ও session email status;
- পরিচিত offering-এর public enquiry review queue

দেখাবে। অন্য workspace-এর direct class/programme URL অথবা RPC-ও operational record read/write অনুমতি দেয় না। Request replay-এর আগেও workspace যাচাই হয়। Cookie preference নিজে কোনো access grant নয়; DB verified account assignment যাচাই করে।

Public আবেদন unverified claim হিসেবেই থাকবে। Offering পছন্দ review queue routing-এর জন্য ব্যবহৃত হয়; admission/enrollment হিসেবে সত্য ধরে নেওয়া হয় না। ভুল/অনুপস্থিত offering হলে **Workspace needs verification** হিসেবে শুধু ADMIN দেখবেন। এটি সাধারণ operator-এর অন্য workspace-এর আবেদন দেখার পথ নয়।

## যেগুলো একাডেমিজুড়ে shared

School/institution নাম, subjects, academic years, programme definitions, ব্যক্তি পরিচয় এবং physical classroom একই master record থাকবে। School ও Coaching-এর জন্য একই school নাম বা শিক্ষককে দুইবার তৈরি করা যাবে না। People register নির্বাচিত workspace-এর মানুষ দেখালেও controlled identity matching যাচাইকৃত admission/access কাজের জন্য shared পরিচয় খুঁজতে পারে—duplicate এড়ানোর জন্য।

Room ও শিক্ষক বাস্তবে একই resource হওয়ায় booking conflict এবং future availability protection একাডেমিজুড়ে যাচাই হবে। School-এ room বুক থাকলে একই সময়ে Coaching ওই room বুক করতে পারবে না। একই নিয়ম teacher-এর জন্য। শিক্ষক নির্বাচন করতে account-টি সেই workspace-এ assigned হতে হবে। Room/holiday master setup shared; class booking shared নয়।

Account requests ও account access configuration ADMIN-এর global control area; এগুলো teaching register নয়।

## Account ও logout

Desktop sidebar-এর নিচে **Sign out** আছে; collapsed sidebar-এ icon ও tooltip আছে। Mobile navigation এবং প্রথম workspace-selection screen-এও Sign out আছে। চলমান request বা unsaved form যাচাই না করে logout হবে না।

Sign out এই browser-এর session শেষ করবে এবং workspace cookie পরিষ্কার করবে। Server ফলাফল নিশ্চিত না করতে পারলে retry feedback দেখাবে। অন্য device-এর session আলাদা থাকবে।

[My account](/dashboard/settings)-এ নিজের নাম, staff ID ও দায়িত্ব দেখা যায় এবং password recovery instructions নেওয়া যায়। নিজের দায়িত্ব/identity correction-এর জন্য ADMIN-কে জানাবেন। Header-এর language button দিয়ে বাংলা বা English নির্বাচন করুন। Account/email server configuration শুধু ADMIN-এর settings-এ দেখাবে।

## Update ও যাচাই

```bash
git fetch origin
git switch feature/academic_operations
git pull --ff-only
pnpm install
pnpm exec supabase db push
pnpm build
pnpm dev
```

পুরোনো dev server থাকলে আগে বন্ধ করুন। নতুন migrations 26–27 apply হবে। Live database reset বা email পাঠানো এই কাজের অংশ নয়।

স্থানীয় acceptance:

1. ADMIN দিয়ে School নির্বাচন করে School programme/batch/session দেখুন। Coaching-এ switch করে তালিকা বদলায় কি না দেখুন।
2. একটি teacher account-এ শুধু School ও সাধারণ teacher permissions দিন।
3. Teacher login-এ অন্য workspace button থাকা উচিত নয়। নিজের class work জমা দেওয়া যাবে; অন্যের class URL ও account settings চলবে না।
4. ADMIN teacher-এর report permission সরিয়ে দিন; teacher নতুন action-এ edit/submit করতে পারবেন না।
5. Desktop/mobile Sign out করে browser Back চাপলেও protected route-এ account পুনরায় যাচাই হবে।

TypeScript, targeted lint, production build এবং isolated SQL regression-এর মাধ্যমে migration application, role protection, actor audit, retry, teacher scope, cross-workspace detail/write denial ও dated class-work workflow যাচাই করা হয়েছে। Hosted database ও browser visual acceptance ব্যবহারকারীর environment-এ বাকি।
