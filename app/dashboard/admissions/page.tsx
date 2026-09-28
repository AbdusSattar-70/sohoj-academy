import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import { ConsentForm } from "@/modules/admissions/components/consent-form";
import { ReferralForm } from "@/modules/admissions/components/referral-form";
import { getAdmissionReferrals } from "@/modules/admissions/referrals";
import { getConsentDocuments } from "@/modules/admissions/consent";
import { StaffAdmissionIntakeForm } from "@/modules/admissions/components/staff-intake-form";
import type { AdmissionCommand } from "@/modules/admissions/schema";
const nextAction: Record<
  string,
  { action: AdmissionCommand["action"]; label: string; description: string }
> = {
  DRAFT: {
    action: "READY",
    label: "Mark Ready for Acceptance",
    description:
      "Verify the student, guardian, academic placement and inherited charges. Receive the signed consent before accepting the admission.",
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
export default async function AdmissionsPage({
  searchParams,
}: {
  searchParams: Promise<{ prospect?: string }>;
}) {
  const context = await requirePermission("admissions.view");
  const { prospect: prospectParam } = await searchParams;
  const [data, consentDocuments, referrals] = await Promise.all([getAdmissionWorkspace(), getConsentDocuments(), getAdmissionReferrals()]);
  const manage = context.permissions.includes("admissions.create");
  const pay = context.permissions.includes("finance.payments.post");
  const defaultProspectId =
    prospectParam && data.prospects.some((p) => p.id === prospectParam)
      ? prospectParam
      : undefined;
  const preselected = defaultProspectId
    ? data.prospects.find((p) => p.id === defaultProspectId)
    : undefined;
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Student Lifecycle"
        title="Admissions"
        description="Draft → Verify details and signed consent → Accept → Initial billing → Record actual payment → Evaluate enrollment. Each stage is recorded separately."
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
        <section id="start-admission" className="space-y-4 rounded-2xl border bg-muted/10 p-5 sm:p-6">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-700 dark:text-blue-300">Choose how to begin</p>
            <h2 className="mt-1 text-xl font-semibold">Start an admission</h2>
            <p className="mt-1 text-sm text-muted-foreground">Online entry creates an unconfirmed draft. A blank paper form must be entered by staff before a case exists. Review, signed consent, acceptance, billing, payment and enrollment are separate steps.</p>
          </div>
          <div className="grid gap-3 md:grid-cols-3">
            <div className="rounded-xl border bg-card p-4">
              <p className="text-sm font-semibold">New applicant with staff assistance</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">Enter the student and guardian details while they are with you. A CRM Prospect and draft are created together.</p>
              <a className="mt-3 inline-block text-sm font-medium underline" href="#new-applicant">Enter details online</a>
            </div>
            <div className="rounded-xl border bg-card p-4">
              <p className="text-sm font-semibold">Already in Prospects</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">Continue a verified enquiry. Choose the intended offering and an available batch.</p>
              <a className="mt-3 inline-block text-sm font-medium underline" href="#from-prospect">Start from a Prospect</a>
            </div>
            <div className="rounded-xl border bg-card p-4">
              <p className="text-sm font-semibold">Paper application</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">Print a blank A4 form for the student and guardian to complete and sign in person.</p>
              <Link className="mt-3 inline-block text-sm font-medium underline" href="/dashboard/admissions/application-form">Print blank application</Link>
            </div>
          </div>
          <details id="new-applicant" className="rounded-xl border bg-card p-4">
            <summary className="cursor-pointer list-inside font-semibold">Enter a new applicant online</summary>
            <div className="mt-4"><StaffAdmissionIntakeForm data={data} /></div>
          </details>
          <details id="from-prospect" open={Boolean(preselected)} className="rounded-xl border bg-card p-4">
            <summary className="cursor-pointer list-inside font-semibold">Create a draft from an existing Prospect</summary>
            <div className="mt-4 space-y-3">
              {preselected && <p className="rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-950 dark:border-blue-900 dark:bg-blue-950/30 dark:text-blue-100">Starting from <strong>{preselected.number} · {preselected.name}</strong>. Confirm the correct offering and batch before creating the draft.</p>}
              <AdmissionCommandForm action="CREATE" data={data} defaultProspectId={defaultProspectId} label="Create admission draft" description="Student and guardian identity are inherited from the Prospect. The selected offering and batch are revalidated before the draft is created." />
            </div>
          </details>
        </section>
      )}
      <section id="case-register" className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div><h2 className="text-xl font-semibold">Admission cases</h2><p className="mt-1 text-sm text-muted-foreground">Open a case to review documents, fees, current stage and the next allowed action.</p></div>
          <p className="text-sm text-muted-foreground">{data.cases.length} {data.cases.length === 1 ? "case" : "cases"}</p>
        </div>
        {data.cases.length === 0 && <p className="rounded-xl border border-dashed p-6 text-sm text-muted-foreground">No admission cases yet. Start from a new applicant or an existing Prospect above.</p>}
      </section>
      {data.cases.map((a) => {
        const next = nextAction[a.status];
        const due = a.invoice ? a.invoice.due : null;
        const signedForms = consentDocuments.filter((d) => d.admission_id === a.id);
        return (
          <article
            key={a.id}
            id={a.id}
            className="rounded-2xl border bg-card p-4 sm:p-5"
          >
            <details>
              <summary className="flex cursor-pointer list-none flex-wrap items-center justify-between gap-3">
                <span><strong>{a.number} · {a.name}</strong><span className="mt-1 block text-sm text-muted-foreground">{data.batches.find((b) => b.id === a.batchId)?.name ?? "Batch unavailable"} · {a.studentId ? a.studentNo : "Student ID issued on acceptance"}</span></span>
                <span className="flex items-center gap-3"><StatusBadge value={a.status} /><span aria-hidden="true" className="text-sm text-muted-foreground">View case⌄</span></span>
              </summary>
              <div className="mt-5 space-y-5 border-t pt-5">
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
                  Print admission &amp; consent
                </Link>
              </div>
            </div>
            <p className="text-xs text-muted-foreground">
              Give the printed form to the guardian to review and sign. The student may sign if able. Record the signed copy below before marking the application ready.
            </p>
            <section className="rounded-xl border p-4">
              <h3 className="font-semibold">Signed consent evidence</h3>
              {signedForms.length ? <ul className="mt-2 space-y-1 text-sm">{signedForms.map((document) => <li key={document.id}>
                <Link className="underline" href={`/dashboard/admissions/${a.id}/consent/${document.id}`} target="_blank" rel="noopener noreferrer">Open signed form v{document.version}</Link>
                {" · Guardian signed "}{document.guardian_signed_on}{" · Received "}{new Date(document.received_at).toLocaleString()}
              </li>)}</ul> : <p className="mt-2 text-sm text-amber-700">No signed form has been received for this case.</p>}
            </section>
            {manage && ["DRAFT","READY"].includes(a.status) && <ReferralForm admissionId={a.id} people={referrals} choice={referrals.choices.find(r=>r.admission_id===a.id)} />}
            {!(["DRAFT","READY"].includes(a.status)) && <p className="text-sm">Admission source: {referrals.choices.find(r=>r.admission_id===a.id)?.source==="ORGANIC"?"Organic":referrals.people.find(p=>p.id===referrals.choices.find(r=>r.admission_id===a.id)?.referrer_id)?.full_name??"Unrecorded historical source"}</p>}
            {manage && ["DRAFT","READY"].includes(a.status) && <ConsentForm admissionId={a.id} />}
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
            {a.status === "READY" && !signedForms.length && <p role="status" className="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">Waiting for the signed guardian consent. Record the signed form above; acceptance becomes available after it is attached to this case.</p>}
            {manage && next && (a.status !== "READY" || signedForms.length > 0) && (
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
              </div>
            </details>
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
