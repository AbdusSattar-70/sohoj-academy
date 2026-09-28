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
        title="Student Accounts"
        description="View and manage student charges, payments, discounts, cancellations, refunds and recurring billing from the student account record."
      />
      <FinanceOperations
        data={data}
        permissions={context.permissions}
      />
    </div>
  );
}
