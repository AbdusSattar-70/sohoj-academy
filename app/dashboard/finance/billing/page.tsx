import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getFinanceWorkspace } from "@/modules/finance/operations/queries";
import { FinanceOperations } from "@/modules/finance/operations/workspace";
export default async function BillingPage({ searchParams }: { searchParams: Promise<{ returnTo?: string }> }) {
  const context = await requirePermission("finance.view");
  const data = await getFinanceWorkspace();
  const requestedReturn = (await searchParams).returnTo;
  const returnTo = requestedReturn && /^\/dashboard\/admissions\/[0-9a-f-]{36}$/i.test(requestedReturn)
    ? requestedReturn : undefined;
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Finance"
        title="Student Accounts"
        description="View and manage student charges, payments, discounts, cancellations, refunds and recurring billing from the student account record."
      />
      {returnTo && <Link href={returnTo} className="inline-block rounded-lg border px-4 py-2 text-sm font-medium">Return to admission case</Link>}
      <FinanceOperations
        data={data}
        permissions={context.permissions}
        returnTo={returnTo}
      />
    </div>
  );
}
