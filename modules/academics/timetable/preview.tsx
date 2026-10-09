"use client";
import { useLanguage } from "@/components/providers/language-provider";
import { StatusBadge } from "@/components/erp/status-badge";
import type { PlanningData } from "../planning/schema";
import type { TimetableInput, TimetablePreview } from "./schema";
function compact(items: { row: number; message: string }[]) {
  const grouped = new Map<string, Set<number>>();
  for (const item of items) {
    const message = item.message.replace(/^\d{4}-\d{2}-\d{2}: /, "");
    if (!grouped.has(message)) grouped.set(message, new Set());
    grouped.get(message)!.add(item.row);
  }
  return [...grouped].map(([message, rows]) => ({ message, rows: [...rows] }));
}
export function TimetablePreviewPanel({
  preview,
  slots,
  data,
}: {
  preview: TimetablePreview;
  slots: TimetableInput["slots"];
  data: PlanningData;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const names = (indexes: number[]) =>
    [
      ...new Set(
        indexes
          .map((i) => slots[i - 1])
          .filter(Boolean)
          .map(
            (s) =>
              data.choices.subjects.find((x) => x.id === s.subject_id)?.name ??
              t("Class", "ক্লাস"),
          ),
      ),
    ].join(", ");
  return (
    <section className="space-y-3 rounded-xl border p-4">
      <h3 className="font-semibold">
        {t("Review timetable", "রুটিন যাচাই করুন")}
      </h3>
      <p>
        {preview.count} {t("classes ready", "টি ক্লাস প্রস্তুত")} ·{" "}
        {preview.from} — {preview.through}
      </p>
      {preview.issues.length > 0 && (
        <div
          role="alert"
          className="space-y-2 rounded-lg border border-red-400 p-3"
        >
          <p className="font-semibold">
            {t(
              "Correct these conflicts before activating.",
              "চালু করার আগে এই সমস্যাগুলো সংশোধন করুন।",
            )}
          </p>
          {compact(preview.issues).map((x) => (
            <p key={x.message}>
              {names(x.rows)}: {x.message}
            </p>
          ))}
        </div>
      )}
      {preview.warnings?.length > 0 && (
        <details className="rounded-lg border border-amber-400 p-3">
          <summary className="cursor-pointer font-medium">
            {t(
              "Preferred-hours notice — you can still activate",
              "Preferred hours সতর্কতা — রুটিন চালু করতে পারবেন",
            )}
          </summary>
          {compact(preview.warnings).map((x) => (
            <p className="mt-2" key={x.message}>
              {names(x.rows)}:{" "}
              {locale === "bn"
                ? x.message.replace(
                    ": outside saved preferred hours. This is a preference, not a booking conflict; you may save this routine.",
                    ": সংরক্ষিত পছন্দের সময়ের বাইরে। এটি বুকিং conflict নয়; রুটিন সংরক্ষণ করতে পারবেন।",
                  )
                : x.message}
            </p>
          ))}
        </details>
      )}
      <details>
        <summary className="min-h-10 cursor-pointer font-medium">
          {t("View dated classes", "তারিখভিত্তিক ক্লাস দেখুন")} (
          {preview.classes.length})
        </summary>
        <div className="max-h-80 overflow-auto">
          <table className="w-full min-w-[580px] text-left text-sm">
            <thead>
              <tr>
                {[
                  t("Date / time", "তারিখ / সময়"),
                  t("Subject / teacher / room", "বিষয় / শিক্ষক / কক্ষ"),
                  t("Result", "অবস্থা"),
                ].map((x) => (
                  <th key={x} className="p-2">
                    {x}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {preview.classes.map((c, i) => {
                const s = slots[c.row - 1];
                return (
                  <tr key={i} className="border-t">
                    <td className="p-2">
                      {c.date} · {c.start_time.slice(0, 5)}–
                      {c.end_time.slice(0, 5)}
                    </td>
                    <td className="p-2">
                      {
                        data.choices.subjects.find((x) => x.id === s.subject_id)
                          ?.name
                      }
                      <p>
                        {
                          data.choices.teachers.find(
                            (x) => x.id === s.teacher_id,
                          )?.name
                        }{" "}
                        ·{" "}
                        {
                          data.choices.rooms.find((x) => x.id === s.room_id)
                            ?.name
                        }
                      </p>
                    </td>
                    <td className="p-2">
                      <StatusBadge
                        value={
                          c.status === "READY"
                            ? "APPROVED"
                            : c.status === "SKIPPED"
                              ? "PENDING"
                              : "REJECTED"
                        }
                        label={
                          c.status === "READY"
                            ? t("Ready", "প্রস্তুত")
                            : c.status === "SKIPPED"
                              ? t("Skipped", "বাদ যাবে")
                              : t("Conflict", "সমস্যা")
                        }
                      />
                      {c.status === "SKIPPED" && (
                        <p className="mt-1 text-xs">
                          {c.message === "Time has already passed"
                            ? t("Time has passed", "সময় পার হয়েছে")
                            : t(
                                "Holiday or recorded unavailability",
                                "ছুটি বা নির্ধারিত বন্ধ",
                              )}
                        </p>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </details>
    </section>
  );
}
