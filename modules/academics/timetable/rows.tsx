"use client";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import type { PlanningData } from "../planning/schema";
import { weekdays, weekdaysBn } from "../planning/form";
import type { TimetableInput } from "./schema";
export type EditorRow = TimetableInput["slots"][number] & {
  key: string;
  days: number[];
};
const cls = "min-h-11 w-full rounded-lg border bg-background px-2";
export function TimetableRows({
  rows,
  data,
  batchId,
  onChange,
  onCopy,
  onRemove,
  onCreatePlan,
}: {
  rows: EditorRow[];
  data: PlanningData;
  batchId: string;
  onChange: (
    key: string,
    field: string,
    value: string | number | number[],
  ) => void;
  onCopy: (key: string, day: number) => void;
  onRemove: (key: string) => void;
  onCreatePlan: (key: string) => void;
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
                  <fieldset className="flex min-w-44 flex-wrap gap-2">
                    <legend className="sr-only">
                      {t("Class days", "ক্লাসের দিন")}
                    </legend>
                    {weekdays.map((x, n) => (
                      <label
                        key={n}
                        className="flex min-h-9 cursor-pointer items-center gap-1"
                      >
                        <input
                          type="checkbox"
                          checked={r.days.includes(n)}
                          onChange={(e) =>
                            onChange(
                              r.key,
                              "days",
                              e.target.checked
                                ? [...r.days, n].sort()
                                : r.days.filter((d) => d !== n),
                            )
                          }
                        />
                        {t(x.slice(0, 3), weekdaysBn[n])}
                      </label>
                    ))}
                  </fieldset>
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
                <Button
                  type="button"
                  variant="outline"
                  disabled={rows.length >= 40}
                  onClick={() => onCopy(r.key, r.days[0] ?? 0)}
                >
                  {t("Duplicate class", "ক্লাসের কপি")}
                </Button>
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
                    {t(
                      "Topics & teaching plan (optional)",
                      "পাঠ ও পরিকল্পনা (ঐচ্ছিক)",
                    )}
                  </summary>
                  <label className="block">
                    {t("Teaching plan", "পাঠ পরিকল্পনা")}
                    <select
                      className={cls}
                      value={r.curriculum_id ?? ""}
                      onChange={(e) =>
                        onChange(r.key, "curriculum_id", e.target.value)
                      }
                    >
                      <option value="">
                        {t("No plan yet", "পরিকল্পনা নেই")}
                      </option>
                      {data.choices.curricula
                        .filter(
                          (x) =>
                            x.batch_id === batchId &&
                            x.subject_id === r.subject_id,
                        )
                        .map((x) => (
                          <option key={x.id} value={x.id}>
                            {x.name}
                          </option>
                        ))}
                    </select>
                  </label>
                  <Button
                    type="button"
                    variant="outline"
                    disabled={!r.subject_id || !batchId}
                    onClick={() => onCreatePlan(r.key)}
                  >
                    {t(
                      "Create teaching plan here",
                      "এখানেই পাঠ পরিকল্পনা তৈরি",
                    )}
                  </Button>
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
