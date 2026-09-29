import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { RolePermissionEditor } from "@/modules/settings/components/role-permission-editor";
import { UserAccessEditor } from "@/modules/settings/components/user-access-editor";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getSettingsOverview } from "@/modules/settings/queries";
import { can } from "@/types/erp";

export default async function AccessSecurityPage() {
  const context = await requirePermission("system.settings.view");
  const data = await getSettingsOverview();
  const canManageRoles = can(context, "system.roles.manage");
  const canManageUsers = can(context, "system.users.manage");

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Academy Setup"
        title="Access & Security"
        description="Manage staff access and teaching roles. Changes are checked by database permissions and recorded in the audit trail. Bootstrap admin recovery access stays protected."
      />
      <div className="rounded-2xl border bg-card p-5 text-sm">
        Looking for capacity, enrollment or compensation settings?{" "}
        <Link href="/dashboard/governance/rules" className="font-medium text-primary underline">
          Open Operating Rules
        </Link>
      </div>
      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Staff access</h2>
        <p className="text-sm text-muted-foreground">
          Assign a role only after checking the staff member. Teacher access is limited to assigned work; admin actions require admin permission.
        </p>
        {canManageUsers ? (
          <div className="rounded-2xl border bg-card p-5 sm:p-6">
            <UserAccessEditor users={data.accessUsers} roles={data.roles} />
          </div>
        ) : (
          <p className="rounded-2xl border border-dashed p-5 text-sm text-muted-foreground">
            You can view this page, but only an authorized admin can change staff access.
          </p>
        )}
      </section>
      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Role permissions</h2>
        <p className="text-sm text-muted-foreground">
          Review the abilities attached to each role. Server and database checks enforce these permissions.
        </p>
        {canManageRoles ? (
          <div className="rounded-2xl border bg-card p-5 sm:p-6">
            <RolePermissionEditor roles={data.roles} permissions={data.permissions} />
          </div>
        ) : (
          <p className="rounded-2xl border border-dashed p-5 text-sm text-muted-foreground">
            Role permission changes require admin access.
          </p>
        )}
      </section>
    </div>
  );
}
