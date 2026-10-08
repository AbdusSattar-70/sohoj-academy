"use client";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/erp/status-badge";
import { useLanguage } from "@/components/providers/language-provider";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { DailyAttendanceForm } from "./daily-attendance-form";
import { bangladeshClock, type AttendanceStatus } from "./daily-attendance";
import type { AttendanceRegisterData } from "./attendance-register-query";
const rowTones: Record<AttendanceStatus, string> = {
  PRESENT: "bg-emerald-50/60 dark:bg-emerald-950/20",
  ABSENT: "bg-red-50/60 dark:bg-red-950/20",
  LEAVE: "bg-amber-50/60 dark:bg-amber-950/20",
  HOLIDAY: "bg-blue-50/60 dark:bg-blue-950/20",
};
export function AttendanceRegister({
  data,
  today,
  ownStaffId,
}: {
  data: AttendanceRegisterData;
  today: string;
  ownStaffId: string | null;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [selected, setSelected] = useState(data.selected),
    [notice, setNotice] = useState("");
  const labels: Record<AttendanceStatus, [string, string]> = {
    PRESENT: ["Present", "উপস্থিত"],
    ABSENT: ["Absent", "অনুপস্থিত"],
    LEAVE: ["On leave", "ছুটি"],
    HOLIDAY: ["Academy holiday", "একাডেমি বন্ধ"],
  };
  const totals = attendanceStatusesForSummary(data);
  const toggle = (event: React.MouseEvent<HTMLButtonElement>, id: string) => {
    guardWorkspaceNavigation(event, locale);
    if (!event.defaultPrevented) setSelected(selected === id ? null : id);
  };
  const url = (page: number) =>
    `/dashboard/attendance?date=${data.date}&page=${page}`;
  return (
    <section className="space-y-4">
      <form
        action="/dashboard/attendance"
        className="flex flex-wrap items-end gap-3 rounded-xl border p-4"
      >
        <label className="text-sm font-medium">
          {t("Register date", "রেজিস্টারের তারিখ")}
          <input
            className="mt-1 block min-h-11 rounded-lg border bg-background px-3"
            type="date"
            name="date"
            defaultValue={data.date}
            max={today}
            required
          />
        </label>
        <Button type="submit">{t("View register", "রেজিস্টার দেখুন")}</Button>
        <Button asChild variant="outline">
          <Link prefetch={false} href="/dashboard/attendance">
            {t("Today", "আজ")}
          </Link>
        </Button>
        {ownStaffId && (
          <Button asChild variant="outline">
            <Link
              prefetch={false}
              href={`/dashboard/attendance?date=${data.date}&person=${ownStaffId}`}
            >
              {t("My attendance row", "আমার উপস্থিতির row")}
            </Link>
          </Button>
        )}
      </form>
      <div
        className="flex flex-wrap gap-2"
        aria-label={t("Statuses on this page", "এই পেজের অবস্থা")}
      >
        {(["PRESENT", "ABSENT", "LEAVE", "HOLIDAY"] as const).map((status) => (
          <StatusBadge
            key={status}
            value={status}
            label={`${t(...labels[status])} · ${totals[status]}`}
          />
        ))}
        <StatusBadge
          value="UNRECORDED"
          label={`${t("Not recorded", "রেকর্ড হয়নি")} · ${totals.UNRECORDED}`}
        />
      </div>
      <p className="text-sm text-muted-foreground">
        {t(
          "Counts describe this page. Open a staff row to record status and actual times. Missing records are not absent.",
          "সংখ্যা এই পেজের জন্য। স্টাফের row খুলে অবস্থা ও প্রকৃত সময় দিন। রেকর্ড না থাকা মানে অনুপস্থিত নয়।",
        )}
      </p>
      {notice && (
        <p role="status" className="rounded-lg border p-3">
          {notice}
        </p>
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full min-w-[620px] text-left text-sm">
          <caption className="p-3 text-left font-semibold">
            {t("Staff attendance register", "স্টাফ উপস্থিতি রেজিস্টার")} ·{" "}
            {data.date}
          </caption>
          <thead className="bg-muted/50">
            <tr>
              {[
                t("Staff / ID", "স্টাফ / ID"),
                t("Status", "অবস্থা"),
                t("Start — end", "শুরু — শেষ"),
                t("Net hours", "কাজের ঘণ্টা"),
                t("Action", "করণীয়"),
              ].map((label) => (
                <th key={label} scope="col" className="p-3">
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((person) => {
              const row = person.record,
                status = row?.status,
                open = selected === person.id;
              const hours =
                row?.started_at && row.ended_at
                  ? (
                      (Date.parse(row.ended_at) - Date.parse(row.started_at)) /
                        3600000 -
                      row.break_minutes / 60
                    ).toLocaleString(locale === "bn" ? "bn-BD" : "en-GB", {
                      maximumFractionDigits: 2,
                    })
                  : null;
              return (
                <StaffRow
                  key={person.id}
                  open={open}
                  tone={status ? rowTones[status] : ""}
                  name={person.name}
                  number={person.number}
                  status={
                    <StatusBadge
                      value={status ?? "UNRECORDED"}
                      label={
                        status
                          ? t(...labels[status])
                          : t("Not recorded", "রেকর্ড হয়নি")
                      }
                    />
                  }
                  times={
                    row?.started_at
                      ? `${bangladeshClock(row.started_at)} — ${bangladeshClock(row.ended_at)}`
                      : "—"
                  }
                  hours={hours ?? "—"}
                  action={
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      aria-expanded={open}
                      onClick={(event) => toggle(event, person.id)}
                    >
                      {open
                        ? t("Close", "বন্ধ করুন")
                        : row
                          ? t("Correct", "সংশোধন")
                          : t("Record", "উপস্থিতি নিন")}
                    </Button>
                  }
                >
                  <DailyAttendanceForm
                    people={[person]}
                    initialStaffId={person.id}
                    initialDate={data.date}
                    today={today}
                    lockedSelection
                    onSaved={(message) => {
                      setNotice(`${person.name}: ${message}`);
                      setSelected(null);
                    }}
                  />
                </StaffRow>
              );
            })}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-4">
            {t(
              "No active staff. Verify staff identity and access first.",
              "সক্রিয় স্টাফ নেই। আগে স্টাফ পরিচয় ও প্রবেশাধিকার যাচাই করুন।",
            )}
          </p>
        )}
      </div>
      <nav
        className="flex flex-wrap items-center gap-3"
        aria-label={t("Register pages", "রেজিস্টারের পেজ")}
      >
        <span className="text-sm">
          {t("Page", "পেজ")} {data.page} · {data.total} {t("staff", "স্টাফ")}
        </span>
        {data.page > 1 && (
          <Button asChild variant="outline">
            <Link prefetch={false} href={url(data.page - 1)}>
              {t("Previous", "আগের")}
            </Link>
          </Button>
        )}
        {data.page * 25 < data.total && (
          <Button asChild variant="outline">
            <Link prefetch={false} href={url(data.page + 1)}>
              {t("Next", "পরের")}
            </Link>
          </Button>
        )}
      </nav>
    </section>
  );
}
function attendanceStatusesForSummary(data: AttendanceRegisterData) {
  const counts = { PRESENT: 0, ABSENT: 0, LEAVE: 0, HOLIDAY: 0, UNRECORDED: 0 };
  for (const person of data.rows)
    counts[person.record?.status ?? "UNRECORDED"]++;
  return counts;
}
function StaffRow({
  open,
  tone,
  name,
  number,
  status,
  times,
  hours,
  action,
  children,
}: {
  open: boolean;
  tone: string;
  name: string;
  number: string;
  status: React.ReactNode;
  times: string;
  hours: string;
  action: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <>
      <tr className={`border-t ${tone}`}>
        <th scope="row" className="p-3 font-medium">
          {name}
          <span className="block text-xs font-normal text-muted-foreground">
            {number}
          </span>
        </th>
        <td className="p-3">{status}</td>
        <td className="p-3 whitespace-nowrap">{times}</td>
        <td className="p-3">{hours}</td>
        <td className="p-3">{action}</td>
      </tr>
      {open && (
        <tr className="border-t">
          <td colSpan={5} className="p-3">
            {children}
          </td>
        </tr>
      )}
    </>
  );
}
