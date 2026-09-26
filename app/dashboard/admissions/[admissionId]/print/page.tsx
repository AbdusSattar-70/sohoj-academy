import { notFound } from "next/navigation";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { PrintAdmissionButton } from "@/modules/admissions/components/print-button";
export default async function AdmissionDocument({
  params,
  searchParams,
}: {
  params: Promise<{ admissionId: string }>;
  searchParams: Promise<{ receipt?: string }>;
}) {
  await requirePermission("admissions.view");
  const { admissionId } = await params;
  const query = await searchParams;
  const data = await getAdmissionWorkspace();
  const a = data.cases.find((row) => row.id === admissionId);
  if (!a) notFound();
  const receipt = query.receipt
    ? a.receipts.find((r) => r.number === query.receipt)
    : null;
  if (query.receipt && !receipt) notFound();
  const batch = data.batches.find((b) => b.id === a.batchId);
  return (
    <div className="space-y-4">
      <PrintAdmissionButton />
      <style>{`@media print { body * { visibility:hidden; } .admission-document,.admission-document * { visibility:visible; } .admission-document { position:absolute; top:0; left:0; width:100%; border:0!important; box-shadow:none!important; color:#000!important; background:#fff!important; } @page { size:A4; margin:15mm; } }`}</style>
      <article className="admission-document mx-auto max-w-3xl rounded-xl border bg-white p-8 text-black">
        <header className="border-b pb-5">
          <h1 className="text-2xl font-bold">SOHOJ ACADEMY</h1>
          <p className="text-sm">
            Gopalpur Bazar, Narundi Road, Jamalpur Sadar
          </p>
          <h2 className="mt-5 text-lg font-semibold">
            {receipt ? "Payment Receipt" : "Student Admission Form"}
          </h2>
          <p className="text-sm">{receipt ? receipt.number : a.number}</p>
        </header>
        <dl className="mt-6 grid grid-cols-2 gap-5 text-sm">
          {[
            ["Student", a.name],
            ["Student ID", a.studentNo ?? "Not issued — draft"],
            ["Guardian", a.guardian],
            ["Guardian Mobile", a.mobile],
            ["Batch", batch?.name ?? "—"],
            ["Admission Status", a.status.replaceAll("_", " ")],
          ].map(([label, value]) => (
            <div key={label}>
              <dt className="text-xs text-gray-600">{label}</dt>
              <dd className="mt-1 font-medium">{value}</dd>
            </div>
          ))}
        </dl>
        {receipt ? (
          <section className="mt-8 border-y py-5">
            <p>Actual amount received</p>
            <p className="mt-1 text-2xl font-bold">
              BDT {receipt.amount.toFixed(2)}
            </p>
            <p className="mt-3 text-sm">Method: {receipt.method}</p>
            <p className="text-sm">
              Posted:{" "}
              {new Date(receipt.postedAt).toLocaleString("en-GB", {
                timeZone: "Asia/Dhaka",
              })}
            </p>
            <p className="mt-2 text-sm">
              Allocated to invoice {a.invoice?.number}.
            </p>
          </section>
        ) : (
          <>
            <section className="mt-8">
              <h3 className="font-semibold">
                Standard Fee Terms · Version {a.feeVersion}
              </h3>
              <table className="mt-3 w-full text-left text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2">Charge</th>
                    <th>Frequency</th>
                    <th className="text-right">BDT</th>
                  </tr>
                </thead>
                <tbody>
                  {a.components.map((c, i) => (
                    <tr key={i} className="border-b">
                      <td className="py-2">{c.name}</td>
                      <td>{c.recurrence.replaceAll("_", " ")}</td>
                      <td className="text-right">{c.amount.toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
            <p className="mt-5 text-sm">
              {a.invoice
                ? `Invoice: ${a.invoice.number}. Billed BDT ${a.invoice.total.toFixed(2)}; paid BDT ${a.invoice.paid.toFixed(2)}; outstanding BDT ${(a.invoice.total - a.invoice.paid).toFixed(2)}.`
                : "Initial billing has not been posted."}
            </p>
            <p className="mt-2 text-xs">
              This admission form is not a payment receipt.
            </p>
            <div className="mt-16 grid grid-cols-2 gap-12 text-sm">
              <p className="border-t pt-2">Student signature / date</p>
              <p className="border-t pt-2">Guardian signature / date</p>
            </div>
          </>
        )}
        <footer className="mt-10 border-t pt-3 text-xs text-gray-600">
          System-generated record. Verify the current admission and payment
          status in the ERP.
        </footer>
      </article>
    </div>
  );
}
