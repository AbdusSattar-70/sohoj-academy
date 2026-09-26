import { UsersRound } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { getStaffList } from "@/modules/staff/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function StaffPage() {
  await requirePermission("staff.view");
  const rows = await getStaffList();

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="People"
        title="Staff"
        description="Staff is the permanent person identity. Teacher, Academic Director, Operator and other responsibilities are assignments on that identity, not separate person records."
      />

      {rows.length ? (
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-sm">
              <thead>
                <tr className="border-b bg-muted/40 text-left">
                  <th className="px-4 py-3 font-semibold">Staff ID</th>
                  <th className="px-4 py-3 font-semibold">Name</th>
                  <th className="px-4 py-3 font-semibold">Primary role</th>
                  <th className="px-4 py-3 font-semibold">Contact</th>
                  <th className="px-4 py-3 font-semibold">Joined</th>
                  <th className="px-4 py-3 font-semibold">Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b hover:bg-muted/30">
                    <td className="px-4 py-3 font-semibold">{row.staffNo}</td>
                    <td className="px-4 py-3">{row.fullName}</td>
                    <td className="px-4 py-3">{row.roleName}</td>
                    <td className="px-4 py-3">
                      <p>{row.mobile ?? "—"}</p>
                      {row.email && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {row.email}
                        </p>
                      )}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {row.joinedOn
                        ? new Date(row.joinedOn).toLocaleDateString()
                        : "—"}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge value={row.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : (
        <EmptyState
          icon={UsersRound}
          title="No Staff identities yet"
          description="The first administrator bootstrap creates the initial Staff identity. Additional staff will be added through the controlled Staff workflow."
        />
      )}
    </div>
  );
}
