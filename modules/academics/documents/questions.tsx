"use client";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import type { QuestionWorkspace } from "./schema";
import { DocumentAction, inputClass } from "./form";
export function QuestionDocuments({
  data,
  actorId,
  initialSession,
}: {
  data: QuestionWorkspace;
  actorId: string;
  initialSession?: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    [panel, setPanel] = useState<string | null>(null),
    [session, setSession] = useState(initialSession ?? "");
  const fields = (row?: QuestionWorkspace["rows"][number]) => (
    <>
      <label>
        {t("Scheduled class", "নির্ধারিত ক্লাস")}
        <select
          required
          className={inputClass}
          value={row?.session_id ?? session}
          disabled={!!row}
          onChange={(e) => setSession(e.target.value)}
        >
          {!row && (
            <option value="">{t("Select class", "ক্লাস নির্বাচন")}</option>
          )}
          {row ? (
            <option value={row.session_id}>
              {row.batch} · {row.subject} · {row.session_date}
            </option>
          ) : (
            data.sessions.map((s) => (
              <option value={s.id} key={s.id}>
                {s.label}
              </option>
            ))
          )}
        </select>
      </label>
      <label>
        {t(
          "Chapter / topic — select or write",
          "অধ্যায় / টপিক — নির্বাচন বা লিখুন",
        )}
        <input
          required
          minLength={2}
          maxLength={300}
          name="topic"
          list={"topics-" + (row?.id ?? "new")}
          className={inputClass}
          defaultValue={row?.topic}
        />
        <datalist id={"topics-" + (row?.id ?? "new")}>
          {data.sessions
            .find((s) => s.id === (row?.session_id ?? session))
            ?.topics.map((x, i) => (
              <option value={x.title} key={i} />
            ))}
        </datalist>
      </label>
      <label>
        {t("Pages (optional)", "পৃষ্ঠা (ঐচ্ছিক)")}
        <input
          name="page_reference"
          maxLength={100}
          className={inputClass}
          defaultValue={row?.page_reference}
        />
      </label>
      <label>
        {t(
          "Google Docs draft: questions and answers",
          "Google Docs draft: প্রশ্ন ও উত্তর",
        )}
        <input
          name="draft_url"
          required
          type="url"
          className={inputClass}
          defaultValue={row?.draft_url}
        />
      </label>
      {!row && (
        <label>
          {t(
            "Reuse approved set (optional)",
            "অনুমোদিত সেট পুনর্ব্যবহার (ঐচ্ছিক)",
          )}
          <select className={inputClass} name="source_id">
            <option value="">—</option>
            {data.rows
              .filter((r) => r.status === "FINAL")
              .map((r) => (
                <option key={r.id} value={r.id}>
                  {r.subject} · {r.topic}
                </option>
              ))}
          </select>
        </label>
      )}
    </>
  );
  const query = useSearchParams();
  const pageHref = (page: number) => {
    const q = new URLSearchParams(query.toString());
    q.set("page", String(page));
    return "?" + q;
  };
  return (
    <section className="space-y-5">
      <h1 className="text-2xl font-semibold">
        {t("Question preparation & review", "প্রশ্ন প্রস্তুতি ও যাচাই")}
      </h1>
      <p>
        {t(
          "Prepare from your scheduled class. Submit a Google Docs link; admin records academy-owned final question and separate answer-key copies. ERP does not copy or share documents automatically.",
          "নিজের নির্ধারিত ক্লাস থেকে প্রস্তুত করুন। Google Docs link জমা দিন; admin academy-owned final প্রশ্ন ও আলাদা answer key যুক্ত করবেন। ERP নিজে document copy বা share করে না।",
        )}
      </p>
      <nav className="flex flex-wrap gap-2">
        {["ALL", "DRAFT", "SUBMITTED", "RETURNED", "FINAL"].map((s) => (
          <Link
            className="rounded-lg border px-3 py-2"
            key={s}
            href={"?status=" + s}
          >
            {t(
              s,
              (
                {
                  ALL: "সব",
                  DRAFT: "খসড়া",
                  SUBMITTED: "জমা",
                  RETURNED: "সংশোধন",
                  FINAL: "চূড়ান্ত",
                } as Record<string, string>
              )[s],
            )}
          </Link>
        ))}
      </nav>
      {data.sessions.length > 0 && (
        <Button onClick={() => setPanel(panel === "new" ? null : "new")}>
          {t("Prepare class questions", "ক্লাসের প্রশ্ন প্রস্তুত করুন")}
        </Button>
      )}
      {panel === "new" && (
        <DocumentAction
          kind="questions"
          values={{ action: "SAVE", session_id: session }}
          label={t("Save draft", "খসড়া সংরক্ষণ")}
          onSaved={() => setPanel(null)}
        >
          {fields()}
        </DocumentAction>
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              {[
                t("Class / topic", "ক্লাস / টপিক"),
                t("Teacher", "শিক্ষক"),
                t("Status", "অবস্থা"),
                t("Actions", "কাজ"),
              ].map((x) => (
                <th key={x} className="p-3">
                  {x}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => (
              <tr className="border-t" key={r.id}>
                <td className="p-3">
                  {r.batch} · {r.subject} · {r.session_date}
                  <p className="font-semibold">
                    {r.topic} · {r.page_reference}
                  </p>
                  {r.review_note && <p>{r.review_note}</p>}
                </td>
                <td className="p-3">{r.teacher}</td>
                <td className="p-3">{r.status}</td>
                <td className="space-y-2 p-3">
                  <a
                    className="block underline"
                    href={r.draft_url}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {t("Open teacher document", "শিক্ষকের document খুলুন")}
                  </a>
                  {r.status === "FINAL" ? (
                    <>
                      <a
                        className="block underline"
                        target="_blank"
                        rel="noopener noreferrer"
                        href={r.final_question_url!}
                      >
                        {t("Final questions", "চূড়ান্ত প্রশ্ন")}
                      </a>
                      <a
                        className="block underline"
                        target="_blank"
                        rel="noopener noreferrer"
                        href={r.final_answer_url!}
                      >
                        {t("Answer key", "উত্তরমালা")}
                      </a>
                    </>
                  ) : (
                    <>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setPanel(panel === r.id ? null : r.id)}
                      >
                        {t("Open actions", "কাজ খুলুন")}
                      </Button>
                      {panel === r.id && (
                        <div className="min-w-72">
                          {r.author_id === actorId &&
                            ["DRAFT", "RETURNED"].includes(r.status) && (
                              <DocumentAction
                                kind="questions"
                                values={{ action: "SAVE", id: r.id }}
                                label={t("Save correction", "সংশোধন সংরক্ষণ")}
                                onSaved={() => setPanel(null)}
                              >
                                {fields(r)}
                              </DocumentAction>
                            )}
                          {r.author_id === actorId && r.status === "DRAFT" && (
                            <DocumentAction
                              kind="questions"
                              values={{ action: "SUBMIT", id: r.id }}
                              label={t(
                                "Submit for review",
                                "যাচাইয়ের জন্য জমা দিন",
                              )}
                            />
                          )}
                          {data.canReview &&
                            r.author_id !== actorId &&
                            r.status === "SUBMITTED" && (
                              <>
                                <DocumentAction
                                  kind="questions"
                                  values={{ action: "FINALIZE", id: r.id }}
                                  label={t("Finalize", "চূড়ান্ত করুন")}
                                  onSaved={() => setPanel(null)}
                                >
                                  <label>
                                    {t(
                                      "Academy final questions link",
                                      "একাডেমির final প্রশ্নের link",
                                    )}
                                    <input
                                      required
                                      type="url"
                                      name="final_question_url"
                                      className={inputClass}
                                    />
                                  </label>
                                  <label>
                                    {t(
                                      "Separate final answer key link",
                                      "আলাদা final উত্তরমালার link",
                                    )}
                                    <input
                                      required
                                      type="url"
                                      name="final_answer_url"
                                      className={inputClass}
                                    />
                                  </label>
                                  <label>
                                    {t("Review note", "যাচাইয়ের মন্তব্য")}
                                    <input
                                      required
                                      minLength={5}
                                      name="review_note"
                                      className={inputClass}
                                    />
                                  </label>
                                  <label className="flex gap-2">
                                    <input
                                      required
                                      type="checkbox"
                                      name="academy_copy_confirmed"
                                    />
                                    {t(
                                      "Verified academy-owned copies and restricted sharing",
                                      "একাডেমির copy ও সীমিত sharing যাচাই করেছি",
                                    )}
                                  </label>
                                </DocumentAction>
                                <DocumentAction
                                  kind="questions"
                                  values={{ action: "RETURN", id: r.id }}
                                  label={t(
                                    "Return for correction",
                                    "সংশোধনের জন্য ফেরত",
                                  )}
                                  onSaved={() => setPanel(null)}
                                >
                                  <input
                                    aria-label={t(
                                      "Correction note",
                                      "সংশোধনের নির্দেশনা",
                                    )}
                                    required
                                    minLength={5}
                                    name="review_note"
                                    className={inputClass}
                                  />
                                </DocumentAction>
                              </>
                            )}
                        </div>
                      )}
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-4">
            {t(
              "No submissions in this view.",
              "এই তালিকায় কোনো submission নেই।",
            )}
          </p>
        )}
      </div>
      <nav className="flex gap-4">
        {data.page > 1 && (
          <Link href={pageHref(data.page - 1)}>{t("Previous", "আগের")}</Link>
        )}
        <span>
          {data.page} · {data.total}
        </span>
        {data.page * 25 < data.total && (
          <Link href={pageHref(data.page + 1)}>{t("Next", "পরের")}</Link>
        )}
      </nav>
    </section>
  );
}
