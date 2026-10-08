"use client";
import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { runClassLogCommand } from "./actions";
export function ClassLogReview({
  sessionId,
  logId,
}: {
  sessionId: string;
  logId: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    [message, setMessage] = useState(""),
    [pending, start] = useTransition(),
    router = useRouter(),
    attempt = useRef<{ signature: string; id: string } | null>(null);
  return (
    <form
      className="space-y-3 rounded-lg border p-4"
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const signature = JSON.stringify([f.get("decision"), f.get("note")]);
        if (attempt.current?.signature !== signature)
          attempt.current = { signature, id: crypto.randomUUID() };
        const requestId = attempt.current.id;
        start(async () => {
          try {
            const r = await runClassLogCommand({
              action: "DECIDE",
              request_id: requestId,
              session_id: sessionId,
              class_log_id: logId,
              decision: String(f.get("decision")) as "APPROVED" | "REJECTED",
              review_note: String(f.get("note")),
              reason: t(
                "Reviewed actual teaching evidence and duration",
                "বাস্তব পাঠদান ও সময় যাচাই করেছি",
              ),
              unit_progress: [],
              class_summary: "",
              unfinished_reason: "",
              homework: "",
              next_session_plan: "",
            });
            setMessage(r.message);
            if (r.ok) {
              attempt.current = null;
              router.refresh();
            }
          } catch {
            setMessage(
              t(
                "Review result unconfirmed. Keep the same choices and retry to confirm safely.",
                "যাচাইয়ের ফল নিশ্চিত নয়। একই তথ্য রেখে আবার নিশ্চিত করুন।",
              ),
            );
          }
        });
      }}
    >
      <fieldset disabled={pending} className="grid gap-3 sm:grid-cols-2">
        <label>
          {t("Admin review", "প্রশাসকের যাচাই")}
          <select
            name="decision"
            className="mt-1 w-full rounded-lg border bg-background p-3"
          >
            <option value="APPROVED">
              {t("Approve actual teaching", "বাস্তব পাঠদান অনুমোদন")}
            </option>
            <option value="REJECTED">
              {t("Return for correction", "সংশোধনের জন্য ফেরত")}
            </option>
          </select>
        </label>
        <label>
          {t("Review note", "যাচাইয়ের মন্তব্য")}
          <input
            name="note"
            required
            minLength={5}
            maxLength={1000}
            defaultValue={t(
              "Verified teaching topics and actual duration",
              "পড়ানো বিষয় ও বাস্তব সময় যাচাই করেছি",
            )}
            className="mt-1 w-full rounded-lg border bg-background p-3"
          />
        </label>
      </fieldset>
      <Button loading={pending} disabled={pending}>
        {t("Save review", "যাচাই সংরক্ষণ")}
      </Button>
      {message && <p role="status">{message}</p>}
    </form>
  );
}
