import { ScrollText } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { getAuditList } from "@/modules/governance/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function AuditPage() {
  await requirePermission("audit.view");
  const rows = await getAuditList();

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Governance"
        title="Audit Trail"
        description="Immutable events answer who changed what, when, through which workflow and under which correlation ID."
      />

      {rows.length ? (
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] text-sm">
              <thead>
                <tr className="border-b bg-muted/40 text-left">
                  <th className="px-4 py-3 font-semibold">Time</th>
                  <th className="px-4 py-3 font-semibold">Action</th>
                  <th className="px-4 py-3 font-semibold">Entity</th>
                  <th className="px-4 py-3 font-semibold">Actor role</th>
                  <th className="px-4 py-3 font-semibold">Reason</th>
                  <th className="px-4 py-3 font-semibold">Correlation</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b align-top">
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(row.occurred_at).toLocaleString()}
                    </td>
                    <td className="px-4 py-3 font-medium">{row.action}</td>
                    <td className="px-4 py-3">
                      <p>{row.entity_type}</p>
                      <p className="mt-1 max-w-48 truncate text-xs text-muted-foreground">
                        {row.entity_id}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      {row.actor_role_code ?? "System / Public"}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {row.reason ?? "—"}
                    </td>
                    <td className="px-4 py-3">
                      <code className="text-xs">{row.correlation_id}</code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : (
        <EmptyState
          icon={ScrollText}
          title="No audit events yet"
          description="Business workflow events will appear here automatically. Audit history is never silently deleted."
        />
      )}
    </div>
  );
}
