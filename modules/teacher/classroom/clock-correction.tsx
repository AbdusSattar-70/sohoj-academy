"use client";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import type { ClassFlow } from "./schema";
const input = "mt-1 min-h-11 w-full rounded-lg border bg-background p-3";
function format(value: string) {
  return new Date(value).toLocaleTimeString("en-GB", {
    timeZone: "Asia/Dhaka",
    hour: "2-digit",
    minute: "2-digit",
  });
}
export function ClockCorrection({
  clock,
  sessionDate,
  disabled,
  onCorrect,
}: {
  clock: NonNullable<ClassFlow["clock"]>;
  sessionDate: string;
  disabled: boolean;
  onCorrect: (start: string, end: string, reason: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  return (
    <details className="rounded-lg border p-3">
      <summary className="cursor-pointer">
        {t(
          "Forgot Start/Finish or need to correct the time?",
          "Start/Finish ভুলে গেছেন বা সময় সংশোধন প্রয়োজন?",
        )}
      </summary>
      <form
        className="mt-3 space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          onCorrect(
            `${sessionDate}T${f.get("start")}:00+06:00`,
            `${sessionDate}T${f.get("end")}:00+06:00`,
            String(f.get("reason")),
          );
        }}
      >
        <fieldset disabled={disabled} className="space-y-3">
          <label className="block">
            {t("Actual start", "প্রকৃত শুরু")}
            <input
              required
              type="time"
              name="start"
              defaultValue={format(clock.started_at)}
              className={input}
            />
          </label>
          <label className="block">
            {t("Actual end", "প্রকৃত শেষ")}
            <input
              required
              type="time"
              name="end"
              defaultValue={clock.ended_at ? format(clock.ended_at) : ""}
              className={input}
            />
          </label>
          <label className="block">
            {t("Correction reason", "সংশোধনের কারণ")}
            <input
              required
              minLength={5}
              maxLength={500}
              name="reason"
              className={input}
            />
          </label>
          <Button type="submit" loading={disabled}>
            {t("Record corrected times", "সংশোধিত সময় সংরক্ষণ")}
          </Button>
        </fieldset>
      </form>
    </details>
  );
}
