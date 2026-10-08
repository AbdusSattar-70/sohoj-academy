"use client";
import { useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/erp/status-badge";
import type { AcademicWorkspace } from "@/modules/academics/operations/schema";
export function TeacherWorkspace({
  data,
  today,
  staffName,
  staffNo,
  canRecordAttendance,
  canManageSessions,
}: {
  data: AcademicWorkspace;
  today: string;
  staffName: string | null;
  staffNo: string | null;
  canRecordAttendance: boolean;
  canManageSessions: boolean;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [tab, setTab] = useState("today");
  const grouped = {
    today: data.sessions.filter((s) => s.date === today),
    upcoming: data.sessions.filter((s) => s.date > today),
    recent: data.sessions.filter((s) => s.date < today),
  };
  const rows = grouped[tab as keyof typeof grouped];
  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border p-4">
        <p className="font-medium">
          {staffName ?? t("No linked staff identity", "যুক্ত স্টাফ পরিচয় নেই")}{" "}
          · {staffNo ?? "—"}
        </p>
        <p className="text-sm text-muted-foreground">
          {t("All times: Bangladesh", "সব সময়: বাংলাদেশ")}
        </p>
      </div>
      {!staffName && (
        <p role="status" className="rounded-lg border border-amber-500/40 p-4">
          {t(
            "Ask admin to link your verified account to one staff identity so assigned classes appear.",
            "নির্ধারিত ক্লাস দেখতে admin-কে আপনার যাচাইকৃত account একটিমাত্র স্টাফ পরিচয়ের সঙ্গে যুক্ত করতে বলুন।",
          )}
        </p>
      )}
      <nav
        aria-label={t("Assigned class dates", "নির্ধারিত ক্লাসের সময়")}
        className="flex flex-wrap gap-2"
      >
        {[
          ["today", t("Today", "আজ")],
          ["upcoming", t("Upcoming", "আসন্ন")],
          ["recent", t("Recent", "সম্প্রতি")],
        ].map(([id, label]) => (
          <Button
            key={id}
            variant={tab === id ? "default" : "outline"}
            aria-pressed={tab === id}
            onClick={() => setTab(id)}
          >
            {label} · {grouped[id as keyof typeof grouped].length}
          </Button>
        ))}
      </nav>
      <p className="text-sm text-muted-foreground">
        {t(
          "Open a class to prepare questions, record attendance and submit actual teaching. The counts cover this loaded date window; use the calendar for all records.",
          "ক্লাস খুলে প্রশ্ন প্রস্তুত করুন, উপস্থিতি নিন ও প্রকৃত পাঠদানের তথ্য জমা দিন। সংখ্যা এই load করা সময়সীমার; সব record ক্যালেন্ডারে দেখুন।",
        )}
      </p>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full min-w-[620px] text-left text-sm">
          <thead>
            <tr>
              {[
                t("Date / time", "তারিখ / সময়"),
                t("Batch / subject", "ব্যাচ / বিষয়"),
                t("Room", "কক্ষ"),
                t("Attendance status", "উপস্থিতির অবস্থা"),
                t("Action", "কাজ"),
              ].map((x) => (
                <th className="p-3" key={x}>
                  {x}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((s) => (
              <tr key={s.id} className="border-t">
                <td className="p-3">
                  {s.date}
                  <p className="text-muted-foreground">
                    {s.startTime}–{s.endTime}
                  </p>
                </td>
                <td className="p-3">
                  <p className="font-medium">{s.batch}</p>
                  <p>{s.subject}</p>
                </td>
                <td className="p-3">{s.room}</td>
                <td className="p-3">
                  {s.status === "CANCELLED" ? (
                    <StatusBadge value="CANCELLED" />
                  ) : s.approvedRevision != null ? (
                    <>
                      <StatusBadge value="APPROVED" />
                      <p>
                        {t("Revision", "সংশোধন")}: {s.approvedRevision}
                      </p>
                    </>
                  ) : s.latestStatus ? (
                    <StatusBadge value={s.latestStatus} />
                  ) : (
                    <span>{t("Not recorded", "রেকর্ড হয়নি")}</span>
                  )}
                </td>
                <td className="p-3">
                  <Button asChild variant="outline">
                    <Link
                      prefetch={false}
                      href={"/dashboard/academics/sessions/" + s.id}
                    >
                      {t("Open class", "ক্লাস খুলুন")}
                    </Link>
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && (
          <p role="status" className="p-4">
            {t(
              "No assigned classes in this view. Check the calendar or ask admin to check your assignment.",
              "এই তালিকায় নির্ধারিত ক্লাস নেই। ক্যালেন্ডার দেখুন অথবা admin-কে assignment যাচাই করতে বলুন।",
            )}
          </p>
        )}
      </div>
      {!canRecordAttendance && (
        <p className="text-sm">
          {t(
            "Your current access is view-only for attendance. Ask admin if recording access is required.",
            "উপস্থিতির ক্ষেত্রে আপনার বর্তমান access শুধু দেখার। রেকর্ডের প্রয়োজন হলে admin-কে জানান।",
          )}
        </p>
      )}
      {canManageSessions && (
        <Button asChild variant="outline">
          <Link prefetch={false} href="/dashboard/academics/routine">
            {t("Manage weekly routine", "সাপ্তাহিক রুটিন পরিচালনা")}
          </Link>
        </Button>
      )}
    </section>
  );
}
