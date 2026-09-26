import { PageHeader } from "@/components/erp/page-header";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getFinanceWorkspace } from "@/modules/finance/operations/queries";
import { FinanceOperations } from "@/modules/finance/operations/workspace";
export default async function BillingPage() {
  const context = await requirePermission("finance.view");
  const data = await getFinanceWorkspace();
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Finance"
        title="Billing & Adjustments"
        description="Manage student balances, approved discounts, cancellations, refund payouts and recurring charges with a complete financial history."
      />
      <FinanceOperations
        data={data}
        permissions={context.permissions}
        profileId={context.profileId}
      />
    </div>
  );
}
