"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { PlanningForm } from "../planning/form";
import type { PlanningData } from "../planning/schema";
import { TimetableRows, type EditorRow } from "./rows";
import { TimetablePreviewPanel } from "./preview";
import { previewTimetable, saveTimetable } from "./actions";
import { timetableDates } from "./dates";
import { InlineTeachingPlan } from "./teaching-plan";
import { expandClassGroups } from "./groups";
import type { TimetablePreview, TimetableSave } from "./schema";
export function TimetableEditor({
  data,
  today,
  initial,
  onClose,
}: {
  data: PlanningData;
  today: string;
  initial?: Record<string, unknown>;
  onClose?: (message?: string) => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter();
  const [open, setOpen] = useState(!!initial),
    [batch, setBatch] = useState(String(initial?.batch_id ?? "")),
    [from, setFrom] = useState(today),
    [through, setThrough] = useState(String(initial?.ends_on ?? today)),
    [rows, setRows] = useState<EditorRow[]>(
      initial
        ? [
            {
              key: "edit",
              weekday: Number(initial.weekday),
              days: [Number(initial.weekday)],
              subject_id: String(initial.subject_id),
              teacher_id: String(initial.teacher_id),
              room_id: String(initial.room_id),
              start_time: String(initial.start_time).slice(0, 5),
              end_time: String(initial.end_time).slice(0, 5),
              planned_scope: String(initial.planned_scope ?? ""),
              curriculum_id: initial.curriculum_version_id
                ? String(initial.curriculum_version_id)
                : undefined,
            },
          ]
        : [],
    ),
    [preview, setPreview] = useState<TimetablePreview | null>(null),
    [busy, setBusy] = useState(false),
    [dirty, setDirty] = useState(false),
    [notice, setNotice] = useState(""),
    [room, setRoom] = useState(false),
    [planRow, setPlanRow] = useState<string | null>(null),
    [retry, setRetry] = useState<TimetableSave | null>(null),
    [reason, setReason] = useState("Agreed weekly timetable"),
    [other, setOther] = useState("");
  function invalidate() {
    setPreview(null);
    setDirty(true);
    setNotice("");
  }
  function fresh(): EditorRow {
    return {
      key: crypto.randomUUID(),
      weekday: 0,
      days: [0],
      subject_id: "",
      teacher_id: "",
      room_id: "",
      start_time: "07:00",
      end_time: "09:00",
      planned_scope: "",
    };
  }
  async function save(payload: TimetableSave) {
    setBusy(true);
    setNotice("");
    try {
      const result = await saveTimetable(payload);
      if (result.ok) {
        setNotice(
          t(
            `Saved: ${result.class_count} classes created, ${result.from}–${result.through}. Open the class calendar to take attendance.`,
            `সংরক্ষিত: ${result.class_count}টি ক্লাস তৈরি হয়েছে, ${result.from}–${result.through}। উপস্থিতির জন্য ক্লাস ক্যালেন্ডার খুলুন।`,
          ),
        );
        setOpen(false);
        setDirty(false);
        setRetry(null);
        onClose?.(
          t(
            `Timetable saved. ${result.class_count} classes ready.`,
            `রুটিন সংরক্ষিত। ${result.class_count}টি ক্লাস প্রস্তুত।`,
          ),
        );
        router.refresh();
      } else {
        setNotice(result.message);
        setRetry(result.uncertain ? payload : null);
      }
    } catch {
      setRetry(payload);
      setNotice(
        t(
          "Result unconfirmed. Retry the same request.",
          "ফল নিশ্চিত নয়। একই অনুরোধ আবার নিশ্চিত করুন।",
        ),
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="space-y-4">
      {notice && (
        <p role="status" className="rounded-lg border p-3">
          {notice}
        </p>
      )}
      {!open && (
        <Button
          onClick={() => {
            setRows([fresh()]);
            setBatch("");
            setPreview(null);
            setRetry(null);
            setOpen(true);
            setNotice("");
          }}
        >
          {t("Create weekly timetable", "সাপ্তাহিক রুটিন তৈরি করুন")}
        </Button>
      )}
      {open && (
        <form
          data-editor
          data-dirty={dirty}
          data-busy={busy || !!retry}
          className="space-y-4 rounded-xl border p-4"
          onSubmit={async (e) => {
            e.preventDefault();
            if (rows.some((r) => r.days.length === 0)) {
              setNotice(
                t(
                  "Select at least one day for each class.",
                  "প্রতি ক্লাসের জন্য অন্তত একটি দিন নির্বাচন করুন।",
                ),
              );
              return;
            }
            setBusy(true);
            setPreview(null);
            setNotice("");
            try {
              const r = await previewTimetable({
                batch_id: batch,
                replace_routine_id: initial?.id
                  ? String(initial.id)
                  : undefined,
                starts_on: from,
                ends_on: through,
                slots: expandClassGroups(rows),
                locale,
              });
              if (r.ok) setPreview(r.preview);
              else setNotice(r.message);
            } catch {
              setNotice(
                t(
                  "Preview unavailable. Retry; your input is retained.",
                  "Preview পাওয়া যায়নি। তথ্য রেখে আবার চেষ্টা করুন।",
                ),
              );
            } finally {
              setBusy(false);
            }
          }}
        >
          <fieldset
            disabled={busy || !!retry || !!planRow}
            className="space-y-4"
          >
            <legend className="font-semibold">
              {t(
                "1. Choose batch · 2. Tick class days · 3. Review and activate",
                "১. ব্যাচ → ২. ক্লাসের দিন tick → ৩. যাচাই ও চালু",
              )}
            </legend>
            <div className="grid gap-3 sm:grid-cols-3">
              <label>
                {t("Batch", "ব্যাচ")}
                <select
                  required
                  disabled={!!initial}
                  className="min-h-11 w-full rounded-lg border bg-background p-2"
                  value={batch}
                  onChange={(e) => {
                    if (
                      dirty &&
                      !window.confirm(
                        t(
                          "Changing batch replaces the unsaved class rows. Continue?",
                          "ব্যাচ বদলালে অসংরক্ষিত ক্লাসের সারি বদলে যাবে। এগোবেন?",
                        ),
                      )
                    )
                      return;
                    const id = e.target.value,
                      d = timetableDates(data, id, today);
                    setBatch(id);
                    setFrom(d.from);
                    setThrough(d.through);
                    const b = data.choices.batches.find((x) => x.id === id),
                      w = b?.windows?.[0];
                    setRows([
                      {
                        ...fresh(),
                        weekday: w?.weekday ?? b?.days?.[0] ?? 0,
                        days: b?.windows?.length
                          ? [...new Set(b.windows.map((w) => w.weekday))]
                          : b?.days?.length
                            ? b.days
                            : [0],
                        start_time: w?.start_time.slice(0, 5) ?? "07:00",
                        end_time: w?.end_time.slice(0, 5) ?? "09:00",
                      },
                    ]);
                    invalidate();
                  }}
                >
                  <option value="">
                    {t("Select batch…", "ব্যাচ নির্বাচন…")}
                  </option>
                  {data.choices.batches.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                {t("Effective from", "শুরুর তারিখ")}
                <input
                  required
                  type="date"
                  min={today}
                  value={from}
                  onChange={(e) => {
                    setFrom(e.target.value);
                    invalidate();
                  }}
                  className="min-h-11 w-full rounded-lg border bg-background p-2"
                />
              </label>
              <details className="rounded-lg border p-3">
                <summary className="cursor-pointer">
                  {t(
                    "End date (optional to change)",
                    "শেষ তারিখ (প্রয়োজনে পরিবর্তন)",
                  )}{" "}
                  · {through}
                </summary>{" "}
                <label>
                  {t("Through", "শেষ তারিখ")}
                  <input
                    required
                    type="date"
                    min={from}
                    value={through}
                    onChange={(e) => {
                      setThrough(e.target.value);
                      invalidate();
                    }}
                    className="min-h-11 w-full rounded-lg border bg-background p-2"
                  />
                </label>
              </details>
            </div>
            <p className="text-sm text-muted-foreground">
              {t(
                "One class row can cover several weekdays: tick its days. Add a separate row when subject, time, teacher or room differs. Preferred hours only warn; bookings, closures and seats are checked.",
                "একটি ক্লাসের একাধিক দিন tick করুন। বিষয়, সময়, শিক্ষক বা কক্ষ আলাদা হলে অন্য সারি যোগ করুন। Preferred hours শুধু সতর্ক করবে; booking, বন্ধ সময় ও আসন যাচাই হবে।",
              )}
            </p>
            <TimetableRows
              onCreatePlan={(key) => {
                setPlanRow(key);
                setRoom(false);
              }}
              rows={rows}
              data={data}
              batchId={batch}
              onChange={(key, field, value) => {
                setRows((r) =>
                  r.map((x) =>
                    x.key === key
                      ? {
                          ...x,
                          [field]: value,
                          ...(field === "subject_id"
                            ? { curriculum_id: undefined }
                            : {}),
                        }
                      : x,
                  ),
                );
                invalidate();
              }}
              onCopy={(key, day) => {
                setRows((r) => {
                  const x = r.find((x) => x.key === key)!;
                  return [
                    ...r,
                    { ...x, key: crypto.randomUUID(), weekday: day },
                  ];
                });
                invalidate();
              }}
              onRemove={(key) => {
                setRows((r) => r.filter((x) => x.key !== key));
                invalidate();
              }}
            />
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                disabled={rows.length >= 40}
                onClick={() => {
                  setRows((r) => [...r, fresh()]);
                  invalidate();
                }}
              >
                {t("Add class row", "ক্লাসের সারি যোগ")}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => setRoom(!room)}
              >
                {t("Missing room? Add here", "কক্ষ নেই? এখানেই যোগ করুন")}
              </Button>
              <Button type="submit">
                {busy
                  ? t("Loading…", "লোড হচ্ছে…")
                  : t("Preview next four weeks", "আগামী চার সপ্তাহ দেখুন")}
              </Button>
            </div>
            {preview && (
              <TimetablePreviewPanel
                preview={preview}
                slots={expandClassGroups(rows)}
                data={data}
              />
            )}
            <label className="block">
              {t("Save reason", "সংরক্ষণের কারণ")}
              <select
                className="ml-2 min-h-11 rounded-lg border bg-background p-2"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              >
                <option value="Agreed weekly timetable">
                  {t("Agreed weekly timetable", "সম্মত সাপ্তাহিক রুটিন")}
                </option>
                <option value="other">
                  {t("Other — write reason", "অন্য কারণ লিখুন")}
                </option>
              </select>
              {reason === "other" && (
                <input
                  required
                  minLength={5}
                  maxLength={500}
                  value={other}
                  onChange={(e) => setOther(e.target.value)}
                  className="ml-2 rounded-lg border bg-background p-2"
                />
              )}
            </label>
            <Button
              type="button"
              disabled={
                !preview?.ready ||
                (reason === "other" && other.trim().length < 5)
              }
              onClick={() =>
                save({
                  batch_id: batch,
                  replace_routine_id: initial?.id
                    ? String(initial.id)
                    : undefined,
                  starts_on: from,
                  ends_on: through,
                  slots: expandClassGroups(rows),
                  locale,
                  request_id: crypto.randomUUID(),
                  reason: reason === "other" ? other : reason,
                })
              }
            >
              {t("Activate timetable", "রুটিন চালু করুন")}
            </Button>
          </fieldset>
          {busy && (
            <p role="status">
              {t(
                "Please wait for confirmation…",
                "ফল নিশ্চিত হওয়া পর্যন্ত অপেক্ষা করুন…",
              )}
            </p>
          )}
          {retry && (
            <Button disabled={busy} type="button" onClick={() => save(retry)}>
              {t("Confirm same request", "একই অনুরোধ নিশ্চিত করুন")}
            </Button>
          )}
          <Button
            disabled={busy || !!retry || !!planRow}
            type="button"
            variant="outline"
            onClick={() => {
              if (
                !dirty ||
                window.confirm(
                  t("Discard unsaved timetable?", "অসংরক্ষিত রুটিন বাদ দেবেন?"),
                )
              ) {
                setOpen(false);
                setDirty(false);
                onClose?.();
              }
            }}
          >
            {t("Cancel", "বাতিল")}
          </Button>
        </form>
      )}
      {open && planRow && (
        <InlineTeachingPlan
          key={planRow}
          batchId={batch}
          subjectId={rows.find((r) => r.key === planRow)!.subject_id}
          subjectName={
            data.choices.subjects.find(
              (s) => s.id === rows.find((r) => r.key === planRow)!.subject_id,
            )?.name ?? ""
          }
          from={from}
          through={through}
          onDone={(id) => {
            if (id) {
              setRows((v) =>
                v.map((r) =>
                  r.key === planRow ? { ...r, curriculum_id: id } : r,
                ),
              );
              invalidate();
              setNotice(
                t(
                  "Teaching plan saved and selected.",
                  "পাঠ পরিকল্পনা সংরক্ষিত ও নির্বাচিত হয়েছে।",
                ),
              );
              router.refresh();
            }
            setPlanRow(null);
          }}
        />
      )}
      {open && room && (
        <PlanningForm
          action="ROOM"
          initial={{}}
          data={data}
          onDone={(message) => {
            setRoom(false);
            if (message) setNotice(message);
            router.refresh();
          }}
        />
      )}
      <Link
        className="inline-flex cursor-pointer rounded-lg border px-4 py-2 hover:bg-muted"
        onNavigate={(e) => guardWorkspaceNavigation(e, locale)}
        href="/dashboard/academics/operations"
      >
        {t("Open class calendar", "ক্লাস ক্যালেন্ডার খুলুন")}
      </Link>
    </section>
  );
}
