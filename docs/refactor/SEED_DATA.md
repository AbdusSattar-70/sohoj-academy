# স্থায়ী starter data

Seed data সাধারণ editable database record। এগুলো sample student/payment নয়; পরে real operations-এ রাখা যাবে। পুনরায় seed চালালে admin-এর নাম, ফি, তারিখ, status বা capacity edit overwrite হবে না। কোনো password, fake Auth identity, student, admission, invoice বা payment তৈরি হয় না।

## আগে থেকেই থাকবে
- School / Coaching / Preparation & Training divisions; Main Campus।
- Play, Nursery, KG, Class 1–12; graduation 3/4-year ও postgraduate tracks।
- পরিচিত subjects, Science/Humanities/Business groups, guardian relationships, Organic/Referral, discount reasons ও expense categories।
- ২০২৬ ও ২০২৭ academic year, দুটোই active।
- Gopalpur Bazar, Narundi, Nandina, Varuakhali area choices।
- ৬টি official-source school name: নরুন্দি, উত্তর নরুন্দি, দক্ষিণ নরুন্দি, নান্দিনা, নান্দিনা নেকজাহান ও শৈলেরকান্দা সরকারি প্রাথমিক বিদ্যালয়। নাম [উপজেলা শিক্ষা অফিসের সরকারি তালিকা](https://dpe.jamalpursadar.jamalpur.gov.bd/pages/static-pages/69708eb8a31054345f15c107) থেকে। Source/date database-এ থাকে; EIIN/contact অনুমান করা হয়নি। তালিকায় নাম থাকা accreditation/current activity-এর নিশ্চয়তা নয়।
- Programme definitions: School Academic Programme, SSC A+ Preparation, Spoken English, Primary Teacher Job Preparation।

## শুরু করার জন্য প্রস্তুত offerings
| Offering | Division | Dates | Starter tuition | Batch |
| --- | --- | --- | --- | --- |
| SCHOOL_8_2026 | School · Class 8 | 2026-01-01–2026-12-31 | BDT 2000/month | Morning A · 12 seats |
| SSC_10_2027 | Coaching · Class 10 | 2027-01-01–2027-12-31 | BDT 3000/month | Morning A · 12 seats |
| SPOKEN_2026 | Training · no school class/year | 2026-10-01–2026-12-31 | Unset starter amount: 0/course | Morning A · 12 seats |

এই fees/dates operating defaults, approved public quotation নয়। Admission fee initial 0; due day 10; 5/10/15/20/25/30% selectable discounts। Subjects offering-এ যুক্ত আছে। Website visibility ও intake প্রথমে বন্ধ; actual fee/date review ছাড়া automatic public publication নয়। Spoken English শূন্য মানে fee নির্ধারণ বাকি, free course ঘোষণা নয়।

## সঙ্গে সঙ্গে পরীক্ষা
1. `/dashboard/offerings` → **Fees** → প্রয়োজনমতো মূল্য ও discount choices ঠিক করুন।
2. **Batches** → **Edit** → নাম/আসন সংশোধন করুন।
3. **Edit / publish** → তারিখ/বিবরণ যাচাই → **Website visible** tick; প্রয়োজন হলে **Accept applications** tick → Save।
4. Homepage-এ card দেখুন; `/interest`-এ আবেদন জমা দিন; `/dashboard/enquiries`-এ দেখুন।

Existing offering context/subject selection ও নতুন offering/batch creation UI পরবর্তী extension। বর্তমান editor seeded/current offerings-এর title, date, copy, publish/intake, fees/discounts এবং existing batch edit/inactive করে। Admission/payment এখনও implementation বাকি; seed তা দাবি করে না।

## নতুন migration apply
Fresh schema 01–07 আগে reset করা থাকলে data reset করতে হবে না:
```bash
git pull --ff-only
pnpm exec supabase db push
pnpm dev
```
`08_persistent_starter_setup.sql` নতুন records যোগ করবে। নতুন install-এ normal reset 01–08 চালায়। সাধারণ seed পুনরায় চালিয়ে update করা নয়—UI দিয়ে record edit করুন।

## School entry কতটুকু?
**Name required**, **area optional**। Institution type defaults to School। Bangla alias, type, EIIN, official source/check date ও display order collapsed optional section-এ। Reason নিজে লেখা লাগে না; system action audit করে। Verified source না থাকলেও একটি school choice save/use করা যায়। Public unknown school name original enquiry-তে থাকে, master directory-তে নিজে থেকে authoritative school তৈরি হয় না।
