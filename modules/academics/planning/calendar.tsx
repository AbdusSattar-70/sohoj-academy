"use client";
import Link from "next/link";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import { PlanningForm } from "./form";
import type { CalendarData, PlanningData } from "./schema";
export function ClassCalendar({
  data,
  planning,
  from,
  to,
}: {
  data: CalendarData;
  planning?: PlanningData;
  from: string;
  to: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    [panel, setPanel] = useState<{
      action: string;
      initial: Record<string, unknown>;
    } | null>(null),
    [notice, setNotice] = useState("");
  const time = (s: string) =>
    new Date(s).toLocaleTimeString(locale === "bn" ? "bn-BD" : "en-GB", {
      timeZone: "Asia/Dhaka",
      hour: "2-digit",
      minute: "2-digit",
    });
  return (
    <section className="space-y-5">
      <header>
        <h1 className="text-2xl font-semibold">
          {t("Class calendar & today", "ক্লাস ক্যালেন্ডার ও আজকের ক্লাস")}
        </h1>
        <p className="mt-2 text-muted-foreground">
          {t(
            "Open a class → attendance → actual teaching and hours → submit → admin review. All times are Bangladesh time.",
            "ক্লাস খুলুন → উপস্থিতি → বাস্তব পাঠদান ও সময় → জমা → প্রশাসকের যাচাই। সব সময় বাংলাদেশ সময়।",
          )}
        </p>
      </header>
      {planning && (
        <div className="flex flex-wrap gap-3">
          <Link
            className="rounded-lg border px-4 py-2"
            href="/dashboard/academics/routine"
          >
            {t("Weekly routines", "সাপ্তাহিক রুটিন")}
          </Link>
          <Link
            className="rounded-lg border px-4 py-2"
            href="/dashboard/academics/planning"
          >
            {t(
              "Academic planning / availability",
              "পাঠদান পরিকল্পনা / ব্যবহারযোগ্য সময়",
            )}
          </Link>
          <Button
            onClick={() =>
              setPanel({
                action: "CREATE_SESSION",
                initial: { starts_on: from },
              })
            }
          >
            {t("Schedule one class", "একটি ক্লাস তৈরি")}
          </Button>
        </div>
      )}
      <form className="flex flex-wrap items-end gap-3">
        <label>
          {t("From", "শুরু")}
          <input
            required
            type="date"
            name="from"
            defaultValue={from}
            className="ml-2 rounded-lg border bg-background p-2"
          />
        </label>
        <label>
          {t("Through · maximum 32 days", "শেষ · সর্বোচ্চ ৩২ দিন")}
          <input
            required
            type="date"
            name="to"
            defaultValue={to}
            className="ml-2 rounded-lg border bg-background p-2"
          />
        </label>
        <Button type="submit">{t("Show classes", "ক্লাস দেখুন")}</Button>
      </form>
      <p>
        {t("Teaching reports awaiting review", "পাঠদানের রিপোর্ট যাচাই বাকি")}:{" "}
        {data.pendingReports}
      </p>
      {notice && (
        <p role="status" className="rounded-lg border p-3">
          {notice}
        </p>
      )}
      {panel && planning && (
        <PlanningForm
          key={panel.action + String(panel.initial.session_id ?? "new")}
          action={panel.action}
          initial={panel.initial}
          data={planning}
          onDone={(msg) => {
            setPanel(null);
            if (msg) setNotice(msg);
          }}
        />
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              {[
                t("Class / time", "ক্লাস / সময়"),
                t("Teacher / room", "শিক্ষক / কক্ষ"),
                t("Attendance / teaching", "উপস্থিতি / পাঠদান"),
                t("Actions", "কাজ"),
              ].map((s) => (
                <th className="p-3" key={s}>
                  {s}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((s) => (
              <tr key={s.id} className="border-t">
                <td className="p-3">
                  <Link
                    className="font-semibold underline"
                    href={"/dashboard/academics/sessions/" + s.id}
                  >
                    {s.batch} · {s.subject}
                  </Link>
                  <p>
                    {s.session_date} · {time(s.starts_at)}–{time(s.ends_at)}
                  </p>
                  <span
                    className={
                      "inline-block rounded px-2 py-1 " +
                      (s.status === "CANCELLED"
                        ? "bg-red-500/15"
                        : "bg-green-500/15")
                    }
                  >
                    {s.status}
                  </span>
                  {s.replacement_for_id && (
                    <Link
                      className="ml-2 underline"
                      href={
                        "/dashboard/academics/sessions/" + s.replacement_for_id
                      }
                    >
                      {t("Original class", "মূল ক্লাস")}
                    </Link>
                  )}
                </td>
                <td className="p-3">
                  {s.teacher}
                  <p>{s.room}</p>
                </td>
                <td className="p-3">
                  {s.attendance ?? t("Not recorded", "লেখা হয়নি")}
                  <p>
                    {s.report_status ??
                      t(
                        "Teaching log not recorded",
                        "পাঠদানের রিপোর্ট লেখা হয়নি",
                      )}
                  </p>
                </td>
                <td className="p-3">
                  <Link
                    className="inline-block rounded-lg border px-3 py-2"
                    href={"/dashboard/academics/sessions/" + s.id}
                  >
                    {s.report_status === "SUBMITTED"
                      ? t("Open / review", "খুলুন / যাচাই")
                      : t("Open class", "ক্লাস খুলুন")}
                  </Link>
                  {planning && (
                    <details className="mt-2">
                      <summary className="cursor-pointer">
                        {t("Change this occurrence", "এই ক্লাসে পরিবর্তন")}
                      </summary>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {(s.status === "CANCELLED"
                          ? ["MAKEUP"]
                          : [
                              "SUBSTITUTE",
                              "ROOM_CHANGE",
                              "RESCHEDULE",
                              "CANCEL",
                            ]
                        ).map((action) => (
                          <Button
                            size="sm"
                            variant="outline"
                            key={action}
                            onClick={() =>
                              setPanel({
                                action,
                                initial: {
                                  session_id: s.id,
                                  batch_id: s.batch_id,
                                  subject_id: s.subject_id,
                                  teacher_id: s.teacher_id,
                                  room_id: s.room_id,
                                  starts_on: s.session_date,
                                  start_time: new Intl.DateTimeFormat("en-GB", {
                                    timeZone: "Asia/Dhaka",
                                    hour: "2-digit",
                                    minute: "2-digit",
                                    hour12: false,
                                  }).format(new Date(s.starts_at)),
                                  end_time: new Intl.DateTimeFormat("en-GB", {
                                    timeZone: "Asia/Dhaka",
                                    hour: "2-digit",
                                    minute: "2-digit",
                                    hour12: false,
                                  }).format(new Date(s.ends_at)),
                                },
                              })
                            }
                          >
                            {t(
                              action,
                              (
                                {
                                  SUBSTITUTE: "বিকল্প শিক্ষক",
                                  ROOM_CHANGE: "কক্ষ পরিবর্তন",
                                  RESCHEDULE: "সময় পরিবর্তন",
                                  CANCEL: "বাতিল",
                                  MAKEUP: "পূরণ ক্লাস",
                                } as Record<string, string>
                              )[action],
                            )}
                          </Button>
                        ))}
                      </div>
                    </details>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-5">
            {t(
              "No classes in this range. Prepare a routine and generate dated sessions first.",
              "এই সময়ে ক্লাস নেই। রুটিন তৈরি করে তারিখভিত্তিক ক্লাস তৈরি করুন।",
            )}
          </p>
        )}
      </div>
      <nav className="flex gap-4">
        {data.page > 1 && (
          <Link
            href={
              "?" +
              new URLSearchParams({ from, to, page: String(data.page - 1) })
            }
          >
            {t("Previous", "আগের")}
          </Link>
        )}
        <span>
          {data.page} · {data.total}
        </span>
        {data.page * 25 < data.total && (
          <Link
            href={
              "?" +
              new URLSearchParams({ from, to, page: String(data.page + 1) })
            }
          >
            {t("Next", "পরের")}
          </Link>
        )}
      </nav>
    </section>
  );
}
