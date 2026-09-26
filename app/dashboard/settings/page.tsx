import {
  LockKeyhole,
  Settings2,
  SlidersHorizontal,
  UsersRound,
} from "lucide-react";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { PolicyControlCenter } from "@/modules/settings/components/policy-control-center";
import { RolePermissionEditor } from "@/modules/settings/components/role-permission-editor";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getSettingsOverview } from "@/modules/settings/queries";
import { can } from "@/types/erp";

export default async function SettingsPage() {
  const context = await requirePermission("system.settings.view");
  const data = await getSettingsOverview();
  const canManagePolicies = can(context, "system.settings.manage");
  const canManageRoles = can(context, "system.roles.manage");

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Control Center"
        title="Settings"
        description="Operational behavior belongs here—not in hard-coded UI logic. Policies are versioned, access is permission-based, and every sensitive change requires a reason and audit trail."
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

      <section className="space-y-4">
        <SectionHeader
          title="Business Policies"
          description="These are active management policies, not code constants. Publishing creates a new version; historical transactions keep the version that governed them."
          badge={canManagePolicies ? "Editable" : "View only"}
        />

        {canManagePolicies ? (
          <PolicyControlCenter rules={data.rules} />
        ) : (
          <ReadOnlyPolicies rules={data.rules} />
        )}
      </section>

      <section className="space-y-4">
        <SectionHeader
          title="Role & Permission Matrix"
          description="Operational roles determine what a user may see or do. Hiding a menu item is not security; the same permissions are enforced by server/database workflows."
          badge={canManageRoles ? "Editable" : "Restricted"}
          icon={LockKeyhole}
        />

        {canManageRoles ? (
          <div className="rounded-2xl border bg-card p-5 sm:p-6">
            <RolePermissionEditor
              roles={data.roles}
              permissions={data.permissions}
            />
          </div>
        ) : (
          <div className="rounded-2xl border border-dashed bg-card p-6 text-sm leading-6 text-muted-foreground">
            You can view Settings, but role-permission editing requires the
            <code className="mx-1 rounded bg-muted px-1.5 py-0.5">
              system.roles.manage
            </code>
            permission.
          </div>
        )}
      </section>

      <section className="rounded-2xl border border-blue-200 bg-blue-50 p-5 text-sm leading-6 text-blue-950 dark:border-blue-900 dark:bg-blue-950/30 dark:text-blue-100">
        Policy and permission changes are written through controlled database
        workflows. Direct browser writes to policy-version and role-permission
        tables are revoked.
      </section>
    </div>
  );
}

function ReadOnlyPolicies({
  rules,
}: {
  rules: Awaited<ReturnType<typeof getSettingsOverview>>["rules"];
}) {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {rules.map((rule) => (
        <article key={rule.id} className="rounded-2xl border bg-card p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.14em] text-muted-foreground">
                {rule.domain}
              </p>
              <h3 className="mt-1 font-semibold">{rule.ruleKey}</h3>
            </div>
            <StatusBadge value={rule.status} />
          </div>
          <pre className="mt-4 overflow-x-auto rounded-xl bg-muted/50 p-4 text-xs leading-5">
            {JSON.stringify(rule.payload, null, 2)}
          </pre>
          <p className="mt-3 text-xs text-muted-foreground">
            Version {rule.version} • Effective {rule.effectiveFrom}
          </p>
        </article>
      ))}
    </div>
  );
}

function SectionHeader({
  title,
  description,
  badge,
  icon: Icon = SlidersHorizontal,
}: {
  title: string;
  description: string;
  badge: string;
  icon?: typeof SlidersHorizontal;
}) {
  return (
    <div className="flex flex-col gap-3 border-b pb-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="flex items-start gap-3">
        <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-muted">
          <Icon className="size-5" aria-hidden="true" />
        </div>
        <div>
          <h2 className="font-semibold">{title}</h2>
          <p className="mt-1 max-w-3xl text-sm leading-6 text-muted-foreground">
            {description}
          </p>
        </div>
      </div>
      <span className="w-fit rounded-full border bg-card px-2.5 py-1 text-xs font-semibold">
        {badge}
      </span>
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
