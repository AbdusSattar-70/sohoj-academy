import Link from "next/link";
import { z } from "zod";
import { getAttendanceRegister } from "@/modules/workforce/attendance-register-query";
import { AttendanceRegister } from "@/modules/workforce/attendance-register";
import { bangladeshDate } from "@/modules/workforce/daily-attendance";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
export default async function AttendancePage({
  searchParams,
}: {
  searchParams: Promise<{ person?: string; date?: string; page?: string }>;
}) {
  const context = await requirePermission("workforce.self.view");
  const manage = context.permissions.includes("workforce.manage");
  const query = await searchParams,
    today = bangladeshDate();
  const person = z.string().uuid().safeParse(query.person);
  const day = z.iso.date().safeParse(query.date);
  const date = day.success && day.data <= today ? day.data : today;
  const data = manage
    ? await getAttendanceRegister(
        date,
        query.page,
        person.success ? person.data : undefined,
      )
    : null;
  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow={<LocalizedText en="Daily work" bn="দৈনন্দিন কাজ" />}
        title={
          <LocalizedText en="Attendance register" bn="উপস্থিতি রেজিস্টার" />
        }
        description={
          <LocalizedText
            en="Choose a date, then record or correct staff attendance from the register. Green means present, red means absent. Unrecorded days stay neutral."
            bn="তারিখ নির্বাচন করে রেজিস্টার থেকে স্টাফের উপস্থিতি নিন বা সংশোধন করুন। উপস্থিত সবুজ, অনুপস্থিত লাল। অনথিভুক্ত দিন নিরপেক্ষ থাকবে।"
          />
        }
      />
      {data ? (
        <AttendanceRegister
          key={`${data.date}:${data.page}`}
          data={data}
          today={today}
          ownStaffId={context.staffId}
        />
      ) : (
        <section className="space-y-3 rounded-xl border p-5">
          <h2 className="font-semibold">
            <LocalizedText en="My attendance" bn="আমার উপস্থিতি" />
          </h2>
          <p>
            <LocalizedText
              en="View your recorded attendance. Authorized management records or corrects staff attendance."
              bn="নিজের রেকর্ড করা উপস্থিতি দেখুন। অনুমোদিত ব্যবস্থাপক উপস্থিতি রেকর্ড বা সংশোধন করেন।"
            />
          </p>
          <Button asChild>
            <Link prefetch={false} href="/dashboard/my-work?tab=attendance">
              <LocalizedText en="View my attendance" bn="আমার উপস্থিতি দেখুন" />
            </Link>
          </Button>
        </section>
      )}
      {manage && (
        <details className="rounded-xl border p-4">
          <summary className="cursor-pointer min-h-11 font-medium">
            <LocalizedText en="Attendance reports" bn="উপস্থিতির রিপোর্ট" />
          </summary>
          <p className="py-3">
            <LocalizedText
              en="Month selection is only for viewing reports, not recording a day."
              bn="মাস নির্বাচন শুধু রিপোর্ট দেখার জন্য; একটি দিনের উপস্থিতি নিতে লাগে না।"
            />
          </p>
          <Button asChild variant="outline">
            <Link
              prefetch={false}
              href="/dashboard/staff/operations?tab=attendance"
            >
              <LocalizedText
                en="View staff attendance reports"
                bn="স্টাফ উপস্থিতির রিপোর্ট দেখুন"
              />
            </Link>
          </Button>
        </details>
      )}
      {context.permissions.includes("academics.view") && (
        <section className="space-y-3 rounded-xl border p-5">
          <h2 className="font-semibold">
            <LocalizedText en="Student attendance" bn="শিক্ষার্থীর উপস্থিতি" />
          </h2>
          <p>
            <LocalizedText
              en="Open a dated class, then record the student roster in its class report. A weekly routine alone is not a dated class; generate sessions first. Only assigned or otherwise authorized classes are available."
              bn="তারিখভিত্তিক ক্লাস খুলে class report-এ শিক্ষার্থীদের উপস্থিতি দিন। শুধু সাপ্তাহিক রুটিন ক্লাস নয়; আগে sessions তৈরি করুন। দায়িত্বপ্রাপ্ত বা অনুমোদিত ক্লাসই পাওয়া যাবে।"
            />
          </p>
          <Button asChild>
            <Link
              prefetch={false}
              href={
                context.roles.includes("TEACHER") &&
                !context.permissions.includes("academics.sessions.manage")
                  ? "/dashboard/teacher"
                  : "/dashboard/academics/operations"
              }
            >
              <LocalizedText
                en="Open classes to record student attendance"
                bn="শিক্ষার্থীর উপস্থিতি দিতে ক্লাস খুলুন"
              />
            </Link>
          </Button>
        </section>
      )}
    </div>
  );
}
