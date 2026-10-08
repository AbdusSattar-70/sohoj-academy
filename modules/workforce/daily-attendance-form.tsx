"use client";
import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import {
  readDailyAttendance,
  recordDailyAttendance,
} from "./daily-attendance-actions";
import {
  bangladeshClock,
  bangladeshDate,
  attendanceStatuses,
  type AttendanceStatus,
} from "./daily-attendance";
import type { WorkData } from "./queries";
const cls = "mt-1 min-h-11 w-full rounded-lg border bg-background px-3 py-2";
export function DailyAttendanceForm({
  people,
  initialStaffId,
  initialDate,
  today,
  lockedSelection = false,
  onSaved,
}: {
  people: WorkData["people"];
  initialStaffId: string | null;
  initialDate: string;
  today: string;
  lockedSelection?: boolean;
  onSaved?: (message: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter();
  const [staff, setStaff] = useState(initialStaffId ?? ""),
    [date, setDate] = useState(initialDate),
    [status, setStatus] = useState<AttendanceStatus>("PRESENT"),
    [startTime, setStartTime] = useState(""),
    [endTime, setEndTime] = useState(""),
    [nextDay, setNextDay] = useState(false),
    [breakMinutes, setBreakMinutes] = useState(0),
    [reason, setReason] = useState("record"),
    [note, setNote] = useState(""),
    [recorded, setRecorded] = useState(false),
    [loadedKey, setLoadedKey] = useState(""),
    [readError, setReadError] = useState(false),
    [refresh, setRefresh] = useState(0),
    [message, setMessage] = useState(""),
    [pending, transition] = useTransition();
  const form = useRef<HTMLFormElement>(null),
    request = useRef({ signature: "", id: "" });
  const key = staff + ":" + date,
    ready = loadedKey === key && !readError;
  useEffect(() => {
    if (!staff || !date) return;
    let current = true;
    readDailyAttendance({ staff_id: staff, work_date: date })
      .then((result) => {
        if (!current) return;
        setLoadedKey(key);
        setReadError(!result.ok);
        if (!result.ok) {
          setMessage(
            t(
              "Could not load this day's record. Retry before saving.",
              "এই দিনের রেকর্ড পাওয়া যায়নি। সংরক্ষণের আগে আবার চেষ্টা করুন।",
            ),
          );
          return;
        }
        const row = result.record;
        setRecorded(Boolean(row));
        setStatus(row?.status ?? "PRESENT");
        setStartTime(bangladeshClock(row?.started_at ?? null));
        setEndTime(bangladeshClock(row?.ended_at ?? null));
        setNextDay(
          Boolean(
            row?.ended_at && bangladeshDate(new Date(row.ended_at)) !== date,
          ),
        );
        setBreakMinutes(row?.break_minutes ?? 0);
        setReason(row ? "correct" : "record");
        setNote("");
        setMessage("");
        if (form.current) form.current.dataset.dirty = "false";
      })
      .catch(() => {
        if (current) {
          setLoadedKey(key);
          setReadError(true);
          setMessage(
            t(
              "Could not load this day's record. Retry before saving.",
              "এই দিনের রেকর্ড পাওয়া যায়নি। সংরক্ষণের আগে আবার চেষ্টা করুন।",
            ),
          );
        }
      });
    return () => {
      current = false;
    };
    // Reload only when the selected record or retry changes, never when the person types.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, refresh]);
  const change = (event: { preventDefault: () => void }, apply: () => void) => {
    let blocked = false;
    guardWorkspaceNavigation(
      {
        preventDefault: () => {
          blocked = true;
          event.preventDefault();
        },
      },
      locale,
      form.current?.parentElement,
    );
    if (!blocked) {
      apply();
      setMessage("");
    }
  };
  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending || !ready) return;
    const values = {
      staff_id: staff,
      work_date: date,
      status,
      start_time: startTime,
      end_time: endTime,
      ends_next_day: nextDay,
      break_minutes: breakMinutes,
      reason:
        reason === "other"
          ? note
          : t(
              reason === "correct"
                ? "Corrected verified staff attendance"
                : "Recorded verified staff attendance",
              reason === "correct"
                ? "যাচাইকৃত স্টাফ উপস্থিতি সংশোধন করেছি"
                : "যাচাইকৃত স্টাফ উপস্থিতি রেকর্ড করেছি",
            ),
    };
    const signature = JSON.stringify(values);
    if (request.current.signature !== signature)
      request.current = { signature, id: crypto.randomUUID() };
    transition(async () => {
      try {
        const result = await recordDailyAttendance({
          ...values,
          request_id: request.current.id,
        });
        if (!result.ok) {
          setMessage(result.message);
          return;
        }
        setRecorded(true);
        setReason("correct");
        setMessage(
          t(
            "Attendance saved for this staff member and date. You can record another day or person.",
            "এই স্টাফ ও তারিখের উপস্থিতি সংরক্ষিত হয়েছে। অন্য দিন বা স্টাফের উপস্থিতি নিতে পারেন।",
          ),
        );
        if (form.current) form.current.dataset.dirty = "false";
        request.current = { signature: "", id: "" };
        window.dispatchEvent(new CustomEvent("erp:saved"));
        onSaved?.(t("Attendance saved.", "উপস্থিতি সংরক্ষিত হয়েছে।"));
        router.refresh();
      } catch {
        setMessage(
          t(
            "Save could not be confirmed. Reload this day's record before retrying.",
            "সংরক্ষণ নিশ্চিত হয়নি। আবার সংরক্ষণের আগে এই দিনের রেকর্ড দেখুন।",
          ),
        );
      }
    });
  }
  const labels: Record<AttendanceStatus, [string, string]> = {
    PRESENT: ["Present", "উপস্থিত"],
    ABSENT: ["Absent", "অনুপস্থিত"],
    LEAVE: ["On leave", "ছুটি"],
    HOLIDAY: ["Academy holiday", "একাডেমি বন্ধ"],
  };
  return (
    <section className="space-y-3 rounded-xl border p-4 sm:p-5">
      <h2 className="text-lg font-semibold">
        {t("Record staff attendance", "স্টাফ উপস্থিতি নিন")}
      </h2>
      <p className="text-sm text-muted-foreground">
        {t(
          "Choose yourself or a staff member and one date. Present requires actual start/end times; other statuses do not. All times are Bangladesh time.",
          "নিজেকে বা স্টাফকে এবং একটি তারিখ নির্বাচন করুন। উপস্থিত হলে প্রকৃত শুরু–শেষ সময় দিন; অন্য অবস্থায় সময় লাগে না। সব সময় বাংলাদেশ সময়।",
        )}
      </p>
      {lockedSelection ? (
        <p className="font-medium">
          {people.find((person) => person.id === staff)?.name} · {date}
        </p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          <label>
            {t("Staff member", "স্টাফ")}
            <select
              className={cls}
              value={staff}
              disabled={pending}
              onChange={(e) => {
                const value = e.target.value;
                change(e, () => setStaff(value));
              }}
            >
              <option value="">
                {t("Choose staff…", "স্টাফ নির্বাচন করুন…")}
              </option>
              {people.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} · {p.number}
                </option>
              ))}
            </select>
          </label>
          <label>
            {t("Attendance date", "উপস্থিতির তারিখ")}
            <input
              className={cls}
              type="date"
              value={date}
              max={today}
              disabled={pending}
              onChange={(e) => {
                const value = e.target.value;
                change(e, () => setDate(value));
              }}
            />
            <Button
              className="mt-2"
              type="button"
              variant="outline"
              disabled={pending || date === today}
              onClick={(e) => change(e, () => setDate(today))}
            >
              {t("Today", "আজ")}
            </Button>
          </label>
        </div>
      )}
      {!staff ? (
        <p role="status">
          {t(
            "Select a staff member to begin. If your identity is missing, link it under Staff & access requests first.",
            "শুরু করতে স্টাফ নির্বাচন করুন। নিজের পরিচয় না থাকলে আগে স্টাফ ও প্রবেশের আবেদন পেজ থেকে যুক্ত করুন।",
          )}
        </p>
      ) : !loadedKey || loadedKey !== key ? (
        <p role="status">
          {t("Loading this day's attendance…", "এই দিনের উপস্থিতি দেখা হচ্ছে…")}
        </p>
      ) : readError ? (
        <Button
          type="button"
          variant="outline"
          onClick={() => setRefresh((n) => n + 1)}
        >
          {t("Retry loading", "আবার রেকর্ড দেখুন")}
        </Button>
      ) : null}
      {message && (
        <div className="space-y-2">
          <p role="status" className="rounded-lg border p-3">
            {message}
          </p>
          {staff && !pending && (
            <Button
              type="button"
              variant="outline"
              onClick={(event) =>
                change(event, () => {
                  setLoadedKey("");
                  setRefresh((n) => n + 1);
                })
              }
            >
              {t("Reload this day's record", "এই দিনের রেকর্ড আবার দেখুন")}
            </Button>
          )}
        </div>
      )}
      {ready && (
        <form
          ref={form}
          onSubmit={submit}
          data-editor
          data-busy={pending ? "true" : "false"}
          className="grid gap-4 sm:grid-cols-2"
        >
          <fieldset className="contents" disabled={pending}>
            <p className="sm:col-span-2 text-sm">
              {recorded
                ? t(
                    "A record already exists. Saving corrects it; it does not add a second attendance.",
                    "এই দিনের রেকর্ড আছে। সংরক্ষণ করলে সংশোধিত হবে; দ্বিতীয় উপস্থিতি তৈরি হবে না।",
                  )
                : t(
                    "No record for this person and date yet.",
                    "এই স্টাফ ও তারিখের রেকর্ড এখনো নেই।",
                  )}
            </p>
            <label>
              {t("Attendance status", "উপস্থিতির অবস্থা")}
              <select
                className={cls}
                value={status}
                onChange={(e) => setStatus(e.target.value as AttendanceStatus)}
              >
                {attendanceStatuses.map((v) => (
                  <option key={v} value={v}>
                    {t(...labels[v])}
                  </option>
                ))}
              </select>
            </label>
            {status === "PRESENT" && (
              <>
                <label>
                  {t("Started at", "শুরু সময়")}
                  <input
                    className={cls}
                    type="time"
                    required
                    value={startTime}
                    onChange={(e) => setStartTime(e.target.value)}
                  />
                </label>
                <label>
                  {t("Ended at", "শেষ সময়")}
                  <input
                    className={cls}
                    type="time"
                    required
                    value={endTime}
                    onChange={(e) => setEndTime(e.target.value)}
                  />
                </label>
                <details className="sm:col-span-2 rounded-lg border p-3">
                  <summary className="cursor-pointer min-h-9">
                    {t(
                      "Break / overnight shift (optional)",
                      "বিরতি / রাত পেরিয়ে কাজ (ঐচ্ছিক)",
                    )}
                  </summary>
                  <div className="space-y-3 pt-3">
                    <label>
                      {t("Break minutes", "বিরতি মিনিট")}
                      <input
                        className={cls}
                        type="number"
                        min={0}
                        max={1440}
                        value={breakMinutes}
                        onChange={(e) =>
                          setBreakMinutes(Number(e.target.value))
                        }
                      />
                    </label>
                    <label className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={nextDay}
                        onChange={(e) => setNextDay(e.target.checked)}
                      />
                      {t("End time is on the next day", "শেষ সময় পরের দিনের")}
                    </label>
                  </div>
                </details>
              </>
            )}
            <label>
              {t("Record / correction reason", "রেকর্ড / সংশোধনের কারণ")}
              <select
                className={cls}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              >
                <option value="record">
                  {t("Recorded actual attendance", "প্রকৃত উপস্থিতি রেকর্ড")}
                </option>
                <option value="correct">
                  {t(
                    "Corrected verified attendance",
                    "যাচাইকৃত উপস্থিতি সংশোধন",
                  )}
                </option>
                <option value="other">
                  {t("Other — write a note", "অন্য কারণ — লিখুন")}
                </option>
              </select>
            </label>
            {reason === "other" && (
              <label>
                {t("Note", "কারণ")}
                <input
                  className={cls}
                  required
                  minLength={5}
                  maxLength={1000}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
              </label>
            )}
            <div className="sm:col-span-2">
              <Button type="submit" loading={pending} disabled={pending}>
                {recorded
                  ? t("Save correction", "সংশোধন সংরক্ষণ")
                  : t("Save attendance", "উপস্থিতি সংরক্ষণ")}
              </Button>
            </div>
          </fieldset>
        </form>
      )}
    </section>
  );
}
