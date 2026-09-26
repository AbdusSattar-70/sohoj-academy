import { notFound } from "next/navigation";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getFinanceWorkspace } from "@/modules/finance/operations/queries";
import { PrintAdmissionButton } from "@/modules/admissions/components/print-button";
export default async function Statement({
  params,
}: {
  params: Promise<{ invoiceId: string }>;
}) {
  await requirePermission("finance.view");
  const { invoiceId } = await params;
  const data = await getFinanceWorkspace();
  const i = data.invoices.find((r) => r.id === invoiceId);
  if (!i) notFound();
  const a = data.admissions.find((r) => r.id === i.admissionId);
  return (
    <div className="space-y-4">
      <PrintAdmissionButton />
      <style>{`@media print { body * { visibility:hidden; } .finance-document,.finance-document * { visibility:visible; } .finance-document { position:absolute; top:0; left:0; width:100%; border:0!important; color:#000!important; background:#fff!important; } @page { size:A4; margin:15mm; } }`}</style>
      <article className="finance-document mx-auto max-w-3xl rounded-xl border bg-white p-8 text-black">
        <h1 className="text-2xl font-bold">SOHOJ ACADEMY</h1>
        <h2 className="mt-5 text-lg font-semibold">
          Invoice Account Statement · {i.number}
        </h2>
        <p className="mt-2 text-sm">
          {i.name} · {a?.number} · {a?.status.replaceAll("_", " ")}
        </p>
        <p className="text-sm">
          Billing period {i.period} · Due {i.dueOn}
        </p>
        <table className="mt-6 w-full text-left text-sm">
          <thead>
            <tr className="border-b">
              <th className="py-2">Original charge</th>
              <th className="text-right">{i.currency}</th>
            </tr>
          </thead>
          <tbody>
            {i.lines.map((l, n) => (
              <tr key={n} className="border-b">
                <td className="py-2">{l.name}</td>
                <td className="text-right">{l.amount.toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <dl className="mt-6 grid grid-cols-2 gap-4 text-sm">
          {[
            ["Original charges", i.gross],
            ["Approved credits", i.credits],
            ["Net charges", i.net],
            ["Actual payments", i.paid],
            ["Actual refunds", i.refunded],
            ["Outstanding balance", i.due],
            ["Customer credit", i.credit],
            ["Refunds authorized but not paid", i.reserved],
          ].map(([label, value]) => (
            <div key={label}>
              <dt>{label}</dt>
              <dd className="font-semibold">
                {i.currency} {Number(value).toFixed(2)}
              </dd>
            </div>
          ))}
        </dl>
        <h3 className="mt-7 font-semibold">Money Received</h3>
        {data.payments
          .filter((p) => p.invoiceId === i.id)
          .map((p) => (
            <p key={p.id} className="mt-2 text-sm">
              {p.number} · {i.currency} {p.amount.toFixed(2)} · {p.method} ·{" "}
              {new Date(p.postedAt).toLocaleString("en-GB", {
                timeZone: "Asia/Dhaka",
              })}
            </p>
          ))}
        <h3 className="mt-7 font-semibold">Money Returned</h3>
        {data.refunds
          .filter((r) => r.invoiceId === i.id && r.number)
          .map((r) => (
            <p key={r.id} className="mt-2 text-sm">
              {r.number} · {i.currency} {r.amount.toFixed(2)} · {r.method} ·{" "}
              {r.reference ?? "No external reference"}
            </p>
          ))}
        <p className="mt-8 border-t pt-3 text-xs">
          Current statement generated{" "}
          {new Date().toLocaleString("en-GB", { timeZone: "Asia/Dhaka" })}.
          Original receipts remain evidence of money received; refunds are
          recorded separately. This statement is not a new receipt.
        </p>
      </article>
    </div>
  );
}
