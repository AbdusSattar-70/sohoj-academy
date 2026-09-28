import Link from "next/link";
import { ClipboardCheck, PhoneCall, UserRoundSearch } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { getActionCenterData } from "@/modules/action-center/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

const reviewLabels = {
  ATTENDANCE: "Attendance",
  CLASS_LOG: "Class log",
  ASSESSMENT_RESULTS: "Assessment results",
  QUESTION: "Question",
} as const;

export default async function ActionCenterPage() {
  const context = await requirePermission("action_center.view");
  const data = await getActionCenterData(context);

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Workspace"
        title="My Tasks"
        description="Open the work that needs your decision first: teacher submissions, CRM follow-ups and intake verification."
      />

      <section className="overflow-hidden rounded-2xl border bg-card">
        <div className="border-b px-5 py-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h2 className="font-semibold">Teacher review</h2>
              <p className="mt-1 text-xs text-muted-foreground">
                Submitted attendance, class logs, assessment results and
                questions remain non-final until an authorized admin reviews
                them.
              </p>
            </div>
            <Link
              href="/dashboard/governance/approvals"
              className="text-sm font-semibold text-blue-700 hover:underline dark:text-blue-300"
            >
              Open review queue
            </Link>
          </div>
        </div>

        {data.teacherReviews.length ? (
          <div className="divide-y">
            {data.teacherReviews.map((item) => (
              <div
                key={item.reviewType + ":" + item.id}
                className="flex items-start justify-between gap-4 px-5 py-4"
              >
                <div className="min-w-0">
                  <p className="font-medium">
                    {reviewLabels[item.reviewType]} · {item.title}
                  </p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {item.teacherName} · {item.batchName} · {item.subjectName}
                  </p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    Revision {item.revision} · submitted{" "}
                    {new Date(item.submittedAt).toLocaleString("en-GB", {
                      timeZone: "Asia/Dhaka",
                    })}
                  </p>
                </div>
                <Link
                  href={item.href}
                  className="shrink-0 text-sm font-semibold underline"
                >
                  Open
                </Link>
              </div>
            ))}
          </div>
        ) : (
          <div className="p-5">
            <EmptyState
              icon={ClipboardCheck}
              title="Teacher review queue is clear"
              description="No assigned teacher submission is waiting for your configured review permission."
            />
          </div>
        )}
      </section>

      {data.approvals.length > 0 && (
        <details className="rounded-2xl border bg-card">
          <summary className="cursor-pointer px-5 py-4 text-sm font-semibold">
            Other legacy approval requests
          </summary>
          <div className="divide-y border-t">
            {data.approvals.map((item) => (
              <div key={item.id} className="px-5 py-4">
                <p className="font-medium">{item.workflowType}</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  {item.entityType} · {item.requestedAction} ·{" "}
                  {new Date(item.requestedAt).toLocaleString()}
                </p>
                {item.requestNote && (
                  <p className="mt-2 text-sm text-muted-foreground">
                    {item.requestNote}
                  </p>
                )}
              </div>
            ))}
          </div>
        </details>
      )}

      <div className="grid gap-6 xl:grid-cols-2">
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="border-b px-5 py-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <h2 className="font-semibold">Verification queue</h2>
                <p className="mt-1 text-xs text-muted-foreground">
                  Recent public interest and admission submissions still in
                  early CRM states.
                </p>
              </div>
              <div className="flex flex-wrap gap-2 text-xs">
                <span className="rounded-full bg-blue-50 px-2.5 py-1 font-medium text-blue-800 dark:bg-blue-950/40 dark:text-blue-200">
                  Queue: {data.verificationQueue.length}
                </span>
              </div>
            </div>
          </div>

          {data.verificationQueue.length ? (
            <div className="divide-y">
              {data.verificationQueue.map((item) => (
                <div
                  key={item.id}
                  className="flex items-start justify-between gap-4 px-5 py-4"
                >
                  <div className="min-w-0">
                    <Link
                      href={"/dashboard/crm/prospects/" + item.id}
                      className="font-medium hover:underline"
                    >
                      {item.studentName}
                    </Link>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {item.prospectNo} · {item.mobile}
                    </p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      School: {item.schoolName}
                      {item.schoolNeedsReview ? " · needs review" : ""}
                    </p>
                  </div>
                  <StatusBadge value={item.status} />
                </div>
              ))}
            </div>
          ) : (
            <div className="p-5">
              <EmptyState
                icon={UserRoundSearch}
                title="Verification queue is clear"
                description="New public interest and admission submissions will appear here while they are still in early CRM states."
              />
            </div>
          )}
        </section>

        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="border-b px-5 py-4">
            <h2 className="font-semibold">CRM follow-ups due</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Prospect follow-ups whose scheduled time has arrived.
            </p>
          </div>

          {data.dueProspects.length ? (
            <div className="divide-y">
              {data.dueProspects.map((item) => (
                <div
                  key={item.id}
                  className="flex items-start justify-between gap-4 px-5 py-4"
                >
                  <div>
                    <Link
                      href={"/dashboard/crm/prospects/" + item.id}
                      className="font-medium hover:underline"
                    >
                      {item.studentName}
                    </Link>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {item.prospectNo} · {item.mobile}
                    </p>
                    <p className="mt-2 text-xs text-muted-foreground">
                      Due {new Date(item.nextFollowUpAt).toLocaleString()}
                    </p>
                  </div>
                  <StatusBadge value={item.status} />
                </div>
              ))}
            </div>
          ) : (
            <div className="p-5">
              <EmptyState
                icon={PhoneCall}
                title="No CRM follow-ups are overdue"
                description="Scheduled follow-ups will appear here automatically when they become due."
              />
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
