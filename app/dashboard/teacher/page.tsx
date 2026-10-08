import Link from "next/link";
import { getClassFlow } from "@/modules/teacher/classroom/queries";
import { ClassPreparation } from "@/modules/teacher/classroom/preparation";
import { LocalizedText } from "@/components/shared/localized-text";
import { PageHeader } from "@/components/erp/page-header";
import { getCalendar } from "@/modules/academics/planning/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { TeacherWorkspace } from "@/modules/teacher/workspace";

function organizationToday() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Dhaka",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function addDays(isoDate: string, days: number) {
  const base = new Date(`${isoDate}T00:00:00Z`);
  base.setUTCDate(base.getUTCDate() + days);
  return base.toISOString().slice(0, 10);
}

export default async function TeacherDashboardPage() {
  const context = await requirePermission("academics.view");
  const today = organizationToday();
  // Include a short look-back so teachers can finish recent attendance.
  const from = addDays(today, -7);
  const to = addDays(today, 14);
  const [calendar, flow] = await Promise.all([
    getCalendar(from, to, 1),
    getClassFlow(),
  ]);

  const data = {
    branches: [],
    batches: [],
    subjects: [],
    teachers: [],
    rooms: [],
    curricula: [],
    routines: [],
    sessions: calendar.rows.map((s) => ({
      id: s.id,
      batch: s.batch,
      subject: s.subject,
      teacher: s.teacher,
      room: s.room,
      date: s.session_date,
      startTime: new Date(s.starts_at).toLocaleTimeString("en-GB", {
        timeZone: "Asia/Dhaka",
        hour: "2-digit",
        minute: "2-digit",
      }),
      endTime: new Date(s.ends_at).toLocaleTimeString("en-GB", {
        timeZone: "Asia/Dhaka",
        hour: "2-digit",
        minute: "2-digit",
      }),
      timezone: "Asia/Dhaka",
      status: s.status,
      scope: s.planned_scope,
      latestStatus: s.attendance,
      approvedRevision: s.approved_revision,
    })),
  };
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow={<LocalizedText en="Teaching" bn="পাঠদান" />}
        title={<LocalizedText en="My classes" bn="আমার ক্লাস" />}
        description={
          <LocalizedText
            en="Open an assigned class to prepare questions or record attendance and actual teaching. Submitted evidence is finalized after admin review."
            bn="নির্ধারিত ক্লাস খুলে প্রশ্ন প্রস্তুত করুন অথবা উপস্থিতি ও প্রকৃত পাঠদানের তথ্য দিন। Admin review-এর পরে জমা তথ্য চূড়ান্ত হবে।"
          />
        }
      />
      <nav className="flex flex-wrap gap-3">
        <Link
          className="rounded-lg border px-4 py-2"
          href="/dashboard/academics/questions"
        >
          <LocalizedText
            en="Class question preparation"
            bn="ক্লাসের প্রশ্ন প্রস্তুতি"
          />
        </Link>
        <Link
          className="rounded-lg border px-4 py-2"
          href="/dashboard/academics/progress"
        >
          <LocalizedText
            en="Student progress reports"
            bn="শিক্ষার্থীর অগ্রগতি প্রতিবেদন"
          />
        </Link>
      </nav>
      {context.permissions.includes("workforce.self.view") && (
        <Link
          className="inline-flex min-h-11 items-center rounded-lg border px-4 py-2 hover:bg-muted"
          href="/dashboard/my-work?tab=tasks"
          prefetch={false}
        >
          <LocalizedText
            en="Assigned work, staff attendance & earnings"
            bn="নির্ধারিত কাজ, নিজের উপস্থিতি ও পাওনা"
          />
        </Link>
      )}
      {calendar.total > 25 && (
        <Link
          className="rounded-lg border p-3"
          href={`/dashboard/academics/operations?from=${from}&to=${to}`}
        >
          <LocalizedText
            en="View all assigned classes →"
            bn="সব নির্ধারিত ক্লাস দেখুন →"
          />
        </Link>
      )}
      <TeacherWorkspace
        data={data}
        today={today}
        staffName={context.staffName}
        staffNo={context.staffNo}
        canRecordAttendance={context.permissions.includes(
          "academics.attendance.record",
        )}
        canManageSessions={context.permissions.includes(
          "academics.sessions.manage",
        )}
      />
      <ClassPreparation reminders={flow.reminders} />
    </div>
  );
}
