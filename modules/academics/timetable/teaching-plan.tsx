"use client";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { createTimetableTeachingPlan } from "./actions";
export function InlineTeachingPlan({
  batchId,
  subjectId,
  subjectName,
  from,
  through,
  onDone,
}: {
  batchId: string;
  subjectId: string;
  subjectName: string;
  from: string;
  through: string;
  onDone: (id?: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [title, setTitle] = useState(
      subjectName + t(" teaching plan", " পাঠ পরিকল্পনা"),
    ),
    [units, setUnits] = useState([{ title: "", target_date: from }]),
    [busy, setBusy] = useState(false),
    [message, setMessage] = useState(""),
    [retry, setRetry] = useState<
      Parameters<typeof createTimetableTeachingPlan>[0] | null
    >(null);
  async function submit(input: unknown) {
    setBusy(true);
    setMessage("");
    try {
      const r = await createTimetableTeachingPlan(input);
      if (r.ok) onDone(r.id);
      else {
        setMessage(r.message);
        setRetry(r.uncertain ? input : null);
      }
    } catch {
      setRetry(input);
      setMessage(
        t(
          "Result unconfirmed. Retry the same request.",
          "ফল নিশ্চিত নয়। একই অনুরোধ নিশ্চিত করুন।",
        ),
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <form
      className="space-y-3 rounded-xl border p-4"
      data-editor
      data-busy={busy || !!retry}
      data-dirty={units.some((u) => u.title.trim())}
      onSubmit={(e) => {
        e.preventDefault();
        submit({
          request_id: crypto.randomUUID(),
          batch_id: batchId,
          subject_id: subjectId,
          title,
          units,
          locale,
        });
      }}
    >
      <h3 className="font-semibold">
        {subjectName} ·{" "}
        {t("Dated teaching topics", "তারিখভিত্তিক পাঠ পরিকল্পনা")}
      </h3>
      <p className="text-sm text-muted-foreground">
        {t(
          "Select the intended class date for each topic. The teacher sees topics targeted for that class date; an unfinished topic is recorded separately.",
          "প্রতি পাঠের জন্য নির্ধারিত ক্লাসের তারিখ দিন। শিক্ষক সেই দিনের পাঠ দেখবেন; অসম্পূর্ণ পাঠ আলাদাভাবে রেকর্ড হবে।",
        )}
      </p>
      <fieldset disabled={busy || !!retry} className="space-y-3">
        <label className="block">
          {t("Plan title", "পরিকল্পনার নাম")}
          <input
            autoFocus
            required
            minLength={2}
            maxLength={200}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="min-h-11 w-full rounded-lg border bg-background p-2"
          />
        </label>
        {units.map((u, i) => (
          <div className="grid gap-3 sm:grid-cols-[1fr_auto_auto]" key={i}>
            <label>
              {t("Chapter / topic", "অধ্যায় / পাঠ")} {i + 1}
              <input
                required
                minLength={2}
                maxLength={200}
                value={u.title}
                onChange={(e) =>
                  setUnits((v) =>
                    v.map((x, n) =>
                      n === i ? { ...x, title: e.target.value } : x,
                    ),
                  )
                }
                className="min-h-11 w-full rounded-lg border bg-background p-2"
              />
            </label>
            <label>
              {t("Class date", "ক্লাসের তারিখ")}
              <input
                required
                type="date"
                min={from}
                max={through}
                value={u.target_date}
                onChange={(e) =>
                  setUnits((v) =>
                    v.map((x, n) =>
                      n === i ? { ...x, target_date: e.target.value } : x,
                    ),
                  )
                }
                className="min-h-11 w-full rounded-lg border bg-background p-2"
              />
            </label>
            <Button
              type="button"
              variant="outline"
              disabled={units.length === 1}
              onClick={() => setUnits((v) => v.filter((_, n) => n !== i))}
            >
              {t("Remove", "বাদ দিন")}
            </Button>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          disabled={units.length >= 200}
          onClick={() =>
            setUnits((v) => [...v, { title: "", target_date: from }])
          }
        >
          {t("Add topic", "পাঠ যোগ")}
        </Button>
        <Button type="submit">
          {t("Save and select plan", "সংরক্ষণ ও নির্বাচন")}
        </Button>
      </fieldset>
      {(busy || message) && (
        <p role="status">{busy ? t("Saving…", "সংরক্ষণ হচ্ছে…") : message}</p>
      )}
      {retry !== null && (
        <Button disabled={busy} type="button" onClick={() => submit(retry)}>
          {t("Confirm same request", "একই অনুরোধ নিশ্চিত করুন")}
        </Button>
      )}
      <Button
        disabled={busy || !!retry}
        type="button"
        variant="outline"
        onClick={() => {
          if (
            !units.some((u) => u.title.trim()) ||
            window.confirm(
              t("Discard unsaved topics?", "অসংরক্ষিত পাঠ বাদ দেবেন?"),
            )
          )
            onDone();
        }}
      >
        {t("Cancel", "বাতিল")}
      </Button>
    </form>
  );
}
