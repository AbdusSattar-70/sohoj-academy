import Link from "next/link";
import { ClipboardCheck, PhoneCall } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { getActionCenterData } from "@/modules/action-center/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function ActionCenterPage() {
  const context = await requirePermission("action_center.view");
  const data = await getActionCenterData(context);

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Exceptions first"
        title="Action Center"
        description="Work that requires a human decision or timely follow-up is collected here so important exceptions do not disappear inside reports."
      />

      <div className="grid gap-6 xl:grid-cols-2">
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="border-b px-5 py-4">
            <h2 className="font-semibold">Pending approvals</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Sensitive workflows remain unsettled until an authorized reviewer
              makes a maker-checker decision.
            </p>
          </div>

          {data.approvals.length ? (
            <div className="divide-y">
              {data.approvals.map((item) => (
                <div key={item.id} className="px-5 py-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-medium">{item.workflowType}</p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {item.entityType} • {item.requestedAction}
                      </p>
                    </div>
                    <StatusBadge value="PENDING" />
                  </div>
                  {item.requestNote && (
                    <p className="mt-3 text-sm leading-6 text-muted-foreground">
                      {item.requestNote}
                    </p>
                  )}
                  <p className="mt-2 text-xs text-muted-foreground">
                    Requested {new Date(item.requestedAt).toLocaleString()}
                  </p>
                </div>
              ))}
              <div className="p-4">
                <Link
                  href="/dashboard/governance/approvals"
                  className="text-sm font-semibold text-blue-700 hover:underline dark:text-blue-300"
                >
                  Open approval register
                </Link>
              </div>
            </div>
          ) : (
            <div className="p-5">
              <EmptyState
                icon={ClipboardCheck}
                title="No approval decisions are waiting"
                description="New requests will appear here when a controlled workflow is submitted for review."
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
                    <p className="font-medium">{item.studentName}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {item.prospectNo} • {item.mobile}
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
