import Link from "next/link";
import { getMySalarySummary } from "@/modules/finance/payroll/queries";
import { PersonalSalary } from "@/modules/finance/payroll/personal-summary";
import { getReferrerWorkspace } from "@/modules/referrals/queries";
import { PersonalFinance } from "@/modules/workforce/personal-finance";
import { getTaskData } from "@/modules/workforce/tasks";
import { TaskRegister } from "@/modules/workforce/task-register";
import { LocalizedText } from "@/components/shared/localized-text";
import { PageHeader } from "@/components/erp/page-header";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getWorkData } from "@/modules/workforce/queries";
import { WorkWorkspace } from "@/modules/workforce/workspace";
import { WorkTabs } from "@/modules/workforce/work-tabs";
import { workforceQuery } from "@/modules/workforce/route-query";
export default async function MyWorkPage({
  searchParams,
}: {
  searchParams: Promise<{
    month?: string;
    page?: string;
    tasksPage?: string;
    tasksView?: string;
    tab?: string;
  }>;
}) {
  const context = await requirePermission("workforce.self.view"),
    raw = await searchParams,
    q = workforceQuery(raw);
  const tab = ["tasks", "earnings"].includes(raw.tab ?? "")
    ? raw.tab!
    : raw.tasksView || raw.tasksPage
      ? "tasks"
      : "attendance";
  const history = raw.tasksView === "history",
    page = Math.max(
      1,
      Math.min(10000, Number.parseInt(raw.tasksPage ?? "1", 10) || 1),
    );
  // Fetch only the selected work area. Task reporting does not load payroll or referral data.
  let content;
  if (tab === "tasks") {
    const tasks = await getTaskData(undefined, history, page);
    content = (
      <TaskRegister
        data={tasks}
        people={[]}
        history={history}
        page={page}
        month={
          q.month ??
          new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Dhaka" })
            .format(new Date())
            .slice(0, 7) + "-01"
        }
      />
    );
  } else if (tab === "earnings") {
    const [salary, finance] = await Promise.all([
      getMySalarySummary(),
      context.permissions.includes("referrals.portal.view")
        ? getReferrerWorkspace()
        : Promise.resolve(null),
    ]);
    content = (
      <>
        {finance && (
          <PersonalFinance
            data={finance}
            salaryOutstanding={salary.outstanding}
          />
        )}
        <PersonalSalary data={salary} />
        <div className="flex flex-wrap gap-3">
          {context.permissions.includes("workforce.self.view") && (
            <>
              <Link
                className="rounded-lg border px-4 py-3 hover:bg-muted"
                href="/dashboard/finance/payroll"
                prefetch={false}
              >
                <LocalizedText
                  en="Salary statements & payslips"
                  bn="বেতনের বিবরণ ও payslip"
                />
              </Link>
              <Link
                className="rounded-lg border px-4 py-3 hover:bg-muted"
                href="/dashboard/finance/reimbursements"
                prefetch={false}
              >
                <LocalizedText
                  en="Submit / track expense claims"
                  bn="খরচ ফেরতের আবেদন ও অবস্থা"
                />
              </Link>
            </>
          )}
        </div>
      </>
    );
  } else {
    const data = await getWorkData(q.month, undefined, q.page);
    content = <WorkWorkspace data={data} page={q.page} />;
  }
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={<LocalizedText en="My workspace" bn="আমার কর্মক্ষেত্র" />}
        title={<LocalizedText en="My work & earnings" bn="আমার কাজ ও পাওনা" />}
        description={
          <LocalizedText
            en="Choose one work area. Your staff attendance, assigned tasks and earnings are separate from student attendance."
            bn="প্রয়োজনীয় কাজের বিভাগ নির্বাচন করুন। আপনার উপস্থিতি, নির্ধারিত কাজ ও পাওনা শিক্ষার্থীর উপস্থিতি থেকে আলাদা।"
          />
        }
      />
      <WorkTabs selected={tab} />
      {content}
    </div>
  );
}
