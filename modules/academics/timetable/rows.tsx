"use client";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import type { PlanningData } from "../planning/schema";
import { weekdays, weekdaysBn } from "../planning/form";
import type { TimetableInput } from "./schema";
export type EditorRow = TimetableInput["slots"][number] & { key: string };
const cls = "min-h-11 w-full rounded-lg border bg-background px-2";
export function TimetableRows({
  rows,
  data,
  batchId,
  onChange,
  onCopy,
  onRemove,
}: {
  rows: EditorRow[];
  data: PlanningData;
  batchId: string;
  onChange: (key: string, field: string, value: string | number) => void;
  onCopy: (key: string, day: number) => void;
  onRemove: (key: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    batch = data.choices.batches.find((x) => x.id === batchId);
  function choices(
    r: EditorRow,
    key: "subject_id" | "teacher_id" | "room_id",
    label: string,
    options: { id: string; name: string }[],
  ) {
    return (
      <label>
        <span className="sr-only">
          {label} · {rows.indexOf(r) + 1}
        </span>
        <select
          required
          className={cls}
          value={r[key]}
          onChange={(e) => onChange(r.key, key, e.target.value)}
        >
          <option value="">{t("Select…", "নির্বাচন…")}</option>
          {options.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name}
            </option>
          ))}
        </select>
      </label>
    );
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[950px] text-left text-sm">
        <thead>
          <tr>
            {[
              t("Day", "দিন"),
              t("Starts", "শুরু"),
              t("Ends", "শেষ"),
              t("Subject", "বিষয়"),
              t("Teacher", "শিক্ষক"),
              t("Room", "কক্ষ"),
              t("Actions", "কাজ"),
            ].map((x) => (
              <th key={x} className="p-2">
                {x}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.key} className="border-t align-top">
              <td className="p-2">
                <label>
                  <span className="sr-only">
                    {t("Day", "দিন")} {i + 1}
                  </span>
                  <select
                    className={cls}
                    value={r.weekday}
                    onChange={(e) =>
                      onChange(r.key, "weekday", Number(e.target.value))
                    }
                  >
                    {weekdays.map((x, n) => (
                      <option value={n} key={n}>
                        {t(x, weekdaysBn[n])}
                      </option>
                    ))}
                  </select>
                </label>
              </td>
              <td className="p-2">
                <label>
                  <span className="sr-only">
                    {t("Start time", "শুরুর সময়")} {i + 1}
                  </span>
                  <input
                    required
                    type="time"
                    className={cls}
                    value={r.start_time}
                    onChange={(e) =>
                      onChange(r.key, "start_time", e.target.value)
                    }
                  />
                </label>
              </td>
              <td className="p-2">
                <label>
                  <span className="sr-only">
                    {t("End time", "শেষের সময়")} {i + 1}
                  </span>
                  <input
                    required
                    type="time"
                    className={cls}
                    value={r.end_time}
                    onChange={(e) =>
                      onChange(r.key, "end_time", e.target.value)
                    }
                  />
                </label>
              </td>
              <td className="p-2">
                {choices(
                  r,
                  "subject_id",
                  t("Subject", "বিষয়"),
                  data.choices.subjects.filter(
                    (x) =>
                      !x.offerings?.length ||
                      x.offerings.includes(batch?.offering_id ?? ""),
                  ),
                )}
              </td>
              <td className="p-2">
                {choices(
                  r,
                  "teacher_id",
                  t("Teacher", "শিক্ষক"),
                  data.choices.teachers.map((x) => ({
                    ...x,
                    name: x.name + (x.is_self ? t(" · You", " · আপনি") : ""),
                  })),
                )}
              </td>
              <td className="p-2">
                {choices(
                  r,
                  "room_id",
                  t("Room", "কক্ষ"),
                  data.choices.rooms.filter(
                    (x) =>
                      x.branch_id === batch?.branch_id &&
                      (x.capacity ?? 0) >= (batch?.capacity ?? 0),
                  ),
                )}
              </td>
              <td className="space-y-2 p-2">
                <label>
                  <span className="sr-only">
                    {t("Copy class to another day", "অন্য দিনে ক্লাস কপি করুন")}{" "}
                    {i + 1}
                  </span>
                  <select
                    className={cls}
                    value=""
                    disabled={rows.length >= 40}
                    onChange={(e) => onCopy(r.key, Number(e.target.value))}
                  >
                    <option value="">
                      {t("Copy to day…", "অন্য দিনে কপি…")}
                    </option>
                    {weekdays.map((x, n) => (
                      <option key={n} value={n}>
                        {t(x, weekdaysBn[n])}
                      </option>
                    ))}
                  </select>
                </label>
                <Button
                  type="button"
                  variant="outline"
                  disabled={rows.length === 1}
                  onClick={() => onRemove(r.key)}
                >
                  {t("Remove row", "সারি বাদ দিন")}
                </Button>
                <details>
                  <summary className="cursor-pointer text-xs">
                    {t("Planned topic (optional)", "পরিকল্পিত পাঠ (ঐচ্ছিক)")}
                  </summary>
                  <input
                    aria-label={t("Planned topic", "পরিকল্পিত পাঠ")}
                    maxLength={2000}
                    className={cls}
                    value={r.planned_scope}
                    onChange={(e) =>
                      onChange(r.key, "planned_scope", e.target.value)
                    }
                  />
                </details>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
