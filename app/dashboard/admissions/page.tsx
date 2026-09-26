import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import type { AdmissionCommand } from "@/modules/admissions/schema";
const nextAction: Record<
  string,
  { action: AdmissionCommand["action"]; label: string; description: string }
> = {
  DRAFT: {
    action: "READY",
    label: "Mark Ready for Acceptance",
    description:
      "Verify the student, guardian, academic placement and inherited standard charges below.",
  },
  READY: {
    action: "ACCEPT",
    label: "Accept Admission",
    description:
      "Creates the permanent Student identity and pins the current activation policy. No payment or enrollment is created yet.",
  },
  ACCEPTED: {
    action: "BILL",
    label: "Post Initial Billing",
    description:
      "Post the first billing cycle plus one-time charges from the pinned Fee Plan. The unpaid amount remains receivable.",
  },
  BILLING_POSTED: {
    action: "ACTIVATE",
    label: "Evaluate Enrollment Activation",
    description:
      "Apply the pinned payment policy and current batch capacity. Activation may be allowed with an outstanding balance.",
  },
  PENDING_PAYMENT: {
    action: "ACTIVATE",
    label: "Recheck Enrollment Activation",
    description:
      "After the required payment is posted, recheck policy conditions and seat availability.",
  },
};
export default async function AdmissionsPage() {
  const context = await requirePermission("admissions.view");
  const data = await getAdmissionWorkspace();
  const manage = context.permissions.includes("admissions.create");
  const pay = context.permissions.includes("finance.payments.post");
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Student Lifecycle"
        title="Admissions"
        description="Draft → Review → Accept → Initial Billing → Enrollment. Payments and receipts are recorded separately when money is received."
      />
      <div className="flex flex-wrap gap-4 text-sm print:hidden">
        <Link href="/dashboard/finance/billing" className="underline">
          Billing, Discounts & Refunds
        </Link>
        <Link href="/dashboard/crm/prospects" className="underline">
          Prospects
        </Link>
        <Link href="/dashboard/academics/batches" className="underline">
          Batch setup
        </Link>
        <Link href="/dashboard/students" className="underline">
          Student register
        </Link>
      </div>
      {manage && (
        <AdmissionCommandForm
          action="CREATE"
          data={data}
          label="Create Admission Draft"
          description="Start from a Prospect and select an eligible batch. Review the inherited fees before accepting admission."
        />
      )}
      {data.cases.map((a) => {
        const next = nextAction[a.status];
        const due = a.invoice ? a.invoice.due : null;
        return (
          <article
            key={a.id}
            id={a.id}
            className="space-y-5 rounded-2xl border bg-card p-5 sm:p-6"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="text-lg font-semibold">
                  {a.number} · {a.name}
                </h2>
                <p className="text-sm text-muted-foreground">
                  {a.studentId ? (
                    <Link
                      className="underline"
                      href={`/dashboard/students/${a.studentId}`}
                    >
                      {a.studentNo}
                      {a.existingStudent ? " · Existing student" : ""}
                    </Link>
                  ) : (
                    "Student ID issued on acceptance"
                  )}{" "}
                  · {data.batches.find((b) => b.id === a.batchId)?.name}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <StatusBadge value={a.status} />
                <Link
                  href={`/dashboard/admissions/${a.id}/print`}
                  className="text-sm underline print:hidden"
                >
                  Admission Form
                </Link>
              </div>
            </div>
            <div className="grid gap-4 md:grid-cols-3">
              <div>
                <p className="text-xs text-muted-foreground">Guardian</p>
                <p>{a.guardian}</p>
                <p className="text-sm">{a.mobile}</p>
              </div>
              <div>
                <p className="text-xs text-muted-foreground">
                  Standard Fee Plan
                </p>
                <p>Version {a.feeVersion}</p>
                <p className="text-xs text-muted-foreground">
                  Historical fee terms stay attached to this case.
                </p>
              </div>
              <div>
                <p className="text-xs text-muted-foreground">
                  Activation Policy
                </p>
                <p>
                  {a.policyVersion
                    ? `Version ${a.policyVersion} · ${a.paymentRequirement?.replaceAll("_", " ")}`
                    : "Pinned at acceptance"}
                </p>
              </div>
            </div>
            <section className="rounded-xl border p-4">
              <h3 className="font-semibold">Inherited Standard Charges</h3>
              <ul className="mt-2 space-y-2 text-sm">
                {a.components.map((c, i) => (
                  <li key={i} className="flex justify-between gap-4">
                    <span>
                      {c.name} · {c.recurrence.replaceAll("_", " ")}
                    </span>
                    <strong>BDT {c.amount.toFixed(2)}</strong>
                  </li>
                ))}
              </ul>
              <p className="mt-3 border-t pt-3 font-semibold">
                Initial total: BDT{" "}
                {a.components.reduce((sum, c) => sum + c.amount, 0).toFixed(2)}
              </p>
            </section>
            {a.invoice && (
              <section className="rounded-xl border p-4">
                <h3 className="font-semibold">Invoice {a.invoice.number}</h3>
                <div className="mt-3 grid gap-3 sm:grid-cols-3">
                  <p>
                    Billed
                    <br />
                    <strong>BDT {a.invoice.total.toFixed(2)}</strong>
                  </p>
                  <p>
                    Actual payments
                    <br />
                    <strong>BDT {a.invoice.paid.toFixed(2)}</strong>
                  </p>
                  <p>
                    Outstanding balance
                    <br />
                    <strong>BDT {due?.toFixed(2)}</strong>
                  </p>
                </div>
                <p className="mt-2 text-xs text-muted-foreground">
                  Approved credits: BDT {a.invoice.credits.toFixed(2)} · Refunds
                  paid: BDT {a.invoice.refunded.toFixed(2)} · Customer credit:
                  BDT {a.invoice.credit.toFixed(2)}. Due {a.invoice.dueOn}. This
                  invoice records charges; it is not a payment receipt.
                </p>
              </section>
            )}
            {manage &&
              !a.existingStudent &&
              ["DRAFT", "READY"].includes(a.status) && (
                <details className="print:hidden">
                  <summary className="cursor-pointer text-sm">
                    Correct student / guardian details
                  </summary>
                  <AdmissionCommandForm
                    action="EDIT_DRAFT"
                    admissionId={a.id}
                    data={data}
                    identity={a}
                    label="Save Draft Details"
                    description="Changes return the case to Draft for a fresh review and remain in the audit history."
                  />
                </details>
              )}
            {manage && next && (
              <AdmissionCommandForm
                key={`${a.id}-${a.status}`}
                {...next}
                admissionId={a.id}
                data={data}
              />
            )}
            {manage && ["DRAFT", "READY"].includes(a.status) && (
              <details className="print:hidden">
                <summary className="cursor-pointer text-sm">
                  Fee Plan changed?
                </summary>
                <AdmissionCommandForm
                  action="REFRESH_FEES"
                  admissionId={a.id}
                  data={data}
                  label="Refresh Standard Fees"
                  description="Load the latest effective plan and return this case to Draft for a fresh review."
                />
              </details>
            )}
            {a.status === "ACTIVE_ENROLLMENT" && (
              <p
                role="status"
                className="rounded-xl border border-emerald-300 bg-emerald-50 p-4 text-sm text-emerald-950 dark:bg-emerald-950 dark:text-emerald-100"
              >
                Enrollment is active. The student is included in active-student
                counts. Any unpaid balance remains due.
              </p>
            )}
            {pay && due !== null && due > 0 && (
              <AdmissionCommandForm
                action="PAY"
                admissionId={a.id}
                data={data}
                maxAmount={due}
                label="Post Actual Payment"
                description="Confirm money has actually been received. Posting creates an allocation and permanent receipt; it does not automatically activate enrollment."
              />
            )}
            {!!a.receipts.length && (
              <section>
                <h3 className="font-semibold">Payment Receipts</h3>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  {a.receipts.map((r) => (
                    <div key={r.number} className="rounded-xl border p-4">
                      <Link
                        className="font-semibold underline"
                        href={`/dashboard/admissions/${a.id}/print?receipt=${r.number}`}
                      >
                        {r.number} · Print
                      </Link>
                      <p>BDT {r.amount.toFixed(2)} received</p>
                      {r.refunded > 0 && (
                        <p className="text-sm">
                          BDT {r.refunded.toFixed(2)} subsequently refunded.
                        </p>
                      )}
                      <p className="text-sm text-muted-foreground">
                        {r.method} ·{" "}
                        {new Date(r.postedAt).toLocaleString("en-GB", {
                          timeZone: "Asia/Dhaka",
                        })}
                      </p>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </article>
        );
      })}
      {!data.cases.length && (
        <p className="rounded-xl border border-dashed p-6 text-sm">
          No Admission Cases yet. Create a Prospect through the Interest form,
          configure an offering and Fee Plan, create a batch, then start a
          draft.
        </p>
      )}
    </div>
  );
}
