import { LockKeyhole, Settings2, SlidersHorizontal, UsersRound } from "lucide-react";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getSettingsOverview } from "@/modules/settings/queries";

export default async function SettingsPage() {
  await requirePermission("system.settings.view");
  const data = await getSettingsOverview();

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Control Center"
        title="Settings"
        description="Operational behavior belongs here—not in hard-coded UI logic. Policy changes are versioned, access is permission-based, and sensitive changes remain auditable."
      />

      <section className="grid gap-4 lg:grid-cols-3">
        <ControlCard
          icon={SlidersHorizontal}
          title="Business Policies"
          value={data.rules.length}
          description="Active limits, percentages and workflow policies."
        />
        <ControlCard
          icon={UsersRound}
          title="Access Roles"
          value={data.roles.length}
          description="Role bundles that determine effective ERP permissions."
        />
        <ControlCard
          icon={Settings2}
          title="Typed Settings"
          value={data.settings.length}
          description="Organization/branch preferences with version history."
        />
      </section>

      <section className="rounded-2xl border bg-card">
        <div className="border-b px-5 py-4 sm:px-6">
          <h2 className="font-semibold">Active Business Policies</h2>
          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            These values are defaults only until management publishes another
            version. Historical workflows retain the rule version that governed
            them.
          </p>
        </div>
        <div className="grid gap-4 p-5 sm:p-6 lg:grid-cols-2">
          {data.rules.map((rule) => (
            <article key={rule.id} className="rounded-xl border p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.14em] text-muted-foreground">
                    {rule.domain}
                  </p>
                  <h3 className="mt-1 font-semibold">{rule.rule_key}</h3>
                </div>
                <StatusBadge value={rule.status} />
              </div>
              <pre className="mt-4 overflow-x-auto rounded-lg bg-muted/50 p-3 text-xs leading-5">
                {JSON.stringify(rule.payload, null, 2)}
              </pre>
              <p className="mt-3 text-xs text-muted-foreground">
                Version {rule.version} • Effective {rule.effective_from}
              </p>
            </article>
          ))}
        </div>
      </section>

      <section className="rounded-2xl border bg-card">
        <div className="border-b px-5 py-4 sm:px-6">
          <div className="flex items-center gap-2">
            <LockKeyhole className="size-4" aria-hidden="true" />
            <h2 className="font-semibold">Role & Permission Matrix</h2>
          </div>
          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            ADMIN is the protected recovery authority. Operational roles can be
            given exactly the permissions management wants without redeploying
            the application.
          </p>
        </div>
        <div className="grid gap-4 p-5 sm:p-6 xl:grid-cols-2">
          {data.roles.map((role) => (
            <article key={role.id} className="rounded-xl border p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="font-semibold">{role.name}</h3>
                  <p className="mt-1 text-xs text-muted-foreground">{role.code}</p>
                </div>
                {role.code === "ADMIN" && (
                  <span className="rounded-full border px-2.5 py-1 text-xs font-semibold">
                    Protected
                  </span>
                )}
              </div>

              <div className="mt-4 flex flex-wrap gap-2">
                {role.permissions.map((permission) => (
                  <span
                    key={permission.code}
                    title={permission.name}
                    className="rounded-lg bg-muted px-2.5 py-1 text-xs"
                  >
                    {permission.code}
                  </span>
                ))}
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="rounded-2xl border border-blue-200 bg-blue-50 p-5 text-sm leading-6 text-blue-950 dark:border-blue-900 dark:bg-blue-950/30 dark:text-blue-100">
        Settings editing will use controlled publish actions rather than direct
        table edits. Every sensitive change requires a reason and produces an
        audit correlation ID.
      </section>
    </div>
  );
}

function ControlCard({
  icon: Icon,
  title,
  value,
  description,
}: {
  icon: typeof Settings2;
  title: string;
  value: number;
  description: string;
}) {
  return (
    <div className="rounded-2xl border bg-card p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-muted-foreground">{title}</p>
          <p className="mt-2 text-2xl font-bold">{value}</p>
          <p className="mt-2 text-xs leading-5 text-muted-foreground">
            {description}
          </p>
        </div>
        <div className="flex size-10 items-center justify-center rounded-xl bg-muted">
          <Icon className="size-5" aria-hidden="true" />
        </div>
      </div>
    </div>
  );
}
