import Link from "next/link";
import { ClipboardCheck } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { getAdminReviewQueue } from "@/modules/governance/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

const reviewLabels = {
  ATTENDANCE: "Attendance",
  CLASS_LOG: "Class log",
  ASSESSMENT_RESULTS: "Assessment results",
  QUESTION: "Question",
} as const;

export default async function AdminReviewQueuePage() {
  const context = await requirePermission("approvals.view");
  const queue = await getAdminReviewQueue();

  const canReviewAttendance = context.permissions.includes(
    "academics.attendance.approve",
  );
  const canReviewAcademic = context.permissions.includes(
    "academics.assessments.approve",
  );
  const items = queue.filter((item) =>
    item.reviewType === "ATTENDANCE" || item.reviewType === "CLASS_LOG"
      ? canReviewAttendance
      : canReviewAcademic,
  );

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Governance"
        title="Admin Review Queue"
        description="Teacher submissions remain non-final until an authorized admin reviews them. Approve to make the submitted revision official or reject with a reason so the teacher can correct and resubmit."
        actions={
          <span className="rounded-full border bg-card px-3 py-1.5 text-xs font-semibold">
            {items.length} waiting
          </span>
        }
      />

      <section className="rounded-2xl border border-primary/20 bg-primary/5 p-5 sm:p-6">
        <div className="grid gap-4 md:grid-cols-3">
          <ReviewRule
            title="Teacher owns the draft"
            body="A teacher can save and submit assigned work, but cannot finalize their own submission."
          />
          <ReviewRule
            title="Admin owns the decision"
            body="Only the configured review permission can approve or reject submitted academic work."
          />
          <ReviewRule
            title="History stays intact"
            body="Rejected and approved revisions remain traceable; corrections become new revisions."
          />
        </div>
      </section>

      {items.length ? (
        <section className="space-y-3">
          <div>
            <h2 className="text-lg font-semibold">Waiting for review</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Open the owning academic workspace to inspect the submitted
              evidence and record the review decision there.
            </p>
          </div>

          <div className="grid gap-4">
            {items.map((item) => (
              <article
                key={item.reviewType + ":" + item.id}
                className="rounded-2xl border bg-card p-5 sm:p-6"
              >
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <StatusBadge value="SUBMITTED" />
                      <span className="rounded-full border px-2.5 py-1 text-xs font-semibold">
                        {reviewLabels[item.reviewType]}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        Revision {item.revision}
                      </span>
                    </div>
                    <h3 className="mt-2 text-lg font-semibold">{item.title}</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {item.teacherName}
                      {item.teacherStaffNo
                        ? " · " + item.teacherStaffNo
                        : ""}
                      {" · "}
                      {item.batchName} · {item.subjectName}
                    </p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      Submitted{" "}
                      {new Date(item.submittedAt).toLocaleString("en-GB", {
                        timeZone: "Asia/Dhaka",
                      })}
                    </p>
                  </div>

                  <Link
                    href={item.href}
                    className="inline-flex min-h-11 items-center justify-center rounded-xl bg-primary px-4 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                  >
                    Open review
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </section>
      ) : (
        <EmptyState
          icon={ClipboardCheck}
          title="Review queue is clear"
          description={
            canReviewAttendance || canReviewAcademic
              ? "No teacher submissions are waiting for your configured review permissions."
              : "Your account can open the queue, but no academic review permission is assigned."
          }
        />
      )}
    </div>
  );
}

function ReviewRule({ title, body }: { title: string; body: string }) {
  return (
    <div>
      <h2 className="text-sm font-semibold">{title}</h2>
      <p className="mt-1 text-sm leading-6 text-muted-foreground">{body}</p>
    </div>
  );
}
