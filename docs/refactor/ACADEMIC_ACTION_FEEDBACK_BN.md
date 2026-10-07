# শিক্ষা পরিচালনা ও পদক্ষেপের ফলাফল

## কোথায় কোন কাজ

নতুন login-এর পর প্রথমে School, Coaching অথবা Job preparation & training কর্মক্ষেত্র নির্বাচন করুন। নির্বাচন এই browser tab-এর session-এ থাকবে; refresh করলে আবার নির্বাচন লাগবে না। Sidebar থেকে পরিবর্তন করুন। নতুন login বা নতুন tab-এ আবার নির্বাচন করতে হবে। এটি permission পরিবর্তন করে না।

| পেজ | কাজ |
| --- | --- |
| /dashboard/academics/settings | শিক্ষাবর্ষ, বিষয়, programme-এর reusable নাম, room ও অন্যান্য shared settings |
| /dashboard/academics/programmes | Programme offering-এর campus, বছর, class, বিষয়, শুরু/শেষ ও active status |
| /dashboard/academics/fees | নির্বাচিত offering-এর নির্ধারিত fee ও discount |
| /dashboard/academics/batches | নির্বাচিত offering-এর batch ও আসন |
| /dashboard/academics/website | Website visibility, application intake ও public copy |
| /dashboard/academics/sessions | দিনের class operation |

Offering তৈরির ক্রম: কর্মক্ষেত্র নির্বাচন → programme নির্বাচন → বছর/class/বিষয় → সংরক্ষণ → নির্ধারিত fee → batch → website/applications। Programme নাম থেকেই offering-এর নাম তৈরি হয়; দ্বিতীয় নাম লিখতে হয় না। Public CRM design অপরিবর্তিত।

## তথ্য না পাওয়া গেলে

Subject, school অথবা অন্য directory choice খুঁজুন। আগে থাকলে সেটি নির্বাচন করুন। না থাকলে “Add missing choice” ব্যবহার করুন। Validation ব্যর্থ হলে নির্দিষ্ট field-এর বার্তা দেখুন; লেখা মুছে যাবে না। Selected subject নিচের tick তালিকায় থাকবে; tick সরালে বর্তমান নির্বাচন থেকে সরবে।

## পরিবর্তনের কারণ

সাধারণ কারণ নির্বাচন করা যায়। উপযুক্ত কারণ না থাকলে “Other — write a reason” নির্বাচন করে অন্তত পাঁচ অক্ষরে কারণ লিখুন। নিজস্ব কারণ audit event-এ থাকবে; এটি নতুন global dropdown item তৈরি করে না।

## Account setup

প্রত্যেক request-এর action button চলাকালীন preparing state দেখাবে। Success/error একই row-তে থাকবে। আগের Auth account থাকলেও এবার fresh password setup/recovery email পাঠানোর অনুরোধ যাবে; শুধু account link করাকে email success বলা হবে না। Error হলে account configuration খুলুন। Server-only service role key, site URL, auth redirect এবং email service সঠিক হতে হবে। UI পরিবর্তন দিয়ে ভুল credential ঠিক করা যায় না। বাস্তব invitation email পাঠিয়ে এই release যাচাই করা হয়নি।

## পরিচয় ও নিরাপত্তা

Sidebar-এর নিচে নাম, role ও SA-STF-00001 ধরনের স্থায়ী Staff ID থাকবে। Staff/Teacher responsibility দিলে ID একবার তৈরি হবে; নাম, role বা inactive status পরিবর্তনে এটি বদলাবে না। Referrer-only ব্যক্তি Staff নন, তাই Staff ID প্রযোজ্য নয়। পুরোনো bootstrap admin-এর account-ও person identity-তে link হবে। UUID ও database permission checks অপরিবর্তিত।

## প্রকাশিত সীমা

Action buttons-এর ERP-only visual treatment ও pointer একরকম করা হয়েছে। Shared editor, academic operation form, directory create এবং account setup feedback সংশোধিত। প্রতিটি browser/network পরিস্থিতিতে সমস্ত ERP action যাচাই করা হয়নি। Session attendance, routine editing ও সম্পূর্ণ admission lifecycle এই সংশোধনের অন্তর্ভুক্ত নয়।
