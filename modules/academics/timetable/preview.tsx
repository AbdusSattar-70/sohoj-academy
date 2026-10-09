"use client";
import { useLanguage } from "@/components/providers/language-provider";
import { StatusBadge } from "@/components/erp/status-badge";
import type { PlanningData } from "../planning/schema";
import type { TimetableInput, TimetablePreview } from "./schema";
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
  return (
    <section className="space-y-3 rounded-xl border p-4">
      <h3 className="font-semibold">
        {t("First four weeks preview", "প্রথম চার সপ্তাহের preview")} ·{" "}
        {preview.from} — {preview.through}
      </h3>
      <p>
        {preview.count}{" "}
        {t(
          "classes ready to create. Holidays and passed times are skipped.",
          "টি ক্লাস তৈরির জন্য প্রস্তুত। ছুটি ও পার হয়ে যাওয়া সময় বাদ যাবে।",
        )}
      </p>
      {preview.issues.length > 0 && (
        <div
          role="alert"
          className="space-y-2 rounded-lg border border-red-400 p-3"
        >
          <p className="font-semibold">
            {t(
              "Correct these rows, then preview again.",
              "এই row-গুলো সংশোধন করে আবার preview দেখুন।",
            )}
          </p>
          {preview.issues.map((x, i) => (
            <p key={i}>
              {t("Row", "সারি")} {x.row}: {x.message}
            </p>
          ))}
        </div>
      )}
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
                        data.choices.teachers.find((x) => x.id === s.teacher_id)
                          ?.name
                      }{" "}
                      ·{" "}
                      {data.choices.rooms.find((x) => x.id === s.room_id)?.name}
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
                          ? t("Will create", "তৈরি হবে")
                          : c.status === "SKIPPED"
                            ? t("Skipped", "বাদ যাবে")
                            : t("Conflict", "সমস্যা")
                      }
                    />
                    {c.message && (
                      <p className="mt-1 text-xs">
                        {c.message === "Time has already passed"
                          ? t("Time has already passed", "সময় পার হয়ে গেছে")
                          : c.message ===
                              "Holiday or recorded room/teacher unavailability"
                            ? t(
                                "Holiday or recorded unavailability",
                                "ছুটি অথবা নির্ধারিত অনুপস্থিতি",
                              )
                            : c.message}
                      </p>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
