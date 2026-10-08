import { getTaskData } from "@/modules/workforce/tasks";
import { TaskRegister } from "@/modules/workforce/task-register";
import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getWorkData } from "@/modules/workforce/queries";
import { WorkWorkspace } from "@/modules/workforce/workspace";
import { WorkTabs } from "@/modules/workforce/work-tabs";
import { workforceQuery } from "@/modules/workforce/route-query";
export default async function StaffOperations({
  searchParams,
}: {
  searchParams: Promise<{
    month?: string;
    person?: string;
    page?: string;
    tasksPage?: string;
    tasksView?: string;
    tab?: string;
  }>;
}) {
  await requirePermission("workforce.manage");
  const raw = await searchParams,
    q = workforceQuery(raw);
  const tab =
    raw.tab === "attendance"
      ? "attendance"
      : raw.tab === "tasks" || raw.tasksPage || raw.tasksView
        ? "tasks"
        : "attendance";
  const data = await getWorkData(q.month, q.person, q.page);
  let content;
  if (tab === "tasks") {
    const page = Math.max(
        1,
        Math.min(10000, Number.parseInt(raw.tasksPage ?? "1", 10) || 1),
      ),
      history = raw.tasksView === "history",
      tasks = await getTaskData(q.person, history, page);
    content = (
      <TaskRegister
        data={tasks}
        people={data.people}
        admin
        history={history}
        page={page}
        month={data.month}
      />
    );
  } else content = <WorkWorkspace data={data} page={q.page} admin />;
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={<LocalizedText en="People" bn="শিক্ষার্থী ও স্টাফ" />}
        title={
          <LocalizedText
            en="Staff work & attendance"
            bn="স্টাফের কাজ ও উপস্থিতি"
          />
        }
        description={
          <LocalizedText
            en="Choose attendance/compensation terms or task assignment/review. Student attendance stays on the class page."
            bn="উপস্থিতি/পারিশ্রমিকের শর্ত অথবা কাজ দেওয়া/পর্যালোচনা নির্বাচন করুন। শিক্ষার্থীর উপস্থিতি ক্লাস পেজে থাকবে।"
          />
        }
      />
      <WorkTabs selected={tab} admin />
      {content}
    </div>
  );
}
