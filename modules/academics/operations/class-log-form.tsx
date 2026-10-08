"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { runClassLogCommand } from "./actions";
import type { ClassLogCommand, ClassLogWorkspace } from "./schema";
const cls = "mt-1 min-h-11 w-full rounded-lg border bg-background p-3";
const local = (s: string | null | undefined) =>
  s
    ? new Date(s)
        .toLocaleString("sv-SE", { timeZone: "Asia/Dhaka" })
        .replace(" ", "T")
        .slice(0, 16)
    : "";
export function ClassLogForm({
  sessionId,
  workspace,
}: {
  sessionId: string;
  workspace: ClassLogWorkspace;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter(),
    last = workspace.logs[0],
    [open, setOpen] = useState(false),
    [pending, start] = useTransition(),
    [uncertain, setUncertain] = useState(false),
    [attempt, setAttempt] = useState<ClassLogCommand | null>(null),
    [message, setMessage] = useState(""),
    [progress, setProgress] = useState(
      workspace.units.map((_, unit_index) => ({
        unit_index,
        status:
          last?.unit_progress.find((x) => x.unit_index === unit_index)
            ?.status ??
          ("NOT_COVERED" as "COVERED" | "PARTIAL" | "NOT_COVERED"),
        note:
          last?.unit_progress.find((x) => x.unit_index === unit_index)?.note ??
          "",
      })),
    );
  function send(p: ClassLogCommand) {
    start(async () => {
      try {
        const r = await runClassLogCommand(p);
        setMessage(r.message);
        if (r.ok) {
          setOpen(false);
          setAttempt(null);
          setUncertain(false);
          router.refresh();
        } else {
          const unknown = /unconfirmed|network|fetch failed|timeout/i.test(
            r.message,
          );
          setUncertain(unknown);
          if (!unknown) setAttempt(null);
        }
      } catch {
        setUncertain(true);
        setMessage(
          t(
            "Result unconfirmed; retry the same request.",
            "ফল নিশ্চিত নয়; একই অনুরোধ আবার পাঠান।",
          ),
        );
      }
    });
  }
  return (
    <section className="space-y-4 rounded-xl border p-5">
      <h2 className="font-semibold">
        {t("Actual teaching report", "বাস্তব পাঠদানের রিপোর্ট")}
      </h2>
      <p className="text-sm">
        {t(
          "Save actual start/end times and what was taught. Submit the saved draft; admin reviews it. Scheduled time and academy staff attendance are separate.",
          "বাস্তব শুরুর/শেষের সময় ও কী পড়িয়েছেন লিখে খসড়া রাখুন। খসড়া জমা দিলে প্রশাসক যাচাই করবেন। পরিকল্পিত সময় ও স্টাফের উপস্থিতি আলাদা।",
        )}
      </p>
      {message && (
        <p role="status" className="rounded-lg border p-3">
          {message}
        </p>
      )}
      {last?.status === "SUBMITTED" ? (
        <p>{t("Awaiting admin review.", "প্রশাসকের যাচাই বাকি।")}</p>
      ) : (
        <Button
          type="button"
          disabled={pending || uncertain}
          variant="outline"
          onClick={() => setOpen((o) => !o)}
        >
          {t(
            last ? "Edit / correction report" : "Record teaching",
            last ? "সম্পাদনা / সংশোধিত রিপোর্ট" : "পাঠদান লিখুন",
          )}
        </Button>
      )}
      {open && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            const f = new FormData(e.currentTarget);
            const p: ClassLogCommand = {
              action: "SAVE_DRAFT",
              request_id: crypto.randomUUID(),
              session_id: sessionId,
              reason:
                locale === "bn"
                  ? "বাস্তব পাঠদান ও সময় যাচাই করে লিখেছি"
                  : "Recorded verified actual teaching and times",
              actual_starts_at: String(f.get("start")) + ":00+06:00",
              actual_ends_at: String(f.get("end")) + ":00+06:00",
              class_summary: String(f.get("summary")),
              unfinished_reason: String(f.get("unfinished") ?? ""),
              homework: String(f.get("homework") ?? ""),
              next_session_plan: String(f.get("next") ?? ""),
              unit_progress: progress,
            };
            setAttempt(p);
            send(p);
          }}
          className="space-y-4"
        >
          <fieldset
            disabled={pending || uncertain}
            className="grid gap-4 sm:grid-cols-2"
          >
            <label>
              {t(
                "Actual start · Bangladesh time",
                "বাস্তব শুরু · বাংলাদেশ সময়",
              )}
              <input
                name="start"
                type="datetime-local"
                required
                defaultValue={local(last?.actual_starts_at)}
                className={cls}
              />
            </label>
            <label>
              {t("Actual end", "বাস্তব শেষ")}
              <input
                name="end"
                type="datetime-local"
                required
                defaultValue={local(last?.actual_ends_at)}
                className={cls}
              />
            </label>
            {workspace.units.map((u, i) => (
              <label key={i}>
                {u.title}
                <select
                  className={cls}
                  value={progress[i].status}
                  onChange={(e) =>
                    setProgress((p) =>
                      p.map((x, n) =>
                        n === i
                          ? { ...x, status: e.target.value as typeof x.status }
                          : x,
                      ),
                    )
                  }
                >
                  <option value="NOT_COVERED">
                    {t("Not covered", "পড়ানো হয়নি")}
                  </option>
                  <option value="PARTIAL">{t("Partial", "আংশিক")}</option>
                  <option value="COVERED">{t("Covered", "পড়ানো হয়েছে")}</option>
                </select>
              </label>
            ))}
            <label className="sm:col-span-2">
              {t("What was taught?", "কী পড়িয়েছেন?")}
              <textarea
                name="summary"
                required
                minLength={2}
                maxLength={4000}
                defaultValue={last?.class_summary}
                className={cls}
              />
            </label>
            <label>
              {t("Reason for incomplete topics", "অসম্পূর্ণ পাঠের কারণ")}
              <textarea
                name="unfinished"
                required={progress.some((x) => x.status !== "COVERED")}
                maxLength={2000}
                defaultValue={last?.unfinished_reason}
                className={cls}
              />
            </label>
            <label>
              {t("Homework / practice", "বাড়ির কাজ / অনুশীলন")}
              <textarea
                name="homework"
                maxLength={2000}
                defaultValue={last?.homework}
                className={cls}
              />
            </label>
            <label>
              {t("Next class plan", "পরবর্তী ক্লাসের পরিকল্পনা")}
              <textarea
                name="next"
                maxLength={2000}
                defaultValue={last?.next_session_plan}
                className={cls}
              />
            </label>
          </fieldset>
          {uncertain ? (
            <Button
              type="button"
              loading={pending}
              disabled={pending}
              onClick={() => attempt && send(attempt)}
            >
              {t("Confirm previous request", "আগের অনুরোধ নিশ্চিত করুন")}
            </Button>
          ) : (
            <Button loading={pending} disabled={pending} type="submit">
              {t("Save draft", "খসড়া রাখুন")}
            </Button>
          )}
        </form>
      )}
      {last?.status === "DRAFT" && !open && (
        <Button
          loading={pending}
          disabled={pending}
          onClick={() => {
            const p: ClassLogCommand = {
              action: "SUBMIT",
              request_id: crypto.randomUUID(),
              session_id: sessionId,
              reason: t(
                "Submitted saved teaching evidence for admin review",
                "সংরক্ষিত পাঠদানের রিপোর্ট যাচাইয়ের জন্য জমা দিলাম",
              ),
              unit_progress: [],
              class_summary: "",
              unfinished_reason: "",
              homework: "",
              next_session_plan: "",
            };
            setAttempt(p);
            send(p);
          }}
        >
          {t("Submit saved report", "সংরক্ষিত রিপোর্ট জমা দিন")}
        </Button>
      )}
      {uncertain && !open && (
        <Button disabled={pending} onClick={() => attempt && send(attempt)}>
          {t("Confirm previous request", "আগের অনুরোধ নিশ্চিত করুন")}
        </Button>
      )}
    </section>
  );
}
