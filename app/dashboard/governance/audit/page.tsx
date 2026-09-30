import Link from "next/link";
import { z } from "zod";
import { ScrollText } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { getAuditList } from "@/modules/governance/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<{ correlation?: string }>;
}) {
  await requirePermission("audit.view");
  const query = await searchParams;
  const correlation = z.string().uuid().safeParse(query.correlation);
  const rows = await getAuditList(
    correlation.success ? correlation.data : undefined,
  );

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Governance"
        title="Audit Trail"
        description="Immutable events answer who changed what, when, through which workflow and under which correlation ID."
      />

      <section className="space-y-3 rounded-xl border p-4">
        <p className="text-sm">
          A correlation ID links the events produced by one workflow request.
          Click an ID to trace those events and inspect the recorded changes.
          Historic names/roles without a snapshot are resolved from retained
          staff records.
        </p>
        <form className="flex flex-wrap gap-2">
          <input
            name="correlation"
            defaultValue={query.correlation ?? ""}
            placeholder="Paste a correlation UUID"
            className="min-w-64 rounded-lg border bg-background p-2"
          />
          <button className="rounded-lg border px-4">Trace workflow</button>
          <Link
            className="rounded-lg border px-4 py-2"
            href="/dashboard/governance/audit"
          >
            Show latest events
          </Link>
        </form>
        {query.correlation && !correlation.success && (
          <p role="alert">Enter a valid correlation UUID.</p>
        )}
      </section>
      {rows.length ? (
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] text-sm">
              <thead>
                <tr className="border-b bg-muted/40 text-left">
                  <th className="px-4 py-3 font-semibold">Time</th>
                  <th className="px-4 py-3 font-semibold">Action</th>
                  <th className="px-4 py-3 font-semibold">Entity</th>
                  <th className="px-4 py-3 font-semibold">
                    Person / role / ID
                  </th>
                  <th className="px-4 py-3 font-semibold">Reason</th>
                  <th className="px-4 py-3 font-semibold">Correlation</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b align-top">
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(row.occurred_at).toLocaleString("en-GB", {
                        timeZone: "Asia/Dhaka",
                      })}
                    </td>
                    <td className="px-4 py-3 font-medium">{row.action}</td>
                    <td className="px-4 py-3">
                      <p>{row.entity_type}</p>
                      <p className="mt-1 max-w-48 truncate text-xs text-muted-foreground">
                        {row.entity_id}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-semibold">
                        {row.actor_name ??
                          (row.actor_profile_id
                            ? "Authenticated staff"
                            : "Public / system workflow")}
                      </p>
                      <p className="text-xs">
                        {row.actor_role_code ??
                          (row.actor_profile_id
                            ? "Role unavailable"
                            : "No staff actor")}
                        {row.actor_staff_no ? ` · ${row.actor_staff_no}` : ""}
                      </p>
                      {row.actor_profile_id && (
                        <details className="mt-1 text-xs">
                          <summary className="cursor-pointer">
                            Identity IDs
                            {row.identity_snapshot
                              ? ""
                              : " · historical lookup"}
                          </summary>
                          <p className="break-all">
                            Profile: {row.actor_profile_id}
                          </p>
                          <p className="break-all">
                            Staff: {row.actor_staff_id ?? "—"}
                          </p>
                        </details>
                      )}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {row.reason ?? "—"}
                    </td>
                    <td className="px-4 py-3">
                      <Link
                        className="break-all text-xs underline"
                        href={`/dashboard/governance/audit?correlation=${row.correlation_id}`}
                      >
                        {row.correlation_id}
                      </Link>
                      <details className="mt-2">
                        <summary className="cursor-pointer text-xs">
                          Inspect changes
                        </summary>
                        <p className="mt-2 text-xs">Event ID: {row.id}</p>
                        <pre className="mt-2 max-h-64 max-w-96 overflow-auto whitespace-pre-wrap break-all text-xs">
                          {JSON.stringify(
                            {
                              before: row.before_data,
                              after: row.after_data,
                              metadata: row.metadata,
                            },
                            null,
                            2,
                          )}
                        </pre>
                      </details>
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
