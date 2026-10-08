"use client";
import { useLanguage } from "@/components/providers/language-provider";
import { StatusBadge } from "@/components/erp/status-badge";
import { DocumentAction, inputClass } from "@/modules/academics/documents/form";
import type { ClassFlow } from "./schema";
export function ClassPreparation({
  reminders,
}: {
  reminders: ClassFlow["reminders"];
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  return (
    <section className="space-y-3 rounded-xl border p-4">
      <h2 className="font-semibold">
        {t(
          "Next classes & exam preparation",
          "পরবর্তী ক্লাস ও পরীক্ষার প্রস্তুতি",
        )}
      </h2>
      <p className="text-sm text-muted-foreground">
        {t(
          "Next 7 days. Prepare your own Google Docs questions and answers, then submit for admin review. Exam reminders use the latest assigned class for that batch/subject; confirm the exam title in your topic.",
          "আগামী ৭ দিন। নিজের Google Docs-এ প্রশ্ন–উত্তর তৈরি করে admin review-এর জন্য জমা দিন। পরীক্ষার reminder একই ব্যাচ/বিষয়ের সর্বশেষ নির্ধারিত ক্লাসের সঙ্গে যুক্ত; topic-এ পরীক্ষার নাম নিশ্চিত করুন।",
        )}
      </p>
      {!reminders.length && (
        <p>
          {t(
            "No scheduled preparation in the next 7 days.",
            "আগামী ৭ দিনে নির্ধারিত প্রস্তুতি নেই।",
          )}
        </p>
      )}
      {reminders.map((r) => (
        <details key={r.id} className="rounded-lg border p-3">
          <summary className="cursor-pointer">
            <span className="font-medium">
              {r.date} · {r.batch} · {r.subject}
              {r.kind === "EXAM"
                ? ` · ${t("Exam", "পরীক্ষা")}: ${r.title}`
                : ""}
            </span>
            <span className="ml-2">
              <StatusBadge
                value={r.document?.status ?? "PENDING"}
                label={
                  r.document
                    ? {
                        DRAFT: t("Draft — submit", "খসড়া — জমা দিন"),
                        SUBMITTED: t("Awaiting review", "যাচাই বাকি"),
                        RETURNED: t("Correction needed", "সংশোধন প্রয়োজন"),
                        FINAL: t("Finalized", "চূড়ান্ত"),
                      }[r.document.status]
                    : t("Questions not submitted", "প্রশ্ন জমা হয়নি")
                }
              />
            </span>
          </summary>
          <div className="mt-3 space-y-3">
            <p className="text-sm">{r.topic}</p>
            {r.document?.review_note && (
              <p className="rounded-lg border p-3">{r.document.review_note}</p>
            )}
            {(!r.document ||
              ["DRAFT", "RETURNED"].includes(r.document.status)) && (
              <DocumentAction
                kind="questions"
                values={{
                  action: "SAVE",
                  session_id: r.session_id,
                  ...(r.assessment_id
                    ? { assessment_id: r.assessment_id }
                    : {}),
                  ...(r.document ? { id: r.document.id } : {}),
                }}
                label={t("Save question draft", "প্রশ্নের খসড়া রাখুন")}
              >
                <label>
                  {t(
                    "Chapter / topic / exam title",
                    "অধ্যায় / topic / পরীক্ষার নাম",
                  )}
                  <input
                    required
                    minLength={2}
                    maxLength={300}
                    name="topic"
                    defaultValue={
                      r.document?.topic ?? r.title ?? r.topic.slice(0, 300)
                    }
                    className={inputClass}
                  />
                </label>
                <label>
                  {t("Pages (optional)", "পৃষ্ঠা (ঐচ্ছিক)")}
                  <input
                    name="page_reference"
                    maxLength={100}
                    defaultValue={r.document?.page_reference}
                    className={inputClass}
                  />
                </label>
                <label>
                  {t(
                    "Google Docs questions and answers link",
                    "Google Docs প্রশ্ন ও উত্তরের link",
                  )}
                  <input
                    required
                    type="url"
                    name="draft_url"
                    defaultValue={r.document?.draft_url}
                    placeholder="https://docs.google.com/document/d/…/edit"
                    className={inputClass}
                  />
                </label>
                <p className="text-sm">
                  {t(
                    "Give admin permission to read the document. Saving alone does not submit it.",
                    "Admin-কে document পড়ার permission দিন। শুধু Save করলে review-এর জন্য জমা হবে না।",
                  )}
                </p>
              </DocumentAction>
            )}
            {r.document?.status === "DRAFT" && (
              <DocumentAction
                kind="questions"
                values={{ action: "SUBMIT", id: r.document.id }}
                label={t(
                  "Submit questions for admin review",
                  "প্রশ্ন admin review-এর জন্য জমা দিন",
                )}
              />
            )}
          </div>
        </details>
      ))}
    </section>
  );
}
