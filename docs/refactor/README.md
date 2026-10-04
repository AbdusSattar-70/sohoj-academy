# Sohoj Academy — নতুন প্রথম সংস্করণের চুক্তি

Branch: `feature/refactor_sohoj`। সিদ্ধান্তের তারিখ: ৫ অক্টোবর ২০২৬।
এই docs নতুন implementation-এর authoritative contract। এটি পরিকল্পনা; এখানে বর্ণিত redesign এখনও implemented নয়। Branch master থেকে তৈরি; inherited app/schema এখনও পুরোনো অবস্থায় রয়েছে। এই documentation commit database reset বা migration replacement করে না।

## পড়ার ক্রম
1. [Architecture ও scope](ARCHITECTURE.md)
2. [Database ও migration](DATABASE_AND_MIGRATIONS.md)
3. [দৈনন্দিন workflow](OPERATIONAL_WORKFLOWS.md)
4. [Form, navigation ও print](INTERACTION_AND_PRINT.md)
5. [Seed data](SEED_DATA.md)
6. [Implementation ও acceptance](IMPLEMENTATION_PLAN.md)

## স্থির সিদ্ধান্ত
- একটি academy, একজন প্রধান admin; School, Coaching, Preparation/Training আলাদা operating division।
- School Play–Class 8; Coaching Class 9–12; job preparation/training-এ school class বাধ্যতামূলক নয়।
- বর্তমান CRM/public website-এর layout, typography, font, colour ও visual identity সংরক্ষিত। নতুন data/form behaviour সেই design-এর সঙ্গে যুক্ত হবে।
- একটি ব্যক্তি একটি person identity; student, guardian, staff/teacher, referrer হলো linked responsibility/relationship।
- Public applicants/student/guardian-এর account দরকার নেই। Unverified আবেদন master data বা enrollment তৈরি করে না।
- Admin/authorized admission personnel নিজেই admission সম্পন্ন করেন। দ্বিতীয় admission approver নেই। Teacher academic submissions admin review করেন।
- কম typing: search/select, checkbox, safe defaults, inline create। English/Bangla নির্বাচনে এক ভাষার interface।
- Admission এক working page: identity, placement, fees, paper consent, review, confirmation, payment ও printing।
- Digital admission consent/upload নেই; physical signed form ও file reference থাকবে।
- Finance শুধু billing, collection/refund, staff/referral remuneration, running expense এবং পরিচালন লাভ/cash summary।
- Assets/depreciation, stock/procurement engines, counters, budget, capital management ও deep accounting UI নতুন scope নয়।
- Existing development financial history/data migration প্রয়োজন নেই। Fresh schema হবে নতুন 01 থেকে। নতুন system চালুর পর identity, audit ও posted evidence সংরক্ষিত থাকবে।
- Essential editable seed এবং optional fictional demo data পৃথক।

## পুরোনো docs-এর অবস্থান
এই branch-এর `docs/architecture/DEVELOPMENT_HANDOFF.md` নতুন index নির্দেশ করে। Inherited finance roadmaps ও পুরোনো architecture docs historical implementation context মাত্র; সেগুলো এই নতুন scope override করে না। Code replacement-এর সঙ্গে obsolete docs সরাতে হবে; পুরোনো branch-এ reference আছে। User-এর পরবর্তী explicit instruction এই docs-এর উপরে প্রাধান্য পায়।

## Implementation status

Actual implementation started. Read [Delivery status](DELIVERY_STATUS.md) before applying database commands. Backend foundation is staged; current app still uses the inherited schema until the replacement contracts are complete.
