# Fresh Sohoj Academy setup

এই branch-এ একটি schema, একটি migration folder এবং একটি ERP entry `/dashboard`। Legacy modules, migrations, types ও docs সরানো হয়েছে। পুরোনো reference শুধু `master` branch-এ। Current feature scope জানতে [delivery status](refactor/DELIVERY_STATUS.md) পড়ুন।

## Pull and install
```bash
cd ~/all-projects/sohoj-academy
git fetch origin
git switch feature/refactor_sohoj
git pull --ff-only
pnpm install --frozen-lockfile
pnpm db:baseline:check
pnpm db:rpc-types:check
```
`.env.local`-এ `.env.example` অনুযায়ী একই Supabase project-এর URL/publishable key দিন। Public key browser-এ ব্যবহারের জন্য। Service role key এই implementation-এ প্রয়োজন নেই; browser/public env-এ দেওয়া যাবে না।

## Existing development project reset
সব application test data মুছে যাবে। `master` code সংরক্ষণ করে, database backup নয়। আগে নিজের linked project যাচাই করুন।
```bash
pnpm exec supabase login
pnpm exec supabase link --project-ref YOUR_PROJECT_REF
pnpm exec supabase projects list
pnpm exec supabase db reset --linked
pnpm exec supabase migration list --linked
```
Reset সাতটি নতুন migration 01–07 চালায়। Essential setup seed 04 migration-এর অংশ। আলাদা legacy seed বা temporary CLI directory প্রয়োজন নেই। Auth users/Storage files সম্পূর্ণ মুছে গেছে ধরে নেবেন না; Dashboard-এ যাচাই করুন। Normal `db push` দিয়ে পুরোনো schema প্রতিস্থাপন করবেন না; initial replacement-এর জন্য reset। Reset-এর পরে ordinary root `db push` subsequent নতুন migrations-এর জন্য। Migration repair দিয়ে পুরোনো history applied সাজাবেন না।

## New Supabase project
Project তৈরি করে link করুন, `.env.local`-এ সেটির URL/key দিন, তারপর:
```bash
pnpm exec supabase db push
```
এই commands ব্যবহারকারী নিজের machine-এ চালাবেন; repository change কোনো live DB reset করে না।

## Bootstrap administrator
Supabase Dashboard → Authentication → Users থেকে নিজের confirmed email/password account তৈরি/যাচাই করুন। SQL Editor-এ নিজের email দিয়ে একবার চালান:
```sql
select public.initialize_academy('YOUR_VERIFIED_EMAIL', 'Abdus Sattar');
notify pgrst, 'reload schema';
```
এটি verified Auth identity-কে প্রথম ADMIN বানায়। Public form, Person responsibility বা client metadata দিয়ে ADMIN পাওয়া যায় না। দ্বিতীয় administrator তৈরি/role assignment UI এখনও বাকি; database role হাত দিয়ে অনুমান করে পরিবর্তন করবেন না।

Auth Dashboard-এ Site URL `http://localhost:3000`; Redirect URLs `/auth/confirm` এবং `/auth/update-password`-এর absolute URLs দিন। Production-এ নিজের HTTPS domain ব্যবহার করুন।

## Run and inspect
আগের dev process বন্ধ করে:
```bash
pnpm dev
```
- `/`: CRM homepage; design/fonts/colors রাখা হয়েছে, fresh catalogue ব্যবহার করে।
- `/interest`: account ছাড়া enquiry/application; ভুল class/programme preference final placement নয়।
- `/auth/sign-in`: verified administrator sign in; এরপর `/dashboard`।
- `/dashboard/enquiries`: public submissions-এর paginated list।
- `/dashboard/people`: shared person ও responsibilities, edit/inactive।
- `/dashboard/directory`: school/area/subject/shared dropdown data।
- `/dashboard/programmes`: programme definitions; offering/fee/batch editing UI এখনও বাকি।

খালি fresh database-এ কোনো public offering থাকবে না। Fake published course/student/payment seed দেওয়া হয়নি। Backend catalogue আছে; public publishing editor পরবর্তী কাজ।
