"use client";
import Link from "next/link";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { getReportStudentChoices } from "./actions";
import { useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import type { ProgressWorkspace, ReportRow } from "./schema";
import { DocumentAction, inputClass } from "./form";
export function ReportPaper({ report: r }: { report: ReportRow }) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    s = r.snapshot,
    counts = s.attendance.reduce(
      (a, x) => ({ ...a, [x.status]: (a[x.status] ?? 0) + 1 }),
      {} as Record<string, number>,
    ),
    total = (counts.PRESENT ?? 0) + (counts.LATE ?? 0) + (counts.ABSENT ?? 0),
    pct = total
      ? Math.round((((counts.PRESENT ?? 0) + (counts.LATE ?? 0)) / total) * 100)
      : null;
  return (
    <article className="progress-paper space-y-5 rounded-xl border bg-card p-5">
      <header className="border-b pb-3">
        <h2 className="text-xl font-semibold">
          {t("Student Progress Report", "শিক্ষার্থীর অগ্রগতি প্রতিবেদন")}
        </h2>
        <p>
          {r.status === "FINAL"
            ? t("Final approved report", "চূড়ান্ত অনুমোদিত প্রতিবেদন")
            : t("Draft preview — not final", "খসড়া preview — চূড়ান্ত নয়")}
        </p>
      </header>
      <div className="grid grid-cols-2 gap-2 text-sm">
        <p>
          <strong>{s.student.name}</strong> · {s.student.number}
        </p>
        <p>
          {s.student.batch} · {s.student.programme}
        </p>
        <p>
          {s.student.startsOn} — {s.student.endsOn}
        </p>
        <p>
          {t("Evidence captured", "তথ্য সংরক্ষণের সময়")}:{" "}
          {new Date(s.student.generatedAt).toLocaleString(
            locale === "bn" ? "bn-BD" : "en-GB",
            { timeZone: "Asia/Dhaka" },
          )}
        </p>
      </div>
      <section>
        <h3 className="font-semibold">
          {t("Approved attendance", "অনুমোদিত উপস্থিতি")}
        </h3>
        <p>
          {t("Present", "উপস্থিত")}: {counts.PRESENT ?? 0} ·{" "}
          {t("Late", "দেরিতে")}: {counts.LATE ?? 0} · {t("Absent", "অনুপস্থিত")}
          : {counts.ABSENT ?? 0} · {t("Excused", "অনুমতিসহ অনুপস্থিত")}:{" "}
          {counts.EXCUSED ?? 0} ·{" "}
          {pct === null
            ? t("No approved attendance", "অনুমোদিত attendance নেই")
            : pct + "%"}
        </p>
        <p className="text-xs">
          {t(
            "Excused attendance is excluded from the percentage denominator.",
            "অনুমতিসহ অনুপস্থিতি শতাংশের denominator থেকে বাদ।",
          )}
        </p>
      </section>
      <section>
        <h3 className="font-semibold">
          {t("Approved assessment results", "অনুমোদিত পরীক্ষার ফল")}
        </h3>
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              {[
                t("Date / subject", "তারিখ / বিষয়"),
                t("Assessment", "পরীক্ষা"),
                t("Marks", "নম্বর"),
                t("Feedback", "মন্তব্য"),
              ].map((x) => (
                <th className="border-b py-2" key={x}>
                  {x}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {s.assessments.map((a) => (
              <tr key={a.assessmentId}>
                <td className="py-2">
                  {a.date} · {a.subject}
                </td>
                <td>{a.title}</td>
                <td>
                  {a.score}/{a.maxMarks}
                </td>
                <td>{a.feedback}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!s.assessments.length ? (
          <p>
            {t(
              "No approved results in this period. Missing results are not zero marks.",
              "এই সময়ে অনুমোদিত ফল নেই। Missing result শূন্য নম্বর নয়।",
            )}
          </p>
        ) : (
          <p className="mt-2 font-semibold">
            {t("Total approved marks", "মোট অনুমোদিত নম্বর")}: {s.scoreTotal}/
            {s.maxTotal} ·{" "}
            {s.maxTotal
              ? (((s.scoreTotal ?? 0) / s.maxTotal) * 100).toFixed(1) + "%"
              : "—"}
          </p>
        )}
      </section>
      <section>
        <h3 className="font-semibold">
          {t(
            "Teaching progress & homework set",
            "পাঠের অগ্রগতি ও দেওয়া বাড়ির কাজ",
          )}
        </h3>
        {s.coverage.map((c) => (
          <div className="border-b py-2 text-sm" key={c.sessionId}>
            <p>
              {c.date} · {c.subject} — {c.summary}
            </p>
            {c.progress.map((u, i) => (
              <p key={i}>
                {u.title ?? "—"}:{" "}
                {t(
                  u.status,
                  (
                    {
                      COVERED: "সম্পন্ন",
                      PARTIAL: "আংশিক",
                      NOT_COVERED: "পড়ানো হয়নি",
                    } as Record<string, string>
                  )[u.status] ?? u.status,
                )}
                {u.note ? " · " + u.note : ""}
              </p>
            ))}
            {c.homeworkStatus && (
              <p>
                {t("Homework check", "বাড়ির কাজ যাচাই")}:{" "}
                {t(
                  c.homeworkStatus,
                  (
                    {
                      COMPLETE: "সম্পন্ন",
                      NEEDS_WORK: "সংশোধন প্রয়োজন",
                      NOT_SUBMITTED: "জমা হয়নি",
                    } as Record<string, string>
                  )[c.homeworkStatus] ?? c.homeworkStatus,
                )}
                {c.homeworkFeedback ? " · " + c.homeworkFeedback : ""}
              </p>
            )}
            {c.homework && (
              <p>
                {t("Homework set", "দেওয়া বাড়ির কাজ")}: {c.homework}
              </p>
            )}
          </div>
        ))}
        {!s.coverage.length && (
          <p>
            {t("No approved teaching report.", "অনুমোদিত পাঠদান report নেই।")}
          </p>
        )}
      </section>
      <section>
        <h3 className="font-semibold">
          {t("Teacher comment", "শিক্ষকের মন্তব্য")}
        </h3>
        <p className="whitespace-pre-wrap">{r.teacher_comment || "—"}</p>
        <p>
          {t("Home support", "বাড়িতে সহায়তা")}:{" "}
          {r.home_support
            .map((x) =>
              t(
                x.replaceAll("_", " "),
                (
                  {
                    DAILY_READING: "প্রতিদিন পড়া",
                    HOMEWORK_SUPPORT: "বাড়ির কাজে সহায়তা",
                    REGULAR_ATTENDANCE: "নিয়মিত উপস্থিতি",
                    GUARDIAN_MEETING: "অভিভাবক সাক্ষাৎ",
                  } as Record<string, string>
                )[x],
              ),
            )
            .join(" · ") || "—"}
        </p>
        {r.review_note && (
          <p>
            {t("Administrator note", "প্রশাসকের মন্তব্য")}: {r.review_note}
          </p>
        )}
      </section>
      <footer className="grid grid-cols-2 gap-6 border-t pt-4 text-sm">
        <p>
          {t("Prepared by", "প্রস্তুত করেছেন")}: {r.author_name}
        </p>
        <p>
          {t("Reviewed by", "যাচাই করেছেন")}: {r.reviewer_name ?? "—"}
        </p>
        <p className="pt-5">
          {t("Student signature", "শিক্ষার্থীর স্বাক্ষর")}: __________________
        </p>
        <p className="pt-5">
          {t("Guardian signature", "অভিভাবকের স্বাক্ষর")}: __________________
        </p>
      </footer>
    </article>
  );
}
export function ProgressReports({
  data,
  actorId,
}: {
  data: ProgressWorkspace;
  actorId: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    [panel, setPanel] = useState<string | null>(null),
    [batch, setBatch] = useState(""),
    [choices, setChoices] = useState<{ id: string; label: string }[]>([]),
    [search, setSearch] = useState(""),
    [choicePage, setChoicePage] = useState(1),
    [hasMore, setHasMore] = useState(false),
    [loadingChoices, setLoadingChoices] = useState(false),
    [choiceMessage, setChoiceMessage] = useState(""),
    query = useSearchParams(),
    today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Dhaka" }).format(
      new Date(),
    );
  const pageHref = (page: number) => {
    const q = new URLSearchParams(query.toString());
    q.set("page", String(page));
    return "?" + q;
  };
  async function loadChoices(selected: string, term = "", page = 1) {
    setLoadingChoices(true);
    setChoiceMessage("");
    setChoices([]);
    try {
      const result = await getReportStudentChoices(selected, term, page);
      if (!result.ok) {
        setChoiceMessage(result.message);
        return;
      }
      setChoices(result.rows);
      setHasMore(result.more);
      setChoicePage(page);
    } catch {
      setChoiceMessage(
        t(
          "Could not load students. Try again.",
          "শিক্ষার্থী তালিকা পাওয়া যায়নি। আবার চেষ্টা করুন।",
        ),
      );
    } finally {
      setLoadingChoices(false);
    }
  }
  return (
    <section className="space-y-5">
      <h1 className="text-2xl font-semibold">
        {t("Student progress reports", "শিক্ষার্থীর অগ্রগতি প্রতিবেদন")}
      </h1>
      <p>
        {t(
          "Generate from approved academic evidence, add comments, submit for review and print the final report. Drafts and missing results are not counted as zero.",
          "অনুমোদিত academic evidence থেকে তৈরি করুন, মন্তব্য দিন, review-এর জন্য জমা দিন ও final report print করুন। খসড়া বা missing result শূন্য হিসেবে গণনা হয় না।",
        )}
      </p>
      <nav className="flex flex-wrap gap-2">
        {["ALL", "DRAFT", "SUBMITTED", "RETURNED", "FINAL"].map((s) => (
          <Link
            className="rounded-lg border px-3 py-2"
            href={"?status=" + s}
            key={s}
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
      <Button onClick={() => setPanel(panel === "new" ? null : "new")}>
        {t("Generate report preview", "Report preview তৈরি")}
      </Button>
      {panel === "new" && (
        <DocumentAction
          kind="progress"
          values={{ action: "GENERATE", batch_id: batch }}
          label={t("Generate preview", "Preview তৈরি")}
          onSaved={() => setPanel(null)}
        >
          <label>
            {t("Batch", "ব্যাচ")}
            <select
              className={inputClass}
              required
              value={batch}
              disabled={loadingChoices}
              onChange={(e) => {
                setBatch(e.target.value);
                setSearch("");
                if (e.target.value) void loadChoices(e.target.value);
                else setChoices([]);
              }}
            >
              <option value="">—</option>
              {data.batches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.label}
                </option>
              ))}
            </select>
          </label>
          <label>
            {t("Student", "শিক্ষার্থী")}
            <select
              key={batch}
              name="student_id"
              className={inputClass}
              required
              disabled={loadingChoices || !batch}
            >
              <option value="">—</option>
              {choices.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          {batch && (
            <div className="space-y-2">
              <label>
                {t(
                  "Find student by name or ID",
                  "নাম বা ID দিয়ে শিক্ষার্থী খুঁজুন",
                )}
                <input
                  className={inputClass}
                  value={search}
                  maxLength={100}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </label>
              <Button
                type="button"
                variant="outline"
                loading={loadingChoices}
                onClick={() => void loadChoices(batch, search)}
              >
                {t("Search", "খুঁজুন")}
              </Button>
              {choicePage > 1 && (
                <Button
                  type="button"
                  variant="outline"
                  disabled={loadingChoices}
                  onClick={() =>
                    void loadChoices(batch, search, choicePage - 1)
                  }
                >
                  {t("Previous", "আগের")}
                </Button>
              )}
              {hasMore && (
                <Button
                  type="button"
                  variant="outline"
                  disabled={loadingChoices}
                  onClick={() =>
                    void loadChoices(batch, search, choicePage + 1)
                  }
                >
                  {t("Next", "পরের")}
                </Button>
              )}
              {choiceMessage && <p role="status">{choiceMessage}</p>}
            </div>
          )}
          <div className="grid grid-cols-2 gap-3">
            <label>
              {t("From", "শুরু")}
              <input
                name="starts_on"
                type="date"
                required
                max={today}
                defaultValue={today.slice(0, 8) + "01"}
                className={inputClass}
              />
            </label>
            <label>
              {t("Through", "শেষ")}
              <input
                name="ends_on"
                type="date"
                required
                max={today}
                defaultValue={today}
                className={inputClass}
              />
            </label>
          </div>
        </DocumentAction>
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              {[
                t("Student / batch", "শিক্ষার্থী / ব্যাচ"),
                t("Period", "সময়"),
                t("Status", "অবস্থা"),
                t("Action", "কাজ"),
              ].map((x) => (
                <th className="p-3" key={x}>
                  {x}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="p-3">
                  {r.snapshot.student.name} · {r.snapshot.student.number}
                  <p>{r.snapshot.student.batch}</p>
                </td>
                <td className="p-3">
                  {r.snapshot.student.startsOn} — {r.snapshot.student.endsOn}
                </td>
                <td className="p-3">{r.status}</td>
                <td className="p-3">
                  <Button
                    variant="outline"
                    onClick={() => setPanel(panel === r.id ? null : r.id)}
                  >
                    {t("View / actions", "দেখুন / কাজ")}
                  </Button>
                  {r.status === "FINAL" && (
                    <Link
                      className="ml-3 underline"
                      href={"/dashboard/academics/progress/" + r.id + "/print"}
                    >
                      {t("Print", "প্রিন্ট")}
                    </Link>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-4">
            {t("No reports in this view.", "এই তালিকায় report নেই।")}
          </p>
        )}
      </div>
      {data.rows
        .filter((r) => r.id === panel)
        .map((r) => (
          <div key={r.id} className="space-y-4">
            <ReportPaper report={r} />
            {r.author_id === actorId &&
              ["DRAFT", "RETURNED"].includes(r.status) && (
                <DocumentAction
                  kind="progress"
                  values={{ action: "SAVE", id: r.id }}
                  label={t(
                    "Save comments / refresh evidence",
                    "মন্তব্য সংরক্ষণ / তথ্য হালনাগাদ",
                  )}
                >
                  <label>
                    {t("Teacher comment", "শিক্ষকের মন্তব্য")}
                    <textarea
                      name="teacher_comment"
                      maxLength={2000}
                      className={inputClass}
                      defaultValue={r.teacher_comment}
                    />
                  </label>
                  {[
                    "DAILY_READING",
                    "HOMEWORK_SUPPORT",
                    "REGULAR_ATTENDANCE",
                    "GUARDIAN_MEETING",
                  ].map((s) => (
                    <label className="flex gap-2" key={s}>
                      <input
                        type="checkbox"
                        name="home_support"
                        value={s}
                        defaultChecked={r.home_support.includes(s)}
                      />
                      {t(
                        s.replaceAll("_", " "),
                        (
                          {
                            DAILY_READING: "প্রতিদিন পড়া",
                            HOMEWORK_SUPPORT: "বাড়ির কাজে সহায়তা",
                            REGULAR_ATTENDANCE: "নিয়মিত উপস্থিতি",
                            GUARDIAN_MEETING: "অভিভাবক সাক্ষাৎ",
                          } as Record<string, string>
                        )[s],
                      )}
                    </label>
                  ))}
                </DocumentAction>
              )}
            {r.author_id === actorId && r.status === "DRAFT" && (
              <DocumentAction
                kind="progress"
                values={{ action: "SUBMIT", id: r.id }}
                label={t("Submit for review", "যাচাইয়ের জন্য জমা দিন")}
              />
            )}
            {data.canReview &&
              ((r.status === "SUBMITTED" && r.author_id !== actorId) ||
                (["DRAFT", "SUBMITTED"].includes(r.status) &&
                  r.author_id === actorId &&
                  data.canFinalizeOwn)) && (
                <>
                  <DocumentAction
                    kind="progress"
                    values={{ action: "FINALIZE", id: r.id }}
                    label={t(
                      "Refresh approved evidence & finalize",
                      "অনুমোদিত তথ্য হালনাগাদ ও চূড়ান্ত করুন",
                    )}
                  >
                    <input
                      className={inputClass}
                      required
                      name="review_note"
                      minLength={5}
                      maxLength={1000}
                      aria-label={t("Review note", "যাচাইয়ের মন্তব্য")}
                    />
                  </DocumentAction>
                  {r.status === "SUBMITTED" && (
                    <DocumentAction
                      kind="progress"
                      values={{ action: "RETURN", id: r.id }}
                      label={t("Return for correction", "সংশোধনের জন্য ফেরত")}
                    >
                      <input
                        required
                        minLength={5}
                        maxLength={1000}
                        name="review_note"
                        className={inputClass}
                        aria-label={t("Correction note", "সংশোধনের নির্দেশনা")}
                      />
                    </DocumentAction>
                  )}
                </>
              )}
          </div>
        ))}
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
