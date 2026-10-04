# দ্রুত পরীক্ষার জন্য নমুনা ডেটা

এটি শুধু development/test database-এর জন্য। বাস্তব শিক্ষার্থী, টাকা, স্বাক্ষর বা login password তৈরি করে না। আগে থেকে থাকা bootstrap admin দিয়েই ERP-তে প্রবেশ করবেন।

## আগে যা প্রয়োজন

- `master`-এর migrations 01–22 একই Supabase project-এ প্রয়োগ করা থাকতে হবে।
- নিজের Auth account এবং সক্রিয় bootstrap ADMIN থাকতে হবে।
- Main Campus, CASH payment method এবং স্বাভাবিক academy capacity policy সক্রিয় থাকতে হবে। নমুনা batches-এর capacity 12।
- `.env.local` ও Supabase CLI project link সঠিক project-এর হতে হবে।

## একবারে চালান

```bash
git fetch origin
git switch master
git pull --ff-only
pnpm install
pnpm seed:demo
pnpm dev
```

`seed:demo` linked development project-এ pending migrations ও `supabase/seed.sql` প্রয়োগ করে। CLI confirmation পড়ুন। Migration history mismatch হলে থামুন: অন্য branch-এর history repair বা reset করে এই seed চালাবেন না। এই কাজের জন্য existing database reset প্রয়োজন নেই।

নতুন project হলে প্রথমে `pnpm exec supabase db push`, তারপর Supabase Authentication-এ নিজের user তৈরি করে SQL Editor-এ চালান:

```sql
select public.bootstrap_admin('YOUR_ADMIN_EMAIL', 'YOUR_NAME');
```

এরপর `pnpm seed:demo` চালান। Local Supabase-এর fresh reset হলে `pnpm exec supabase db reset --no-seed` ব্যবহার করুন, local Auth user ও bootstrap তৈরি করুন, তারপর `pnpm seed:demo --local`। স্বাভাবিক reset-এর automatic seed bootstrap না থাকলে স্পষ্ট error দিয়ে থামবে।

CLI seed না চালিয়ে database up-to-date বললে linked project-এর SQL Editor-এ repository-এর `supabase/seed.sql` সম্পূর্ণ চালাতে পারেন। একই script দ্বিতীয়বার চালালেও duplicate তৈরি হবে না।

## কী দেখবেন এবং কোথায় পরীক্ষা করবেন

| পৃষ্ঠা | নমুনা / পরীক্ষা |
| --- | --- |
| `/` ও `/interest` | ২টি DEMO programme offering, subject choices, খোলা application intake |
| `/dashboard/academics/offerings` | SSC ও Annual Readiness offering; monthly tuition 3,000 এবং admission fee 500 |
| `/dashboard/academics/batches` | ৩টি batch, প্রতিটিতে ১২ আসন |
| `/dashboard/crm/prospects` | ৬টি unverified enquiry; ভুল class/programme preference-ও verification queue-তে জমা হয়েছে |
| `/dashboard/admissions` | ১টি Draft, ১টি Ready, ৩টি finalized student case |
| `/dashboard/students` | ৩টি স্থায়ী student identity |
| `/dashboard/finance/billing` | নিচের paid / part-paid / unpaid উদাহরণ |
| `/dashboard/staff` | Teacher ও Operator-এর ২টি pending access request |

| শিক্ষার্থী | বিল | নমুনা collection | বাকি |
| --- | ---: | ---: | ---: |
| DEMO Part Paid Student | 3,200 — tuition-এ ১০% discount | 1,500 | 1,700 |
| DEMO Paid Student | 3,500 | 3,500 | 0 |
| DEMO Unpaid Student | 3,500 | 0 | 3,500 |

বর্তমান activation policy যতটুকু payment অনুমোদন করে শুধু সেই case-ই enrolled হবে। Seed payment policy বদলায় না। Default policy-তে তিনটি finalized case enrolled হবে।

Financial entries actual controlled billing/payment workflow দিয়ে journal তৈরি করে; collection reason-এ `DEMO` ও “no real money” লেখা থাকে। Paper consent reference-এ simulated file লেখা থাকে; কোনো বাস্তব স্বাক্ষর কিংবা digital consent তৈরি হয় না। নমুনা staff email `.test` domain-এর; invitation পাঠাবেন না। Teacher login তৈরি হয়নি—নিজের সত্যিকারের verified test account দিয়ে teacher interface পরীক্ষা করবেন।

## Existing ডেটা ও পুনরায় চালানো

কোনো record delete, password change বা existing record overwrite করা হয় না। প্রয়োজন হলে existing academy নাম অপরিবর্তিত রেখে setup prerequisites সম্পন্ন হয়। Demo public offerings website-এ দৃশ্যমান হয়। Reserved `DEMO` code আগে থাকলে overwrite না করে error দেখায়।

শেষে audit marker লেখা হয়। আবার চালালে marker দেখে existing demo এবং আপনার পরিবর্তনগুলো রেখে থামে; নতুন copy বা reset করে না। Marker মুছে পুনরায় seed চালাবেন না। Fresh test project প্রয়োজন হলে আলাদা project তৈরি করে [fresh database setup](../architecture/FRESH_DATABASE_SETUP.md) অনুসরণ করুন।
