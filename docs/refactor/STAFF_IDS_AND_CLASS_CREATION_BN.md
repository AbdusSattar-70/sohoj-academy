# স্থায়ী পরিচয় ও ক্লাস তৈরির নির্দেশনা

## পরিচয়

স্টাফ এবং শিক্ষক একই ব্যক্তি পরিচয়ের দায়িত্ব। তাদের স্থায়ী নম্বর `SA-STF-00001`। Referrer দায়িত্বে নম্বর `SA-RFR-00001`। একই ব্যক্তি দুই দায়িত্বে থাকলে দুটি দায়িত্বের নম্বর থাকবে, দ্বিতীয় ব্যক্তি record হবে না। দায়িত্ব বা নাম পরিবর্তন, নিষ্ক্রিয় করা এবং পুনরায় সক্রিয় করলে নম্বর বদলায় না। তালিকা এবং account request-এর সম্ভাব্য পরিচয় মিলেও এই নম্বর দেখাবে। People তালিকায় সম্পূর্ণ নম্বর লিখে খুঁজতে পারবেন। `P-…` কেবল অন্য ধরনের সাধারণ পরিচয়ের fallback; স্টাফের নম্বর নয়। আগে তৈরি স্টাফ নম্বর পুনরায় দেওয়া হবে না।

## একটি ক্লাস অথবা সাপ্তাহিক ক্লাস

১. [Programme offerings](/dashboard/academics/programmes)-এ সক্রিয় offering এবং পড়ানো বিষয় প্রস্তুত করুন।
২. [Batches](/dashboard/academics/batches)-এ সক্রিয় ব্যাচ রাখুন।
৩. [Classrooms](/dashboard/academics/settings?section=rooms)-এ যথেষ্ট আসনসহ শ্রেণিকক্ষ রাখুন।
৪. [Teacher qualifications](/dashboard/academics/settings?section=teachers)-এ সংশ্লিষ্ট বিষয়ের শিক্ষক নিশ্চিত করুন।
৫. [Class operation](/dashboard/academics/sessions)-এ **Schedule class** অথবা **Create weekly classes** চাপুন। ব্যাচ, বিষয়, যোগ্য শিক্ষক, শ্রেণিকক্ষ এবং বাংলাদেশ সময় নির্বাচন করুন।
৬. সাপ্তাহিক ক্লাসের জন্য ১–৩২ দিনের তারিখসীমা, শুরু/শেষের সময় ও অন্তত একটি weekday নির্বাচন করুন। নির্বাচিত weekday-তে ক্লাস তৈরি হবে; বন্ধের দিন বাদ যাবে।
৭. শিক্ষক ও শ্রেণিকক্ষের availability আগে সংরক্ষিত না থাকলে তাদের সঙ্গে সময় নিশ্চিত করে form-এর confirmation checkbox নির্বাচন করুন। এতে একই transaction-এ প্রয়োজনীয় সাপ্তাহিক availability ও ক্লাস সংরক্ষিত হবে। Checkbox না দিলে আগের availability থাকতে হবে। এই confirmation সাপ্তাহিক resource window যোগ করে—শুধু নির্দিষ্ট তারিখের জন্য নয়। প্রয়োজনে [Availability](/dashboard/academics/settings?section=availability)-এ পরে সংশোধন করুন।
৮. Save করুন। সফল হলে form বন্ধ হয়ে ক্লাসের তালিকা refresh হবে। কোনো ভুল হলে তথ্য রেখে কারণ দেখাবে।

এই সুবিধা অনুমোদিত academic manager-এর জন্য। এটি teacher qualification, room capacity, resource block, offering date, holiday বা একই সময়ে শিক্ষক/ব্যাচ/শ্রেণিকক্ষের অন্য booking এড়িয়ে যায় না। কোনো class ব্যর্থ হলে একই transaction-এর নতুন availability-ও সংরক্ষিত হবে না। অনিশ্চিত network response হলে একই request নিশ্চিত করুন; নতুন করে duplicate request পাঠাবেন না। সব নির্বাচিত দিন বন্ধ অথবা তারিখসীমায় কোনো নির্বাচিত weekday না থাকলে খালি routine তৈরি হবে না।

## আপডেট

Branch pull করার পরে নতুন 18 ও 19 migration `pnpm exec supabase db push` দিয়ে প্রয়োগ করুন। Database reset প্রয়োজন নেই।
