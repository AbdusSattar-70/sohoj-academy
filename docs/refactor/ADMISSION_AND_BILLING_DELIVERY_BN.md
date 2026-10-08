# এক পাতায় ভর্তি ও শিক্ষার্থীর বিল

## কাজের পথ

[ভর্তি](/dashboard/academics/admissions) → নতুন আবেদন / public enquiry / পুরোনো শিক্ষার্থী → তথ্য ও placement নির্বাচন → খসড়া সংরক্ষণ → একই case page-এ যাচাই → ভর্তি নিশ্চিত → প্রথম invoice ও enrollment → প্রয়োজন হলে payment → invoice/receipt print।

নতুন walk-in আবেদন CRM enquiry তৈরি করবে না। Public পছন্দ unverified থাকবে; operator স্বাধীনভাবে সঠিক programme ও batch নির্বাচন করবেন। Class mismatch-এর জন্য conversion আটকে যাবে না। ছাত্র/অভিভাবকের login দরকার নেই। Minor-এর guardian প্রয়োজন; adult training-এর guardian optional।

## ধাপে delivery ও commit

1. Scoped admission drafts, direct/enquiry/existing identity paths, editable application ও compact register।
2. Verified final submission: permanent Student ID, batch roll, dated enrollment এবং প্রথম invoice একই transaction-এ। Standard fee snapshot ও স্পষ্ট discount; পূর্ণ payment বাধ্যতামূলক নয়।
3. একই case-এ payment, invoice correction/discount, receipt, refund এবং পরের tuition invoice।
4. Monochrome letterhead-safe application/invoice/receipt, blank form, বাংলা operator help ও integration verification।

## তথ্য ও নিরাপত্তা

একটি real person-এর এক পরিচয়; shared mobile/email দিয়ে কাউকে automatic merge করা হবে না। Existing student/guardian search ও duplicate confirmation থাকবে। Student ID `SA-000001`, Staff/Referrer IDs অপরিবর্তিত। Schools/relationships/discount reasons select/create; typo বা missing choice-এ input হারাবে না। Paper consent-এর staff acknowledgement থাকবে; digital file upload বা electronic signature নয়।

Draft অসম্পূর্ণ অবস্থায় save করা যাবে। Final করার আগে verified student/contact, applicable guardian, active offering, তার fees, batch capacity, effective enrollment date, source, discount reason ও declaration যাচাই করতে হবে। Website-visible/open-applications staff admission-এর শর্ত নয়। কোনো staff maker-checker admission approval নয়; teacher academic review পৃথক থাকবে।

Final fee plan বদলে গেলে operatorকে refresh/review করতে হবে। Final invoice-এর lines পরে fee settings বদলালেও rewrite হবে না। Discount এবং scholarship explicit reduction; student credit নামে নয়। Payment শুধু বাস্তব money receipt; zero payment মানে due invoice, receipt নয়। Idempotent requests, scoped permission, row locks, immutable financial evidence, audit এবং no deletion বজায় থাকবে।

School/Coaching/Training-এর admission, invoice, payment ও collection register আলাদা workspace-এ থাকবে। একই student একাধিক programme-এ ভর্তি হতে পারবেন; একই offering-এ duplicate open enrollment নয়।

## পরীক্ষার উদাহরণ

- নতুন school student → guardian → paper form acknowledgement → 10% permitted tuition discount → unpaid confirmation → partial payment → receipt → class attendance roster।
- ভুল class-সহ public enquiry → সঠিক offering বেছে ভর্তি → original preference unchanged; duplicate conversion নয়।
- পুরোনো student → নতুন offering → একই Student ID ও guardian reuse → পৃথক invoice।
- Adult course → নিজস্ব contact, optional guardian → course billing।
- একই request retry → দ্বিতীয় student/invoice/payment নয়; last seat concurrent admission → একটিই সফল।

এটি নতুন simple model; master-এর advanced GL/advance/assets/payroll architecture ফিরিয়ে আনা হবে না। এই delivery document implementation-এর সঙ্গে সম্পন্ন অবস্থা ও সীমা হালনাগাদ হবে।

## বাস্তবায়িত delivery — ৮ অক্টোবর ২০২৬

- 28: সরাসরি/website enquiry/existing identity admission draft, compact register, school/relationship/discount reason inline directory selection।
- 29: reviewed paper acknowledgement, permanent Student ID, batch roll, enrollment ও initial invoice একই transaction-এ।
- 30: payment/numbered receipt, explicit discount ও scholarship, original receipt-linked refund, operator-run next tuition, workspace-scoped billing search।
- 31: ভুল/বন্ধ unconfirmed draft বাতিল; ইতিহাস অক্ষত।
- একই case থেকে application, invoice ও actual payment receipt print; letterhead-এর জন্য branding header নেই। Printable acknowledgement টাকা গ্রহণের প্রমাণ নয়।
- ERP-তে বাংলা সাহায্য: `/dashboard/help/admission`; ভর্তি `/dashboard/academics/admissions`; student account search `/dashboard/billing`।

### যাচাই ও সীমা

Fresh baseline isolated PostgreSQL-compatible execution, TypeScript ও production build যাচাই করা হয়েছে। পরীক্ষা: direct entry-তে enquiry তৈরি না হওয়া, confirmation/payment retry, Student ID/enrollment, unpaid due, scholarship/refund balance, overpayment rejection, next tuition ও cross-workspace denial। Hosted database বা real email পরিবর্তন হয়নি। Local browser/letterhead printer acceptance admin করবেন।

Confirmed identity correction existing People workflow-তে হয়; admission draft নিজেরাই existing identity বদলায় না। Referrer reward settlement, salary, academy expenses/profit ও full assessment/question bank এই admission delivery-এর অংশ নয়। Recurring invoices operator চালান; background auto-billing নয়। Student IDs permanent; guardian-এর shared mobile দিয়ে automatic merge হয় না।
