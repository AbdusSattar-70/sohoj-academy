import Link from "next/link";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
export default async function AttendancePage() {
  const context = await requirePermission("workforce.self.view");
  const manage = context.permissions.includes("workforce.manage");
  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow={<LocalizedText en="Daily work" bn="দৈনন্দিন কাজ" />}
        title={<LocalizedText en="Attendance" bn="উপস্থিতি" />}
        description={
          <LocalizedText
            en="Choose whose attendance you need. Staff presence and student class attendance are different records."
            bn="কার উপস্থিতি দরকার নির্বাচন করুন। স্টাফের উপস্থিতি ও শিক্ষার্থীর ক্লাসের উপস্থিতি আলাদা রেকর্ড।"
          />
        }
      />
      <section className="space-y-3 rounded-xl border p-5">
        <h2 className="font-semibold">
          <LocalizedText en="My attendance" bn="আমার উপস্থিতি" />
        </h2>
        <p>
          <LocalizedText
            en={
              manage
                ? "Open your attendance, then choose Record staff attendance to record your own day."
                : "See your recorded days and hours. Authorized management records or corrects staff attendance."
            }
            bn={
              manage
                ? "নিজের উপস্থিতি খুলে স্টাফ উপস্থিতি রেকর্ড করুন button থেকে নিজের দিন রেকর্ড করুন।"
                : "রেকর্ড করা দিন ও ঘণ্টা দেখুন। অনুমোদিত ব্যবস্থাপক স্টাফ উপস্থিতি রেকর্ড বা সংশোধন করেন।"
            }
          />
        </p>
        <Button asChild>
          <Link prefetch={false} href="/dashboard/my-work?tab=attendance">
            <LocalizedText en="Open my attendance" bn="আমার উপস্থিতি খুলুন" />
          </Link>
        </Button>
      </section>
      {manage && (
        <section className="space-y-3 rounded-xl border p-5">
          <h2 className="font-semibold">
            <LocalizedText en="Staff attendance" bn="স্টাফ উপস্থিতি" />
          </h2>
          <p>
            <LocalizedText
              en="Select a staff member, choose Record staff attendance, then save date, status and actual times."
              bn="স্টাফ নির্বাচন করে উপস্থিতি রেকর্ড করার button খুলুন; তারিখ, অবস্থা ও প্রকৃত সময় সংরক্ষণ করুন।"
            />
          </p>
          <Button asChild>
            <Link
              prefetch={false}
              href="/dashboard/staff/operations?tab=attendance"
            >
              <LocalizedText
                en="Record / correct staff attendance"
                bn="স্টাফ উপস্থিতি রেকর্ড / সংশোধন"
              />
            </Link>
          </Button>
        </section>
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
