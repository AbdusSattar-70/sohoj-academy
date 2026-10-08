"use client";
import Link from "next/link";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import { PlanningForm, weekdays, weekdaysBn } from "./form";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { sections, type PlanningData } from "./schema";
const titles = {
  qualifications: ["Teacher subject qualifications", "শিক্ষকের পাঠদানের বিষয়"],
  offerings: ["Programme teaching plan", "প্রোগ্রামের পাঠদান পরিকল্পনা"],
  batches: ["Batch days & times", "ব্যাচের দিন ও সময়"],
  rooms: ["Classrooms", "শ্রেণিকক্ষ"],
  availability: ["Teacher / room availability", "শিক্ষক / কক্ষের সময়"],
  closures: ["Holidays & unavailability", "ছুটি ও অনুপস্থিতি"],
  routines: ["Weekly subject routine", "সাপ্তাহিক বিষয়ের রুটিন"],
};
const instructions: Record<PlanningData["section"], [string, string]> = {
  qualifications: [
    "Select a verified teacher and the subjects they can teach. Next, set their weekly available hours.",
    "যাচাইকৃত শিক্ষক ও তাঁর পাঠদানের বিষয় নির্বাচন করুন। এরপর সাপ্তাহিক ব্যবহারযোগ্য সময় দিন।",
  ],
  offerings: [
    "Set teaching dates and default weekdays for an existing offering. This does not schedule a teacher or room. Next, prepare batch times.",
    "বিদ্যমান অফারিংয়ের পাঠদানের তারিখ ও সাধারণ দিন দিন। এতে শিক্ষক বা কক্ষ বুক হয় না। এরপর ব্যাচের সময় দিন।",
  ],
  batches: [
    "Choose an existing batch and set its days and time windows. Each subject class will be assigned separately in Weekly routines.",
    "বিদ্যমান ব্যাচের দিন ও সময় দিন। সাপ্তাহিক রুটিনে প্রতিটি বিষয়ের ক্লাস আলাদা বরাদ্দ হবে।",
  ],
  rooms: [
    "Add the room, branch and seat capacity, then set its available hours. A room being available does not mean it is unbooked.",
    "কক্ষ, শাখা ও আসনসংখ্যা দিন; এরপর ব্যবহারযোগ্য সময় দিন। ব্যবহারযোগ্য কক্ষ আগে থেকে বুক থাকতে পারে।",
  ],
  availability: [
    "Choose Teacher or Room and set weekdays and local start/end times. This permits scheduling within the window; it does not create classes.",
    "শিক্ষক বা কক্ষ নির্বাচন করে দিন ও স্থানীয় শুরু–শেষ সময় দিন। এই সময়ের মধ্যে রুটিন করা যাবে; এতে ক্লাস তৈরি হয় না।",
  ],
  closures: [
    "Record academy holidays or resource unavailability. Generated classes skip closed dates; existing sessions need their own change action.",
    "একাডেমির ছুটি বা শিক্ষক/কক্ষের বন্ধ সময় দিন। নতুন ক্লাস তৈরিতে বন্ধ দিন বাদ যায়; বিদ্যমান ক্লাস পৃথকভাবে পরিবর্তন করতে হবে।",
  ],
  routines: [
    "Create a weekly routine with batch, subject, qualified teacher, room and time. After saving, use Generate classes on its row, then open the class calendar for attendance.",
    "ব্যাচ, বিষয়, যোগ্য শিক্ষক, কক্ষ ও সময় দিয়ে সাপ্তাহিক রুটিন তৈরি করুন। সংরক্ষণের পর ওই row থেকে তারিখভিত্তিক ক্লাস তৈরি করুন; উপস্থিতির জন্য ক্লাস ক্যালেন্ডার খুলুন।",
  ],
};
function generationDates(row: Record<string, unknown>) {
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Dhaka",
  }).format(new Date());
  const starts = String(row.starts_on) > today ? String(row.starts_on) : today;
  const through = new Date(starts + "T00:00:00Z");
  through.setUTCDate(through.getUTCDate() + 30);
  return {
    starts_on: starts,
    ends_on:
      String(row.ends_on) < through.toISOString().slice(0, 10)
        ? String(row.ends_on)
        : through.toISOString().slice(0, 10),
  };
}
const actions = {
  qualifications: "QUALIFICATION",
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
  const openPanel = (next: NonNullable<typeof panel>) => {
    let blocked = false;
    guardWorkspaceNavigation(
      {
        preventDefault: () => {
          blocked = true;
        },
      },
      locale,
    );
    if (!blocked) {
      setSetup(null);
      setPanel(next);
    }
  };
  return (
    <section className="space-y-5">
      <header>
        <h1 className="text-2xl font-semibold">
          {t(...(titles[data.section] as [string, string]))}
        </h1>
        <p className="mt-2 text-muted-foreground">
          {t(...instructions[data.section])}
        </p>
      </header>
      <div className="flex flex-wrap items-center gap-3">
        {" "}
        <Button
          onClick={() => {
            setNotice("");
            openPanel({ action: actions[data.section], initial: {} });
          }}
        >
          {t(
            data.section === "offerings" || data.section === "batches"
              ? "Set teaching plan"
              : data.section === "routines"
                ? "Create weekly routine"
                : "Create",
            data.section === "offerings" || data.section === "batches"
              ? "পাঠদান পরিকল্পনা দিন"
              : data.section === "routines"
                ? "সাপ্তাহিক রুটিন তৈরি করুন"
                : "তৈরি করুন",
          )}
        </Button>
        <p className="text-sm text-muted-foreground">
          {t(
            data.section === "routines"
              ? "Save a routine first; Generate classes becomes available on its row."
              : "Open the form to add or update this setup. No class is created by this action.",
            data.section === "routines"
              ? "আগে রুটিন সংরক্ষণ করুন; তারপর তার row থেকে ক্লাস তৈরি করুন।"
              : "তথ্য যোগ বা পরিবর্তনের জন্য form খুলুন। এই action ক্লাস তৈরি করে না।",
          )}
        </p>
      </div>
      <Link
        className="inline-flex rounded-lg border px-3 py-2 hover:bg-muted"
        href="/dashboard/help/academics"
      >
        {t("Academic workflow guide", "শিক্ষা কার্যক্রমের নির্দেশিকা")}
      </Link>
      <nav className="flex flex-wrap gap-2">
        {sections.map((s) => (
          <Link
            key={s}
            prefetch={false}
            aria-current={data.section === s ? "page" : undefined}
            className={
              "rounded-lg border px-3 py-2 " +
              (data.section === s
                ? "bg-primary text-primary-foreground"
                : "hover:bg-muted")
            }
            href={
              s === "routines"
                ? "/dashboard/academics/routine"
                : "/dashboard/academics/planning?section=" + s
            }
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
              ["QUALIFICATION", "Assign teaching subject", "পাঠদানের বিষয় দিন"],
              ["CLOSURE", "Record holiday", "ছুটি যোগ"],
            ].map(([action, en, bn]) => (
              <Button
                key={action}
                variant="outline"
                onClick={(event) => {
                  guardWorkspaceNavigation(event, locale);
                  if (event.defaultPrevented) return;
                  setPanel(null);
                  setSetup(setup === action ? null : action);
                }}
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
                              openPanel({
                                action: "GENERATE",
                                initial: {
                                  routine_id: r.id,
                                  ...generationDates(r),
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
                              openPanel({
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
                        openPanel({
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
              "No records yet. Use the create button above to open the form.",
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
