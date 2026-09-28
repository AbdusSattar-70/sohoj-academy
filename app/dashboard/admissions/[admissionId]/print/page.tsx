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
  const offering = data.offerings.find((o) => o.id === batch?.offeringId);
  return (
    <div className="space-y-4">
      <PrintAdmissionButton />
      <style>{`@media print { body * { visibility:hidden; } .admission-document,.admission-document * { visibility:visible; } .admission-document { position:absolute; top:0; left:0; width:100%; padding:0!important; border:0!important; box-shadow:none!important; color:#000!important; background:#fff!important; } .admission-preprinted-header { height:50mm; } .admission-signatures,.admission-office-use { break-inside:avoid; } @page { size:A4; margin:12mm 15mm; } }`}</style>
      <article className="admission-document mx-auto max-w-3xl rounded-xl border bg-white p-8 text-black">
        {receipt ? (
          <header className="border-b pb-5">
            <h1 className="text-2xl font-bold">SOHOJ ACADEMY</h1>
            <h2 className="mt-5 text-lg font-semibold">Payment Receipt</h2>
            <p className="text-sm">{receipt.number}</p>
          </header>
        ) : (
          <>
            <p className="mb-3 text-xs text-gray-500 print:hidden">
              The top 50 mm is reserved for preprinted academy letterhead.
            </p>
            <div className="admission-preprinted-header" aria-hidden="true" />
            <header className="border-b pb-3">
              <h1 className="text-xl font-bold">Student Admission &amp; Consent Form</h1>
              <p className="text-xs">Admission reference: {a.number}</p>
            </header>
          </>
        )}
        <dl className="mt-5 grid grid-cols-2 gap-x-5 gap-y-3 text-sm">
          {[
            ["Student name", a.name],
            ["Student name (Bangla)", a.nameBn || "—"],
            ["Student ID", a.studentNo ?? "Pending admission completion"],
            ["Date of birth", a.dateOfBirth || "—"],
            ["Gender", a.gender || "—"],
            ["Current school", a.schoolName || "—"],
            ["School roll", a.schoolRoll || "—"],
            ["Guardian name", a.guardian],
            ["Relationship", a.guardianRelationship || "—"],
            ["Guardian Mobile", a.mobile],
            ["Alternate Mobile", a.alternateMobile || "—"],
            ["Guardian address", a.guardianAddress || "—"],
            ["Programme", offering?.name ?? "—"],
            ["Class", offering?.className ?? "—"],
            ["Batch", batch?.name ?? "—"],
            ["Case status", a.status.replaceAll("_", " ")],
          ].map(([label, value]) => (
            <div key={label}>
              <dt className="text-xs text-gray-600">{label}</dt>
              <dd className="font-medium">{value}</dd>
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
            {receipt.refunded > 0 && (
              <p className="mt-2 text-sm">
                Subsequently refunded: BDT {receipt.refunded.toFixed(2)}. This
                receipt preserves the original payment.
              </p>
            )}
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
            <section className="mt-5">
              <h2 className="font-semibold">Published fee terms · Plan version {a.feeVersion}</h2>
              <table className="mt-2 w-full text-left text-xs">
                <thead>
                  <tr className="border-b">
                    <th className="py-1">Charge</th>
                    <th>Frequency</th>
                    <th className="text-right">BDT</th>
                  </tr>
                </thead>
                <tbody>
                  {a.components.map((c, i) => (
                    <tr key={i} className="border-b">
                      <td className="py-1">{c.name}</td>
                      <td>{c.recurrence.replaceAll("_", " ")}</td>
                      <td className="text-right">{c.amount.toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
            <p className="mt-2 text-xs">
              {a.invoice
                ? `Invoice ${a.invoice.number}: current outstanding balance BDT ${a.invoice.due.toFixed(2)}. Approved discounts, payments and refunds may change the balance; confirm the current ledger before collection.`
                : "Billing has not been posted. The listed charges are the selected fee plan, subject to approved adjustments."}
            </p>
            <section className="mt-5 space-y-3 border-t pt-4 text-xs leading-5">
              <div>
                <h2 className="font-semibold">Guardian declaration and consent</h2>
                <p>
                  I confirm that the student and guardian details above are accurate to the best of my
                  knowledge. I have reviewed the selected programme, batch and fee terms. I consent to
                  Sohoj Academy using these details to administer the application, contact me about the
                  student&apos;s education, and maintain the admission record. I understand that staff
                  verification, fee processing and enrollment activation are separate steps.
                </p>
              </div>
              <div>
                <h2 className="font-semibold">Student acknowledgement (optional)</h2>
                <p>
                  I have reviewed my programme and will follow the academy&apos;s learning and conduct
                  guidance. My signature is optional when I am unable to sign.
                </p>
              </div>
            </section>
            <div className="admission-signatures mt-12 grid grid-cols-2 gap-x-10 gap-y-10 text-xs">
              <p className="border-t pt-1">Guardian signature &amp; date (required)</p>
              <p className="border-t pt-1">Student signature &amp; date (optional)</p>
            </div>
            <section className="admission-office-use mt-7 border-t pt-3 text-xs">
              <h2 className="font-semibold">Office use / verification</h2>
              <div className="mt-2 grid grid-cols-2 gap-x-8 gap-y-2">
                <p>Identity and eligibility checked: __________</p>
                <p>Consent form received on: ________________</p>
                <p>Student ID issued: {a.studentNo ?? "________________"}</p>
                <p>Verified by: ___________________________</p>
              </div>
              <p className="mt-9 border-t pt-1">Authorized signature &amp; academy seal / date</p>
            </section>
          </>
        )}
        <footer className="mt-5 border-t pt-2 text-xs text-gray-600">
          {receipt
            ? "System-generated receipt. Verify its current refund status in the ERP."
            : "This signed form records consent. It is not a payment receipt or proof of active enrollment."}
        </footer>
      </article>
    </div>
  );
}
