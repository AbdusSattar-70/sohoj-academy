import Link from "next/link";
import {
  ClipboardCheck,
  Clock3,
  UserRoundSearch,
  UsersRound,
  GraduationCap,
} from "lucide-react";
import { PageHeader } from "@/components/erp/page-header";
import { StatCard } from "@/components/erp/stat-card";
import { StatusBadge } from "@/components/erp/status-badge";
import { getDashboardOverview } from "@/modules/dashboard/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ access?: string }>;
}) {
  const context = await requirePermission("dashboard.view");
  const overview = await getDashboardOverview(context);
  const { access } = await searchParams;

  const cards = [
    overview.activeProspects !== null && {
      label: "Active prospects",
      value: overview.activeProspects,
      description: "Open CRM opportunities not yet converted or lost.",
      icon: UserRoundSearch,
    },
    overview.activeStudents !== null && {
      label: "Active students",
      value: overview.activeStudents,
      description: "Current Student Master records with active lifecycle status.",
      icon: GraduationCap,
    },
    overview.pendingApprovals !== null && {
      label: "Pending approvals",
      value: overview.pendingApprovals,
      description: "Maker-checker decisions waiting for an authorized reviewer.",
      icon: ClipboardCheck,
    },
    overview.activeStaff !== null && {
      label: "Active staff",
      value: overview.activeStaff,
      description: "Active and on-leave Staff identities in the organization.",
      icon: UsersRound,
    },
  ].filter(Boolean) as Array<{
    label: string;
    value: number;
    description: string;
    icon: typeof UserRoundSearch;
  }>;

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Operational overview"
        title="Digital Campus"
        description="A concise view of work that needs attention. Every number comes from the same governed ERP records used by the underlying workflows."
      />

      {access === "denied" && (
        <div
          role="status"
          className="rounded-2xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100"
        >
          The requested module is outside your current permissions. No data was
          exposed or changed.
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => (
          <StatCard key={card.label} {...card} />
        ))}
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.5fr_1fr]">
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="flex items-center justify-between gap-4 border-b px-5 py-4">
            <div>
              <h2 className="font-semibold">Recent prospects</h2>
              <p className="mt-1 text-xs text-muted-foreground">
                Latest Student Bank entries from public and staff channels.
              </p>
            </div>
            {overview.recentProspects.length > 0 && (
              <Link
                href="/dashboard/crm/prospects"
                className="text-sm font-semibold text-blue-700 hover:underline dark:text-blue-300"
              >
                View all
              </Link>
            )}
          </div>

          <div className="divide-y">
            {overview.recentProspects.length ? (
              overview.recentProspects.map((prospect) => (
                <div
                  key={prospect.id}
                  className="flex items-center justify-between gap-4 px-5 py-4"
                >
                  <div className="min-w-0">
                    <p className="truncate font-medium">
                      {prospect.studentName}
                    </p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {prospect.prospectNo} •{" "}
                      {new Date(prospect.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                  <StatusBadge value={prospect.status} />
                </div>
              ))
            ) : (
              <p className="px-5 py-8 text-sm text-muted-foreground">
                No prospect records are available yet.
              </p>
            )}
          </div>
        </section>

        <section className="rounded-2xl border bg-card p-5">
          <div className="flex items-start gap-3">
            <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-muted">
              <Clock3 className="size-5" aria-hidden="true" />
            </div>
            <div>
              <h2 className="font-semibold">Action Center</h2>
              <p className="mt-1 text-xs leading-5 text-muted-foreground">
                Exceptions and due work are surfaced here instead of being hidden
                inside individual modules.
              </p>
            </div>
          </div>

          <div className="mt-5 space-y-3">
            {overview.dueFollowups !== null && (
              <div className="rounded-xl border p-4">
                <p className="text-2xl font-bold">{overview.dueFollowups}</p>
                <p className="mt-1 text-sm text-muted-foreground">
                  CRM follow-ups due
                </p>
              </div>
            )}
            {overview.pendingApprovals !== null && (
              <div className="rounded-xl border p-4">
                <p className="text-2xl font-bold">
                  {overview.pendingApprovals}
                </p>
                <p className="mt-1 text-sm text-muted-foreground">
                  approval decisions pending
                </p>
              </div>
            )}
          </div>

          <Link
            href="/dashboard/action-center"
            className="mt-5 inline-flex min-h-11 w-full items-center justify-center rounded-xl border px-4 text-sm font-semibold hover:bg-muted"
          >
            Open Action Center
          </Link>
        </section>
      </div>
    </div>
  );
}
