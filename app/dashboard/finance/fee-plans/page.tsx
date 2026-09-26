import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { FeePlanForm } from "@/modules/offerings/components/fee-plan-form";
import { getOfferingOverview } from "@/modules/offerings/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { can } from "@/types/erp";

function todayInDhaka() {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Dhaka", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date());
  const part = (name: string) => parts.find((item) => item.type === name)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export default async function FeePlansPage() {
  const context = await requirePermission("finance.view");
  const data = await getOfferingOverview();
  const today = todayInDhaka();
  const offering = (id: string) => data.offerings.find((item) => item.id === id);

  return <div className="space-y-7">
    <PageHeader eyebrow="Finance / Control Center" title="Fee Plans" description="Publish standard charges as versions attached to Programme Offerings. Historical versions remain visible and immutable." />
    {can(context, "finance.billing.manage") && <FeePlanForm data={data} today={today} />}
    <section className="rounded-2xl border bg-card p-5 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3"><div><h2 className="font-semibold">Published Versions</h2><p className="text-sm text-muted-foreground">Amounts shown here are standard fees, before any approved student exception.</p></div>
        {can(context, "academics.view") && <Link href="/dashboard/academics/offerings" className="text-sm font-semibold text-primary underline-offset-4 hover:underline">View Offerings →</Link>}</div>
      {data.plans.length ? <div className="mt-4 space-y-3">{data.plans.map((plan) => <article key={plan.id} className="rounded-xl border p-4">
        <div className="flex flex-wrap items-start justify-between gap-2"><div><h3 className="font-semibold">{offering(plan.offering_id)?.name ?? "Offering"} · Version {plan.version}</h3>
          <p className="text-xs text-muted-foreground">{offering(plan.offering_id)?.code} · {plan.billing_cycle.replaceAll("_", " ")} · effective {plan.effective_from}{plan.effective_to ? ` through ${plan.effective_to}` : ""} · {plan.currency_code}</p></div><StatusBadge value={plan.status} /></div>
        <ul className="mt-3 grid gap-2 text-sm sm:grid-cols-2 lg:grid-cols-3">{data.components.filter((item) => item.fee_plan_version_id === plan.id).map((item) => <li key={item.id} className="rounded-lg bg-muted/50 px-3 py-2">{item.name} <strong className="float-right">{Number(item.amount).toLocaleString("en-BD", { minimumFractionDigits: 2 })}</strong><span className="block text-xs text-muted-foreground">{item.charge_type} · {item.recurrence.replaceAll("_", " ")}</span></li>)}</ul>
        <p className="mt-3 text-xs text-muted-foreground">Reason: {plan.change_reason}</p>
      </article>)}</div> : <p className="mt-5 rounded-xl border border-dashed p-6 text-sm text-muted-foreground">No Fee Plans published. Create a Programme Offering, then publish its standard charges.</p>}
    </section>
  </div>;
}
