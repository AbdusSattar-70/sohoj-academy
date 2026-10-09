"use client";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { saveAcademicPlan } from "./actions";
import type { PlanningData } from "./schema";
export const weekdays = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];
export const weekdaysBn = [
  "রবি",
  "সোম",
  "মঙ্গল",
  "বুধ",
  "বৃহস্পতি",
  "শুক্র",
  "শনি",
];
const cls = "mt-1 min-h-11 w-full rounded-lg border bg-background px-3",
  field = "block text-sm font-medium";
type Values = Record<string, unknown>;
export function PlanningForm({
  action,
  data,
  initial = {},
  onDone,
}: {
  action: string;
  data: PlanningData;
  initial?: Values;
  onDone: (message?: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter(),
    [values, setValues] = useState<Values>({
      operation_kind: "COACHING",
      resource_kind: "ROOM",
      is_active: true,
      start_time: "07:00",
      end_time: "09:00",
      planned_scope: "Planned subject class",
      ...(action === "QUALIFICATION"
        ? {
            starts_on: new Intl.DateTimeFormat("en-CA", {
              timeZone: "Asia/Dhaka",
            }).format(new Date()),
            ends_on: "",
          }
        : {}),
      ...(action === "AVAILABILITY"
        ? {
            starts_on: new Intl.DateTimeFormat("en-CA", {
              timeZone: "Asia/Dhaka",
            }).format(new Date()),
            ends_on: "2099-12-31",
          }
        : {}),
      ...initial,
    }),
    [days, setDays] = useState<number[]>(
      (initial.teaching_days ??
        initial.days ??
        (Array.isArray(initial.teaching_windows) &&
        initial.teaching_windows.length
          ? (initial.teaching_windows as { weekday: number }[]).map(
              (w) => w.weekday,
            )
          : data.choices.batches.find((b) => b.id === initial.id)?.days) ??
        []) as number[],
    ),
    [windows, setWindows] = useState<
      { weekday: number; start_time: string; end_time: string }[]
    >(
      (initial.teaching_windows ?? []) as {
        weekday: number;
        start_time: string;
        end_time: string;
      }[],
    ),
    [message, setMessage] = useState(""),
    [customReason, setCustomReason] = useState(false),
    [pending, start] = useTransition(),
    [attempt, setAttempt] = useState<{
      request_id: string;
      payload: Values;
    } | null>(null),
    [uncertain, setUncertain] = useState(false);
  function update(key: string, value: unknown) {
    setValues((v) => ({ ...v, [key]: value }));
    if (key === "id" && action === "BATCH_PLAN") {
      const b = data.choices.batches.find((x) => x.id === value);
      setDays(
        b?.windows?.length ? b.windows.map((w) => w.weekday) : (b?.days ?? []),
      );
      setWindows(b?.windows ?? []);
    }
    if (key === "id" && action === "OFFERING_PLAN") {
      const o = data.choices.offerings.find((x) => x.id === value);
      setDays(o?.days ?? []);
      setValues((v) => ({
        ...v,
        operation_kind: o?.operation_kind ?? "COACHING",
        starts_on: o?.starts_on ?? "",
        ends_on: o?.ends_on ?? "",
      }));
    }
    if (key === "resource_kind") setValues((v) => ({ ...v, resource_id: "" }));
    if (key === "batch_id") {
      const b = data.choices.batches.find((x) => x.id === value),
        o = data.choices.offerings.find((x) => x.id === b?.offering_id);
      setDays(
        b?.windows?.length ? b.windows.map((x) => x.weekday) : (b?.days ?? []),
      );
      setValues((v) => ({
        ...v,
        curriculum_id: "",
        subject_id: "",
        teacher_id: "",
        room_id: "",
        starts_on: o?.starts_on ?? "",
        ends_on: o?.ends_on ?? "",
        start_time: b?.windows?.[0]?.start_time ?? "07:00",
        end_time: b?.windows?.[0]?.end_time ?? "09:00",
      }));
    }
    if (key === "subject_id" && action === "ROUTINE")
      setValues((v) => ({ ...v, curriculum_id: "" }));
  }
  function input(
    key: string,
    en: string,
    bn: string,
    type = "text",
    required = true,
  ) {
    return (
      <label className={field} key={key}>
        {t(en, bn)}
        <input
          name={key}
          required={required}
          type={type}
          value={String(values[key] ?? "")}
          onChange={(e) =>
            update(
              key,
              type === "number" ? Number(e.target.value) : e.target.value,
            )
          }
          className={cls}
          maxLength={key === "name" ? 120 : 500}
          min={type === "number" ? 1 : undefined}
        />
      </label>
    );
  }
  function select(
    key: string,
    en: string,
    bn: string,
    options: { id: string; name: string }[],
    required = true,
  ) {
    return (
      <label className={field} key={key}>
        {t(en, bn)}
        <select
          required={required}
          value={String(values[key] ?? "")}
          onChange={(e) => update(key, e.target.value)}
          className={cls}
        >
          <option value="">{t("Select…", "নির্বাচন…")}</option>
          {options.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
      </label>
    );
  }
  const batch = data.choices.batches.find((b) => b.id === values.batch_id),
    subject = String(values.subject_id ?? ""),
    resource = String(values.resource_kind ?? "ROOM");
  const teacherOptions = data.choices.teachers.map((x) => ({
    ...x,
    name:
      x.name +
      (x.is_self ? t(" · You", " · আপনি") : "") +
      (x.subjects?.includes(subject)
        ? t(" · Teaches this subject", " · বিষয়টি পড়ান")
        : ""),
  }));
  const placement = (
    <>
      {select("batch_id", "Batch", "ব্যাচ", data.choices.batches)}
      {select(
        "subject_id",
        "Subject",
        "বিষয়",
        data.choices.subjects.filter(
          (s) =>
            !s.offerings?.length ||
            s.offerings.includes(batch?.offering_id ?? ""),
        ),
      )}
      {select("teacher_id", "Teacher", "শিক্ষক", teacherOptions)}
      <p className="text-sm text-muted-foreground">
        {t(
          "Subject qualifications are recommendations, not restrictions. Admin can assign any listed active teacher or their own Staff identity. Availability and conflicts are still checked.",
          "বিষয়ের যোগ্যতা পরামর্শ, বাধা নয়। Admin তালিকার যেকোনো সক্রিয় শিক্ষক বা নিজের স্টাফ পরিচয় নির্বাচন করতে পারেন। Availability ও conflict যাচাই হবে।",
        )}
      </p>
      {select(
        "room_id",
        "Classroom",
        "শ্রেণিকক্ষ",
        data.choices.rooms.filter(
          (x) =>
            x.branch_id === batch?.branch_id &&
            (x.capacity ?? 0) >= (batch?.capacity ?? 0),
        ),
      )}
    </>
  );
  const dayPicker = (
    <div className="sm:col-span-2">
      <p className="mb-2 text-sm font-medium">
        {t("Teaching days", "ক্লাসের দিন")} · {days.length}{" "}
        {t("days/week", "দিন/সপ্তাহ")}
      </p>
      <div className="flex flex-wrap gap-4">
        {weekdays.map((name, i) => (
          <label key={name} className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={days.includes(i)}
              onChange={(e) =>
                setDays((d) =>
                  e.target.checked
                    ? [...d, i].sort()
                    : d.filter((x) => x !== i),
                )
              }
            />
            {t(name, weekdaysBn[i])}
          </label>
        ))}
      </div>
    </div>
  );
  function send(current: { request_id: string; payload: Values }) {
    start(async () => {
      const r = await saveAcademicPlan({
        ...current.payload,
        request_id: current.request_id,
      });
      setMessage(r.message);
      setUncertain(!!r.uncertain);
      if (!r.uncertain) setAttempt(null);
      if (r.ok) {
        router.refresh();
        onDone(r.message);
      }
    });
  }
  return (
    <form
      data-editor
      data-busy={pending ? "true" : "false"}
      onSubmit={(e) => {
        e.preventDefault();
        if (pending || uncertain) return;
        const payload: Values = {
          ...values,
          action,
          locale,
          reason: customReason
            ? values.reason
            : t(
                "Confirmed the academic schedule and resource details",
                "ক্লাসের সময় ও সংশ্লিষ্ট তথ্য যাচাই করেছি",
              ),
        };
        if (action === "OFFERING_PLAN" || action === "ROUTINE")
          payload.days = days;
        if (action === "BATCH_PLAN")
          payload.windows = days.map(
            (d) =>
              windows.find((w) => w.weekday === d) ?? {
                weekday: d,
                start_time: values.start_time,
                end_time: values.end_time,
              },
          );
        if (!payload.id) delete payload.id;
        const current = { request_id: crypto.randomUUID(), payload };
        setAttempt(current);
        send(current);
      }}
      className="space-y-4 rounded-xl border bg-card p-5"
    >
      <fieldset disabled={pending} className="contents">
        <fieldset
          disabled={pending || uncertain}
          className="grid gap-4 sm:grid-cols-2"
        >
          {action === "OFFERING_PLAN" && (
            <>
              {select(
                "id",
                "Programme offering",
                "প্রোগ্রাম অফারিং",
                data.choices.offerings,
              )}
              {select("operation_kind", "Operation", "কার্যক্রম", [
                { id: "SCHOOL", name: t("School", "স্কুল") },
                { id: "COACHING", name: t("Coaching", "কোচিং") },
                {
                  id: "TRAINING",
                  name: t("Training / preparation", "প্রশিক্ষণ / প্রস্তুতি"),
                },
              ])}
              {input("starts_on", "Teaching from", "ক্লাস শুরু", "date")}
              {input("ends_on", "Teaching through", "ক্লাস শেষ", "date")}
              {dayPicker}
            </>
          )}
          {action === "BATCH_PLAN" && (
            <>
              {select("id", "Batch", "ব্যাচ", data.choices.batches)}
              {dayPicker}
              {days.map((d) => {
                const w = windows.find((x) => x.weekday === d) ?? {
                  weekday: d,
                  start_time: "07:00",
                  end_time: "09:00",
                };
                return (
                  <div
                    key={d}
                    className="sm:col-span-2 grid gap-3 sm:grid-cols-3"
                  >
                    <strong>{t(weekdays[d], weekdaysBn[d])}</strong>
                    {(["start_time", "end_time"] as const).map((k) => (
                      <label key={k}>
                        {t(
                          k === "start_time" ? "Starts" : "Ends",
                          k === "start_time" ? "শুরু" : "শেষ",
                        )}
                        <input
                          type="time"
                          required
                          value={w[k]}
                          className={cls}
                          onChange={(e) =>
                            setWindows((old) => [
                              ...old.filter((x) => x.weekday !== d),
                              { ...w, [k]: e.target.value },
                            ])
                          }
                        />
                      </label>
                    ))}
                  </div>
                );
              })}
              <p className="sm:col-span-2 text-sm">
                {t(
                  "No override days means inherit programme days without a fixed time window.",
                  "ব্যাচের দিন না দিলে প্রোগ্রামের দিন অনুসরণ করবে; সময়ের বাধ্যতামূলক সীমা থাকবে না।",
                )}
              </p>
            </>
          )}
          {action === "ROOM" && (
            <>
              {select("branch_id", "Campus", "শাখা", data.choices.branches)}
              {input("name", "Classroom name", "কক্ষের নাম")}
              {input("capacity", "Seats", "আসন", "number")}
            </>
          )}
          {(action === "AVAILABILITY" || action === "CLOSURE") && (
            <>
              {select("resource_kind", "For", "যার জন্য", [
                { id: "ROOM", name: t("Classroom", "শ্রেণিকক্ষ") },
                { id: "TEACHER", name: t("Teacher", "শিক্ষক") },
                ...(action === "CLOSURE"
                  ? [
                      {
                        id: "ACADEMY",
                        name: t("Academy holiday", "একাডেমির ছুটি"),
                      },
                    ]
                  : []),
              ])}
              {resource !== "ACADEMY" &&
                select(
                  "resource_id",
                  "Resource",
                  "শিক্ষক / কক্ষ",
                  resource === "ROOM"
                    ? data.choices.rooms
                    : data.choices.teachers,
                )}
              {action === "CLOSURE" &&
                input("name", "Closure / absence reason", "ছুটি / বন্ধের কারণ")}
              {action === "CLOSURE" ? (
                <>
                  {input("starts_on", "Unavailable from", "বন্ধ শুরু", "date")}
                  {input("ends_on", "Through", "শেষ", "date")}
                </>
              ) : (
                <details className="sm:col-span-2 rounded-lg border p-3">
                  <summary className="cursor-pointer">
                    {t(
                      "Limit preference to dates (optional)",
                      "পছন্দের সময় নির্দিষ্ট তারিখে সীমিত করুন (ঐচ্ছিক)",
                    )}
                  </summary>
                  {input("starts_on", "From", "শুরু", "date")}
                  {input("ends_on", "Through", "শেষ", "date")}
                </details>
              )}
              {action === "AVAILABILITY" && (
                <>
                  {select(
                    "weekday",
                    "Weekday",
                    "বার",
                    weekdays.map((name, i) => ({
                      id: String(i),
                      name: t(name, weekdaysBn[i]),
                    })),
                  )}
                  {input("start_time", "Available from", "সময় শুরু", "time")}
                  {input("end_time", "Until", "সময় শেষ", "time")}
                </>
              )}
            </>
          )}
          {action === "QUALIFICATION" && (
            <>
              {select("teacher_id", "Teacher", "শিক্ষক", data.choices.teachers)}
              {select(
                "subject_id",
                "Qualified subject",
                "পড়ানোর বিষয়",
                data.choices.subjects,
              )}
              <p className="sm:col-span-2 text-sm text-muted-foreground">
                {t(
                  "This records teaching subjects as a recommendation, not a scheduling restriction. No dates are required in ordinary use. Open advanced dates only for historical or time-limited assignments.",
                  "এটি পাঠদানের বিষয়ের পরিচিতি; ক্লাস বরাদ্দে বাধা নয়। সাধারণ ব্যবহারে তারিখ দিতে হবে না। অতীত বা সীমিত মেয়াদের জন্য advanced তারিখ খুলুন।",
                )}
              </p>
              <details className="sm:col-span-2 rounded-lg border p-3">
                <summary className="min-h-9 cursor-pointer font-medium">
                  {t(
                    "Effective dates (optional to change)",
                    "কার্যকর তারিখ (প্রয়োজনে পরিবর্তন)",
                  )}
                </summary>
                <div className="grid gap-3 pt-3 sm:grid-cols-2">
                  {input("starts_on", "Effective from", "কার্যকর শুরু", "date")}
                  {input(
                    "ends_on",
                    "Until (optional)",
                    "শেষ তারিখ (ঐচ্ছিক)",
                    "date",
                    false,
                  )}
                </div>
              </details>
            </>
          )}
          {action === "ROUTINE" && (
            <>
              {placement}
              {select(
                "curriculum_id",
                "Teaching plan (optional)",
                "পাঠদান পরিকল্পনা (ঐচ্ছিক)",
                data.choices.curricula.filter(
                  (x) =>
                    x.batch_id === values.batch_id && x.subject_id === subject,
                ),
                false,
              )}
              {dayPicker}
              {input("starts_on", "Effective from", "কার্যকর শুরু", "date")}
              {input("ends_on", "Through", "শেষ", "date")}
              {input("start_time", "Starts", "শুরু", "time")}
              {input("end_time", "Ends", "শেষ", "time")}
            </>
          )}
          {action === "CREATE_SESSION" && (
            <>
              {placement}
              {input("starts_on", "Class date", "ক্লাসের তারিখ", "date")}
              {input("start_time", "Starts", "শুরু", "time")}
              {input("end_time", "Ends", "শেষ", "time")}
              {input("planned_scope", "Planned topics", "পরিকল্পিত পাঠ")}
            </>
          )}
          {action === "GENERATE" && (
            <>
              {input("starts_on", "Generate from", "ক্লাস তৈরি শুরু", "date")}
              {input(
                "ends_on",
                "Through (maximum 94 days)",
                "শেষ (সর্বোচ্চ ৯৪ দিন)",
                "date",
              )}
              {input("planned_scope", "Planned topics", "পরিকল্পিত পাঠ")}
            </>
          )}
          {["RESCHEDULE", "SUBSTITUTE", "ROOM_CHANGE", "MAKEUP"].includes(
            action,
          ) && (
            <>
              {input("starts_on", "New class date", "নতুন তারিখ", "date")}
              {select(
                "teacher_id",
                "Teacher / substitute",
                "শিক্ষক / বিকল্প",
                teacherOptions,
              )}
              {select(
                "room_id",
                "Classroom",
                "শ্রেণিকক্ষ",
                data.choices.rooms.filter(
                  (x) =>
                    x.branch_id === batch?.branch_id &&
                    (x.capacity ?? 0) >= (batch?.capacity ?? 0),
                ),
              )}
              {input("start_time", "Starts", "শুরু", "time")}
              {input("end_time", "Ends", "শেষ", "time")}
            </>
          )}
          {["ROOM", "AVAILABILITY", "CLOSURE"].includes(action) &&
            Boolean(values.id) && (
              <label>
                <input
                  type="checkbox"
                  checked={Boolean(values.is_active)}
                  onChange={(e) => update("is_active", e.target.checked)}
                />
                {t("Active for new use", "নতুন কাজে সক্রিয়")}
              </label>
            )}
          <label className={field}>
            {t("Change reason", "পরিবর্তনের কারণ")}
            <select
              className={cls}
              value={customReason ? "OTHER" : "CONFIRMED"}
              onChange={(e) => setCustomReason(e.target.value === "OTHER")}
            >
              <option value="CONFIRMED">
                {t(
                  "Confirmed the selected details",
                  "নির্বাচিত তথ্য যাচাই করেছি",
                )}
              </option>
              <option value="OTHER">
                {t("Other — write a reason", "অন্য কারণ — লিখুন")}
              </option>
            </select>
          </label>
          {customReason && input("reason", "Reason", "কারণ")}
        </fieldset>
        {message && (
          <p role="status" className="rounded-lg border p-3">
            {message}
          </p>
        )}
        <div className="flex gap-3">
          {uncertain ? (
            <Button
              loading={pending}
              disabled={pending}
              type="button"
              onClick={() => attempt && send(attempt)}
            >
              {t("Confirm previous request", "আগের অনুরোধ নিশ্চিত করুন")}
            </Button>
          ) : (
            <Button loading={pending} disabled={pending} type="submit">
              {t("Save", "সংরক্ষণ")}
            </Button>
          )}
          <Button
            loading={pending}
            variant="outline"
            type="button"
            disabled={pending || uncertain}
            onClick={(event) => {
              guardWorkspaceNavigation(
                event,
                locale,
                event.currentTarget.closest("form"),
              );
              if (!event.defaultPrevented) onDone();
            }}
          >
            {t("Cancel", "বাতিল")}
          </Button>
        </div>
      </fieldset>
    </form>
  );
}
