"use client";
import Link from "next/link";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import { PlanningForm, weekdays, weekdaysBn } from "./form";
import { sections, type PlanningData } from "./schema";
const titles = {
  offerings: ["Programme teaching plan", "প্রোগ্রামের পাঠদান পরিকল্পনা"],
  batches: ["Batch days & times", "ব্যাচের দিন ও সময়"],
  rooms: ["Classrooms", "শ্রেণিকক্ষ"],
  availability: ["Teacher / room availability", "শিক্ষক / কক্ষের সময়"],
  closures: ["Holidays & unavailability", "ছুটি ও অনুপস্থিতি"],
  routines: ["Weekly subject routine", "সাপ্তাহিক বিষয়ের রুটিন"],
};
const actions = {
  offerings: "OFFERING_PLAN",
  batches: "BATCH_PLAN",
  rooms: "ROOM",
  availability: "AVAILABILITY",
  closures: "CLOSURE",
  routines: "ROUTINE",
};
export function PlanningWorkspace({ data }: { data: PlanningData }) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    [panel, setPanel] = useState<{
      action: string;
      initial: Record<string, unknown>;
    } | null>(null),
    [notice, setNotice] = useState(""),
    [setup, setSetup] = useState<string | null>(null);
  return (
    <section className="space-y-5">
      <header>
        <h1 className="text-2xl font-semibold">
          {t(...(titles[data.section] as [string, string]))}
        </h1>
        <p className="mt-2 text-muted-foreground">
          {t(
            "Prepare programme → batch → rooms and qualified teacher availability → routine → generate dated classes. Availability and occupied time are checked separately.",
            "প্রোগ্রাম → ব্যাচ → কক্ষ ও যোগ্য শিক্ষকের সময় → রুটিন → তারিখভিত্তিক ক্লাস। ব্যবহারযোগ্য সময় ও আগে থেকে বুকিং আলাদা যাচাই হবে।",
          )}
        </p>
      </header>
      <nav className="flex flex-wrap gap-2">
        {sections.map((s) => (
          <Link
            key={s}
            prefetch={false}
            className="rounded-lg border px-3 py-2 hover:bg-muted"
            href={"/dashboard/academics/planning?section=" + s}
          >
            {t(...(titles[s] as [string, string]))}
          </Link>
        ))}
      </nav>
      <div className="flex flex-wrap gap-3">
        <Link
          className="rounded-lg border px-3 py-2"
          href="/dashboard/academics/operations"
        >
          {t("Class calendar / today", "ক্লাস ক্যালেন্ডার / আজ")}
        </Link>
        <Link
          className="rounded-lg border px-3 py-2"
          href="/dashboard/crm/manage"
        >
          {t("Classes, subjects & years", "শ্রেণি, বিষয় ও শিক্ষাবর্ষ")}
        </Link>
        <Link
          className="rounded-lg border px-3 py-2"
          href="/dashboard/academics/offerings"
        >
          {t("Offerings & fees", "অফারিং ও ফি")}
        </Link>
        <Link className="rounded-lg border px-3 py-2" href="/dashboard/staff">
          {t("Teacher qualifications", "শিক্ষকের যোগ্যতা")}
        </Link>
        <Button
          onClick={() => {
            setNotice("");
            setPanel({ action: actions[data.section], initial: {} });
          }}
        >
          {t(
            data.section === "offerings" || data.section === "batches"
              ? "Set teaching plan"
              : "Create",
            data.section === "offerings" || data.section === "batches"
              ? "পাঠদান পরিকল্পনা দিন"
              : "তৈরি করুন",
          )}
        </Button>
      </div>
      {data.section === "routines" && (
        <div className="space-y-3 rounded-xl border p-4">
          <p>
            {t(
              "Missing a room or available time? Prepare it here, then continue your routine.",
              "কক্ষ বা ব্যবহারযোগ্য সময় নেই? এখানেই প্রস্তুত করে রুটিনে ফিরে যান।",
            )}
          </p>
          <div className="flex flex-wrap gap-2">
            {[
              ["ROOM", "Add classroom", "শ্রেণিকক্ষ যোগ"],
              ["AVAILABILITY", "Set availability", "সময় নির্ধারণ"],
              ["CLOSURE", "Record holiday", "ছুটি যোগ"],
            ].map(([action, en, bn]) => (
              <Button
                key={action}
                variant="outline"
                onClick={() => setSetup(setup === action ? null : action)}
              >
                {t(en, bn)}
              </Button>
            ))}
          </div>
          {setup && (
            <PlanningForm
              key={setup}
              action={setup}
              initial={{}}
              data={data}
              onDone={(message) => {
                setSetup(null);
                if (message) setNotice(message);
              }}
            />
          )}
        </div>
      )}
      {notice && (
        <p role="status" className="rounded-lg border p-3">
          {notice}
        </p>
      )}
      {panel && (
        <PlanningForm
          key={
            panel.action +
            String(panel.initial.id ?? panel.initial.routine_id ?? "new")
          }
          action={panel.action}
          initial={panel.initial}
          data={data}
          onDone={(message) => {
            setPanel(null);
            if (message) setNotice(message);
          }}
        />
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              {[
                t("Record", "রেকর্ড"),
                t("Days / times / dates", "দিন / সময় / তারিখ"),
                t("Status", "অবস্থা"),
                t("Actions", "কাজ"),
              ].map((s) => (
                <th key={s} className="p-3">
                  {s}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => (
              <tr key={String(r.id)} className="border-t">
                <td className="p-3 font-medium">
                  {String(r.label)}
                  {r.teacher ? (
                    <p>
                      {String(r.teacher)} · {String(r.room)}
                    </p>
                  ) : null}
                  {r.capacity ? (
                    <p>
                      {String(r.capacity)} {t("seats", "আসন")}
                    </p>
                  ) : null}
                </td>
                <td className="p-3">
                  {r.weekday !== undefined ? (
                    <p>
                      {t(
                        weekdays[Number(r.weekday)],
                        weekdaysBn[Number(r.weekday)],
                      )}
                    </p>
                  ) : null}
                  {r.start_time ? (
                    <p>
                      {String(r.start_time).slice(0, 5)} –{" "}
                      {String(r.end_time).slice(0, 5)}
                    </p>
                  ) : null}
                  {r.starts_on ? (
                    <p>
                      {String(r.starts_on)} – {String(r.ends_on)}
                    </p>
                  ) : null}
                  {Array.isArray(r.teaching_days) ? (
                    <p>
                      {(r.teaching_days as number[])
                        .map((d) => t(weekdays[d], weekdaysBn[d]))
                        .join(", ")}
                    </p>
                  ) : null}
                  {Array.isArray(r.teaching_windows)
                    ? (
                        r.teaching_windows as {
                          weekday: number;
                          start_time: string;
                          end_time: string;
                        }[]
                      ).map((w) => (
                        <p key={w.weekday}>
                          {t(weekdays[w.weekday], weekdaysBn[w.weekday])} ·{" "}
                          {w.start_time.slice(0, 5)}–{w.end_time.slice(0, 5)}
                        </p>
                      ))
                    : null}
                </td>
                <td className="p-3">
                  {r.retired_at
                    ? t("Retired", "বন্ধ")
                    : r.is_active === false
                      ? t("Inactive", "নিষ্ক্রিয়")
                      : String(r.status ?? t("Active", "সক্রিয়"))}
                </td>
                <td className="p-3">
                  {data.section === "routines" ? (
                    <div className="flex flex-wrap gap-2">
                      {!r.retired_at && (
                        <>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() =>
                              setPanel({
                                action: "GENERATE",
                                initial: {
                                  routine_id: r.id,
                                  starts_on: r.starts_on,
                                  ends_on: r.ends_on,
                                  planned_scope: "Planned subject class",
                                },
                              })
                            }
                          >
                            {t("Generate classes", "ক্লাস তৈরি")}
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() =>
                              setPanel({
                                action: "RETIRE",
                                initial: { routine_id: r.id },
                              })
                            }
                          >
                            {t("Retire / replace", "বন্ধ / নতুন রুটিন")}
                          </Button>
                        </>
                      )}
                    </div>
                  ) : (
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() =>
                        setPanel({
                          action: actions[data.section],
                          initial: {
                            ...r,
                            starts_on:
                              r.teaching_starts_on ??
                              r.starts_on ??
                              data.choices.offerings.find((o) => o.id === r.id)
                                ?.starts_on,
                            ends_on:
                              r.teaching_ends_on ??
                              r.ends_on ??
                              data.choices.offerings.find((o) => o.id === r.id)
                                ?.ends_on,
                          },
                        })
                      }
                    >
                      {t("Edit / status", "সম্পাদনা / অবস্থা")}
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-5">
            {t(
              "No records yet. Use Create to start.",
              "রেকর্ড নেই। তৈরি করুন বোতাম ব্যবহার করুন।",
            )}
          </p>
        )}
      </div>
      <nav className="flex gap-4">
        {data.page > 1 && (
          <Link href={"?section=" + data.section + "&page=" + (data.page - 1)}>
            {t("Previous", "আগের")}
          </Link>
        )}
        <span>
          {data.page} · {data.total}
        </span>
        {data.page * 25 < data.total && (
          <Link href={"?section=" + data.section + "&page=" + (data.page + 1)}>
            {t("Next", "পরের")}
          </Link>
        )}
      </nav>
    </section>
  );
}
