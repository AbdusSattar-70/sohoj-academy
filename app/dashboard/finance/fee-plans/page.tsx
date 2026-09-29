import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { FeePlanForm } from "@/modules/offerings/components/fee-plan-form";
import { getOfferingOverview } from "@/modules/offerings/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { can } from "@/types/erp";

function todayInDhaka() {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Dhaka", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date());
  const part = (name: string) => parts.find((item) => item.type === name)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}
function money(amount: number, currency: string) {
  return new Intl.NumberFormat("en-BD", { style: "currency", currency, minimumFractionDigits: 2 }).format(amount);
}

export default async function FeePlansPage({
  searchParams,
}: {
  searchParams: Promise<{ edit?: string; new?: string }>;
}) {
  const context = await requirePermission("finance.view");
  const data = await getOfferingOverview();
  const { edit, new: create } = await searchParams;
  const selected = edit && data.offerings.some((item) => item.id === edit) ? edit : null;
  const formOpen = can(context, "finance.billing.manage") && (create === "1" || !!selected);
  const offering = (id: string) => data.offerings.find((item) => item.id === id);
  const today = todayInDhaka();

  return <div className="space-y-7">
    <PageHeader
      eyebrow="Academy Setup"
      title="Fee Plans"
      description="Set the current standard charges for each programme offering. Saved changes apply to future admissions and bills; existing posted charges retain their original terms."
      actions={can(context, "finance.billing.manage") &&
        <Link href="/dashboard/finance/fee-plans?new=1#fee-plan-form" className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground">Create Fee Plan</Link>}
    />
    {formOpen && <section id="fee-plan-form" className="scroll-mt-24">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="text-lg font-semibold">{selected ? `Edit ${offering(selected)?.name ?? "Fee Plan"}` : "Create a Fee Plan"}</h2>
        <Link href="/dashboard/finance/fee-plans" className="rounded-lg border px-3 py-2 text-sm">Close form</Link>
      </div>
      <FeePlanForm data={data} today={today} initialOfferingId={selected ?? undefined} />
    </section>}
    <section className="rounded-2xl border bg-card p-5 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div><h2 className="font-semibold">Current Fee Plans</h2><p className="text-sm text-muted-foreground">Standard charges before a student-specific discount.</p></div>
        {can(context, "academics.view") && <Link href="/dashboard/academics/offerings" className="text-sm font-semibold text-primary underline">View Offerings</Link>}
      </div>
      {data.plans.length ? <div className="mt-4 overflow-x-auto">
        <table className="w-full min-w-[720px] text-left text-sm">
          <thead><tr className="border-b text-muted-foreground"><th className="py-3 pr-3">Offering</th><th className="pr-3">Billing</th><th className="pr-3">Current charges</th><th className="pr-3">Status</th><th>Action</th></tr></thead>
          <tbody>{data.plans.map((plan) => {
            const charges = data.components.filter((item) => item.fee_plan_version_id === plan.id);
            const total = charges.reduce((sum, item) => sum + Number(item.amount), 0);
            return <tr key={plan.id} className="border-b last:border-0">
              <td className="py-4 pr-3"><span className="block font-medium">{offering(plan.offering_id)?.name ?? "Offering"}</span><span className="text-xs text-muted-foreground">{offering(plan.offering_id)?.code}</span></td>
              <td className="pr-3">{plan.billing_cycle.replaceAll("_", " ")}{plan.due_day ? ` · due day ${plan.due_day}` : ""}</td>
              <td className="pr-3"><strong>{money(total, plan.currency_code)}</strong><span className="mt-1 block text-xs text-muted-foreground">{charges.map((item) => `${item.name}: ${money(Number(item.amount), plan.currency_code)}`).join(" · ") || "No components"}</span></td>
              <td className="pr-3">{plan.status === "ACTIVE" ? "Current" : "Unavailable"}</td>
              <td>{can(context, "finance.billing.manage") && <Link href={`/dashboard/finance/fee-plans?edit=${plan.offering_id}#fee-plan-form`} className="rounded-lg border px-3 py-2 font-medium">Edit</Link>}</td>
            </tr>;
          })}</tbody>
        </table>
      </div> : <p className="mt-5 rounded-xl border border-dashed p-6 text-sm text-muted-foreground">No Fee Plans yet. Create an offering, then add its standard charges.</p>}
    </section>
  </div>;
}
