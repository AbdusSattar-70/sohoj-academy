import Link from "next/link";
import { requirePermission } from "@/modules/platform/auth/erp-context";
const steps = [
  [
    "১. প্রয়োজনীয় তালিকা",
    "শ্রেণি, বিষয় ও শিক্ষাবর্ষ যাচাই করুন। শ্রেণি হলো শিক্ষার স্তর; শ্রেণিকক্ষ বাস্তব ঘর।",
    "/dashboard/crm/manage",
  ],
  [
    "২. অফারিং ও ফি",
    "School/Coaching-এ class/year দিন। Training-এ course dates দিন; class/year ঐচ্ছিক। ফি ও website intake আলাদা controls।",
    "/dashboard/academics/offerings",
  ],
  [
    "৩. ব্যাচের দিন ও সময়",
    "আসনসংখ্যা ও প্রতিদিনের সময় দিন। একই দিনে একাধিক subject session চলতে পারে।",
    "/dashboard/academics/planning?section=batches",
  ],
  [
    "৪. কক্ষ ও ব্যবহারযোগ্য সময়",
    "কক্ষের capacity, শিক্ষকের পাঠদানের বিষয় ও দিনভিত্তিক কার্যকর সময় যাচাই করুন। availability থাকলেও অন্য booking থাকলে সময় খালি নয়।",
    "/dashboard/academics/planning?section=availability",
  ],
  [
    "৫. ছুটি",
    "academy holiday এবং শিক্ষক/কক্ষ বন্ধের সময় দিন। আগে scheduled class থাকলে আগে তার বিকল্প ব্যবস্থা করুন।",
    "/dashboard/academics/planning?section=closures",
  ],
  [
    "৬. পাঠদান পরিকল্পনা ও রুটিন",
    "পাঠের target প্রস্তুত করে routine-এ নির্বাচন করুন। ব্যাচ, বিষয়, শিক্ষক, room ও দিনভিত্তিক সময় দিন; তারপর Generate classes। একবারে সর্বোচ্চ ৯৪ দিন, holiday বাদ যায়, retry duplicate করে না।",
    "/dashboard/academics/routine",
  ],
  [
    "৭. ভর্তি",
    "ব্যাচের সময় ও খালি আসন দেখে ভর্তি করুন। enrollment কার্যকর হওয়ার দিন থেকে attendance roster-এ শিক্ষার্থী আসবে।",
    "/dashboard/admissions",
  ],
  [
    "৮. আজকের ক্লাস ও review",
    "শিক্ষক attendance ও actual start/end সহ পাঠদানের report জমা দেন। Admin approve বা correction ফেরত দেন। দুটো approved হলে verified actual hours teaching earnings-এ যায়।",
    "/dashboard/academics/operations",
  ],
];
export default async function Page() {
  await requirePermission("academics.view");
  return (
    <section lang="bn" className="mx-auto max-w-4xl space-y-5">
      <Link
        className="inline-flex rounded-lg border px-4 py-2"
        href="/dashboard/help"
      >
        ← সাহায্য
      </Link>
      <h1 className="text-2xl font-semibold">শিক্ষা কার্যক্রম পরিচালনা</h1>
      <p>
        কী শেখাবেন → কাদের শেখাবেন → কখন, কোথায় ও কে শেখাবেন → বাস্তবে কী হয়েছে।
      </p>
      {steps.map(([title, text, href]) => (
        <article key={title} className="rounded-xl border p-5">
          <h2 className="font-semibold">{title}</h2>
          <p className="my-3 leading-7">{text}</p>
          <Link
            className="inline-flex rounded-lg border px-4 py-2 hover:bg-muted"
            href={href}
          >
            কাজটি খুলুন →
          </Link>
        </article>
      ))}
      <article className="space-y-3 rounded-xl border p-5">
        <h2 className="font-semibold">পরিবর্তন ও সমস্যা</h2>
        <p>
          একটি ক্লাসে Action দিয়ে substitute, room change, reschedule, cancel বা
          makeup দিন। মূল session-এর ইতিহাস থাকবে; নতুন resource আবার যাচাই হবে।
          submitted বা approved evidence থাকা session rewrite হবে না।
        </p>
        <p>
          “availability does not cover” হলে পুরো session-এর সময়, সপ্তাহের দিন ও
          effective dates যাচাই করুন। পাশাপাশি windows পুরো সময় cover করতে পারে;
          gap থাকলে পারবে না। ভুল input মুছে যাবে না। ফল unconfirmed হলে একই
          তথ্য রেখে আবার confirm করুন।
        </p>
        <p>
          ২ ঘণ্টার পরিকল্পনা, বাস্তবে ১.৫ ঘণ্টা হলে approved teaching workload
          ১.৫ ঘণ্টা। academy-তে staff উপস্থিতি ও fixed salary আলাদা। টাকা না
          পেলে due থাকবে।
        </p>
      </article>
    </section>
  );
}
