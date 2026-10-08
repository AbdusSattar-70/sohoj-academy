"use client";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import type {
  ClassLogWorkspace,
  SessionWorkspace,
} from "@/modules/academics/operations/schema";
import type { ClassCommand, ClassFlow } from "./schema";
const input = "mt-1 min-h-11 w-full rounded-lg border bg-background p-3";
export function useTeachingDetails(
  data: SessionWorkspace,
  logs: ClassLogWorkspace,
) {
  const last = logs.logs[0];
  const [dirty, setDirty] = useState(false);
  const [summary, setSummary] = useState(
      last?.class_summary ?? data.session.scope,
    ),
    [homework, setHomework] = useState(last?.homework ?? ""),
    [homeworkKind, setHomeworkKind] = useState(
      last?.homework ? "CUSTOM" : "NONE",
    ),
    [unfinished, setUnfinished] = useState(last?.unfinished_reason ?? ""),
    [next, setNext] = useState(last?.next_session_plan ?? "");
  const todayUnits = logs.units
    .map((u, index) => ({ ...u, index }))
    .filter((u) => u.target_date === data.session.date);
  const [progress, setProgress] = useState(
    todayUnits.map(
      (u) =>
        last?.unit_progress.find((p) => p.unit_index === u.index) ?? {
          unit_index: u.index,
          status: "NOT_COVERED" as "COVERED" | "PARTIAL" | "NOT_COVERED",
          note: "",
        },
    ),
  );
  return {
    summary,
    setSummary,
    homework,
    setHomework,
    homeworkKind,
    setHomeworkKind,
    unfinished,
    setUnfinished,
    next,
    setNext,
    todayUnits,
    progress,
    setProgress,
    dirty,
    setDirty,
  };
}
export function TeachingReport({
  data,
  clock,
  step,
  pending,
  uncertain,
  details,
  command,
  send,
  setStep,
}: {
  data: SessionWorkspace;
  clock: NonNullable<ClassFlow["clock"]>;
  step: number;
  pending: boolean;
  uncertain: boolean;
  details: ReturnType<typeof useTeachingDetails>;
  command: (action: ClassCommand["action"]) => ClassCommand;
  send: (p: ClassCommand, next?: number) => void;
  setStep: (n: number) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const {
    summary,
    setSummary,
    homework,
    setHomework,
    homeworkKind,
    setHomeworkKind,
    unfinished,
    setUnfinished,
    next,
    setNext,
    todayUnits,
    progress,
    setProgress,
    dirty,
    setDirty,
  } = details;
  return (
    <form
      hidden={step < 2}
      className="space-y-4"
      data-editor
      data-dirty={dirty ? "true" : "false"}
      data-busy={pending || uncertain ? "true" : "false"}
      onSubmit={(e) => {
        e.preventDefault();
        send({
          ...command("SUBMIT_REPORT"),
          class_summary: summary,
          unit_progress: progress,
          unfinished_reason: unfinished,
          homework: homeworkKind === "NONE" ? "" : homework,
          next_session_plan: next,
        });
      }}
    >
      <fieldset disabled={pending || uncertain} className="space-y-4">
        <div hidden={step !== 2 && step !== 4} className="space-y-3">
          <h3 className="font-semibold">
            {t("Today’s assigned topics", "আজকের নির্ধারিত পাঠ")}
          </h3>
          <p>{data.session.scope}</p>
          {todayUnits.length === 0 && (
            <p className="text-sm text-muted-foreground">
              {t(
                "No dated curriculum topic is assigned today. Confirm or edit the scheduled scope below; the system will not assume that all curriculum units were covered.",
                "আজকের তারিখে curriculum topic নির্ধারিত নেই। নিচে scheduled scope নিশ্চিত বা সংশোধন করুন; সব অধ্যায় পড়ানো হয়েছে ধরে নেওয়া হবে না।",
              )}
            </p>
          )}
          {todayUnits.map((u, i) => (
            <label key={u.index} className="block">
              {u.title}
              <select
                className={input}
                value={progress[i].status}
                onChange={(e) => {
                  setDirty(true);
                  setProgress((p) =>
                    p.map((x, n) =>
                      n === i
                        ? {
                            ...x,
                            status: e.target.value as typeof x.status,
                          }
                        : x,
                    ),
                  );
                }}
              >
                <option value="NOT_COVERED">
                  {t("Not taught", "পড়ানো হয়নি")}
                </option>
                <option value="PARTIAL">
                  {t("Partly taught", "আংশিক পড়ানো")}
                </option>
                <option value="COVERED">{t("Completed", "সম্পন্ন")}</option>
              </select>
            </label>
          ))}
          <label className="block">
            {t("Confirmed teaching summary", "নিশ্চিত পাঠদানের বিবরণ")}
            <textarea
              required
              minLength={2}
              maxLength={4000}
              className={input}
              value={summary}
              onChange={(e) => {
                setDirty(true);
                setSummary(e.target.value);
              }}
            />
          </label>
          {progress.some((p) => p.status !== "COVERED") && (
            <label className="block">
              {t("Why are topics incomplete?", "পাঠ অসম্পূর্ণ কেন?")}
              <select
                className={input}
                value={
                  [
                    "Students need more practice",
                    "Class time was insufficient",
                    "Topic will continue next class",
                    "",
                  ].includes(unfinished)
                    ? unfinished
                    : "OTHER"
                }
                onChange={(e) => {
                  setDirty(true);
                  setUnfinished(
                    e.target.value === "OTHER" ? "Other: " : e.target.value,
                  );
                }}
              >
                <option value="">{t("Choose reason", "কারণ নির্বাচন")}</option>
                <option value="Students need more practice">
                  {t("Students need more practice", "আরও অনুশীলন প্রয়োজন")}
                </option>
                <option value="Class time was insufficient">
                  {t("Class time was insufficient", "ক্লাসের সময় যথেষ্ট হয়নি")}
                </option>
                <option value="Topic will continue next class">
                  {t("Continue next class", "পরের ক্লাসে চালানো হবে")}
                </option>
                <option value="OTHER">
                  {t("Other — write", "অন্য কারণ — লিখুন")}
                </option>
              </select>
              <input
                required
                maxLength={2000}
                aria-label={t(
                  "Incomplete topic reason",
                  "অসম্পূর্ণ পাঠের কারণ",
                )}
                className={input}
                value={unfinished}
                onChange={(e) => {
                  setDirty(true);
                  setUnfinished(e.target.value);
                }}
              />
            </label>
          )}
          {step === 2 && (
            <Button type="button" onClick={() => setStep(3)}>
              {t(
                "Next — homework & finish",
                "পরের ধাপ — বাড়ির কাজ ও ক্লাস শেষ",
              )}
            </Button>
          )}
        </div>
        <div hidden={step !== 3 && step !== 4} className="space-y-3">
          <label className="block">
            {t("Homework", "বাড়ির কাজ")}
            <select
              className={input}
              value={homeworkKind}
              onChange={(e) => {
                setDirty(true);
                setHomeworkKind(e.target.value);
                if (e.target.value === "NONE") setHomework("");
              }}
            >
              <option value="NONE">
                {t("No homework today", "আজ বাড়ির কাজ নেই")}
              </option>
              <option value="PRACTICE">
                {t("Practice exercises", "অনুশীলনী")}
              </option>
              <option value="READING">
                {t("Reading preparation", "পড়ে আসবে")}
              </option>
              <option value="CUSTOM">
                {t("Details / Google Docs link", "বিবরণ / Google Docs link")}
              </option>
            </select>
          </label>
          {homeworkKind !== "NONE" && (
            <label className="block">
              {t(
                "Homework details / pages / link",
                "বাড়ির কাজের বিবরণ / পৃষ্ঠা / link",
              )}
              <textarea
                required
                maxLength={2000}
                className={input}
                value={homework}
                onChange={(e) => {
                  setDirty(true);
                  setHomework(e.target.value);
                }}
              />
            </label>
          )}
          <label className="block">
            {t(
              "Next class plan (optional)",
              "পরবর্তী ক্লাসের পরিকল্পনা (ঐচ্ছিক)",
            )}
            <input
              maxLength={2000}
              className={input}
              value={next}
              onChange={(e) => {
                setDirty(true);
                setNext(e.target.value);
              }}
            />
          </label>
          {!clock.ended_at && (
            <>
              <p className="text-sm">
                {t(
                  "Finish records the actual end. Review and submit your report next.",
                  "Finish প্রকৃত শেষ সময় নেবে। তারপর রিপোর্ট যাচাই করে জমা দিন।",
                )}
              </p>
              <Button
                type="button"
                loading={pending}
                onClick={() => send(command("END"), 4)}
              >
                {t("Finish my class now", "এখন ক্লাস শেষ করুন")}
              </Button>
            </>
          )}
        </div>
        {step === 4 && clock.ended_at && (
          <div className="space-y-3">
            <p>
              {t(
                "Review student attendance, covered topics, homework and actual time. Submission sends attendance and teaching evidence together; it does not approve either.",
                "শিক্ষার্থীর উপস্থিতি, পড়ানো পাঠ, বাড়ির কাজ ও প্রকৃত সময় যাচাই করুন। Submit করলে উপস্থিতি ও পাঠদানের তথ্য একসঙ্গে review-এ যাবে; কোনোটি স্বয়ংক্রিয় অনুমোদন হবে না।",
              )}
            </p>
            <label className="flex gap-2">
              <input type="checkbox" required />
              {t(
                "I checked the saved student attendance and actual class report.",
                "সংরক্ষিত শিক্ষার্থীর উপস্থিতি ও বাস্তব ক্লাস রিপোর্ট যাচাই করেছি।",
              )}
            </label>
            <div className="flex flex-wrap gap-3">
              <Button
                type="button"
                variant="outline"
                loading={pending}
                onClick={() =>
                  send({
                    ...command("SAVE_REPORT"),
                    class_summary: summary,
                    unit_progress: progress,
                    unfinished_reason: unfinished,
                    homework: homeworkKind === "NONE" ? "" : homework,
                    next_session_plan: next,
                  })
                }
              >
                {t("Save report draft", "রিপোর্টের খসড়া রাখুন")}
              </Button>
              <Button type="submit" loading={pending}>
                {t(
                  "Submit class report to admin",
                  "ক্লাস রিপোর্ট admin-এর কাছে জমা দিন",
                )}
              </Button>
            </div>
          </div>
        )}
      </fieldset>
    </form>
  );
}
