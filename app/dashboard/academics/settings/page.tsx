import { PageHeader } from "@/components/erp/page-header";
import { MasterDataWorkspace } from "@/modules/crm/manage/components/master-data-workspace";
import { getManageCrmOverview } from "@/modules/crm/manage/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { can } from "@/types/erp";

export default async function AcademicSettingsPage() {
  const context = await requirePermission("system.master_data.manage");
  const data = await getManageCrmOverview();
  const canManage = can(context, "system.master_data.manage");

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Academic setup"
        title="Academic & registration settings"
        description="Manage classes, subjects, years, programmes and reusable registration lists. Public forms use these lists; they are not website content. Deactivate rather than delete so history stays intact."
      />

      <MasterDataWorkspace data={data} canManage={canManage} />
    </div>
  );
}
