"use client";
import Link from "next/link";
import { useLanguage } from "@/components/providers/language-provider";
import { AcademicForm } from "../operations/command-form";
import type { AcademicWorkspace } from "../operations/schema";
export function CurriculumWorkspace({
  workspace: data,
  page,
  total,
}: {
  workspace: AcademicWorkspace;
  page: number;
  total: number;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  return (
    <section className="space-y-5">
      <h1 className="text-2xl font-semibold">
        {t("Teaching plans", "পাঠদান পরিকল্পনা")}
      </h1>
      <p>
        {t(
          "Prepare topic targets, select the plan on a weekly routine, then record actual coverage on each class.",
          "পাঠের লক্ষ্য প্রস্তুত করুন, রুটিনে পরিকল্পনা নির্বাচন করুন, তারপর প্রতিটি ক্লাসে বাস্তব অগ্রগতি লিখুন।",
        )}
      </p>
      <Link
        className="inline-flex rounded-lg border px-4 py-2"
        href="/dashboard/academics/routine"
      >
        {t("Weekly routines", "সাপ্তাহিক রুটিন")}
      </Link>
      <AcademicForm
        data={data}
        defaults={{ action: "PUBLISH_CURRICULUM" }}
        fields={[
          {
            key: "batch_id",
            label: t("Batch", "ব্যাচ"),
            options: data.batches,
          },
          {
            key: "subject_id",
            label: t("Subject", "বিষয়"),
            options: data.subjects,
          },
          { key: "title", label: t("Plan title", "পরিকল্পনার নাম") },
        ]}
        label={t("Create teaching plan", "পাঠদান পরিকল্পনা তৈরি")}
        description={t(
          "Keep earlier teaching plans intact. A new plan can be chosen for future classes.",
          "আগের পরিকল্পনা সংরক্ষিত থাকবে। ভবিষ্যৎ ক্লাসের জন্য নতুন পরিকল্পনা নির্বাচন করা যাবে।",
        )}
      />
      {data.curricula.map((c) => (
        <article className="rounded-xl border p-4" key={c.id}>
          <h2 className="font-semibold">
            {c.title} · v{c.version}
          </h2>
          <p>
            {c.batch} · {c.subject}
          </p>
          <ul>
            {c.units.map((u, i) => (
              <li key={i}>
                {u.title} · {u.target_date}
              </li>
            ))}
          </ul>
        </article>
      ))}
      <nav className="flex gap-4">
        {page > 1 && (
          <Link href={"?page=" + (page - 1)}>{t("Previous", "আগের")}</Link>
        )}
        <span>
          {page} · {total}
        </span>
        {page * 25 < total && (
          <Link href={"?page=" + (page + 1)}>{t("Next", "পরের")}</Link>
        )}
      </nav>
    </section>
  );
}
