import { ActionPanel } from "@/components/erp/action-panel";
import { StaffRegister } from "@/modules/staff/components/staff-register";
import { RecordStateButton } from "@/components/erp/record-state-button";
import { StaffEditButton } from "@/components/erp/staff-edit-button";
import { UsersRound } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { CreateStaffForm } from "@/modules/staff/components/create-staff-form";
import { getStaffFormOptions, getStaffList } from "@/modules/staff/queries";
import { can } from "@/types/erp";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function StaffPage() {
  const context = await requirePermission("staff.view");
  const [rows, formOptions] = await Promise.all([
    getStaffList(),
    can(context, "staff.manage")
      ? getStaffFormOptions()
      : Promise.resolve({ roles: [], subjects: [] }),
  ]);

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="People"
        title="Staff"
        description="Staff is the permanent person identity. Teacher, Academic Director, Operator and other responsibilities are assignments on that identity, not separate person records."
      />

      {can(context, "staff.manage") && (
        <ActionPanel title="Create staff identity"><CreateStaffForm
          roles={formOptions.roles}
          subjects={formOptions.subjects}
        /></ActionPanel>
      )}

      {rows.length ? (
        <StaffRegister rows={rows} canManage={can(context,"staff.manage")} />
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
