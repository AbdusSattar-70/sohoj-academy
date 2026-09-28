import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import { PhysicalConsentForm } from "@/modules/admissions/components/physical-consent-form";
import { ReferralForm } from "@/modules/admissions/components/referral-form";
import { getAdmissionReferrals } from "@/modules/admissions/referrals";
import { getConsentDocuments, getPhysicalConsentReceipts } from "@/modules/admissions/consent";
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
  const [data, consentDocuments, physicalReceipts, referrals] = await Promise.all([getAdmissionWorkspace(), getConsentDocuments(), getPhysicalConsentReceipts(), getAdmissionReferrals()]);
  const manage = context.permissions.includes("admissions.create");
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
        description="Verify the application, record referral and paper consent, then accept. Billing and enrollment follow as separate steps."
      />
      <div className="flex flex-wrap gap-4 text-sm print:hidden">
        <Link href="/dashboard/crm/prospects" className="underline">Prospects</Link>
        <Link href="/dashboard/academics/batches" className="underline">Batch setup</Link>
        <Link href="/dashboard/students" className="underline">Student register</Link>
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
          <div><h2 className="text-xl font-semibold">Admission cases</h2><p className="mt-1 text-sm text-muted-foreground">Each case shows the next decision and the checks needed to complete it. Financial operations continue in Finance after acceptance.</p></div>
          <p className="text-sm text-muted-foreground">{data.cases.length} {data.cases.length === 1 ? "case" : "cases"}</p>
        </div>
        {data.cases.length === 0 && <p className="rounded-xl border border-dashed p-6 text-sm text-muted-foreground">No admission cases yet. Start from a new applicant or an existing Prospect above.</p>}
      </section>
      {data.cases.map((a) => {
        const next = nextAction[a.status];
        const batch = data.batches.find((item) => item.id === a.batchId);
        const signedForms = consentDocuments.filter((item) => item.admission_id === a.id);
        const paperReceipts = physicalReceipts.filter((item) => item.admission_id === a.id);
        const hasConsent = signedForms.length > 0 || paperReceipts.length > 0;
        const referral = referrals.choices.find((item) => item.admission_id === a.id);
        const referralReady = !!referral;
        const isVerified = a.status !== "DRAFT" && a.status !== "CANCELLED";
        const canAccept = isVerified && hasConsent && referralReady && a.status === "READY";
        const total = a.components.reduce((sum, component) => sum + component.amount, 0);
        const preAcceptance = ["DRAFT", "READY"].includes(a.status);
        const accepted = ["ACCEPTED", "BILLING_POSTED", "PENDING_PAYMENT", "ACTIVE_ENROLLMENT"].includes(a.status);
        const billed = ["BILLING_POSTED", "PENDING_PAYMENT", "ACTIVE_ENROLLMENT"].includes(a.status);
        const requiredRecordsComplete = referralReady && hasConsent;
        const canContinueFinance = requiredRecordsComplete && accepted;
        const steps = [
          { title: "Verify application", done: isVerified, active: a.status === "DRAFT" },
          { title: "Record referral", done: isVerified && referralReady, active: isVerified && !referralReady },
          { title: "File paper consent", done: isVerified && referralReady && hasConsent, active: isVerified && referralReady && !hasConsent },
          { title: "Accept admission", done: accepted && requiredRecordsComplete, active: a.status === "READY" && canAccept },
          { title: "Post initial bill", done: billed && requiredRecordsComplete, active: a.status === "ACCEPTED" && canContinueFinance },
          { title: "Activate enrollment", done: a.status === "ACTIVE_ENROLLMENT" && requiredRecordsComplete, active: ["BILLING_POSTED", "PENDING_PAYMENT"].includes(a.status) && canContinueFinance },
        ];
        return (
          <article key={a.id} id={a.id} className="rounded-2xl border bg-card p-4 sm:p-6">
            <header className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Admission case</p>
                <h2 className="mt-1 text-lg font-semibold">{a.number} · {a.name}</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  {batch?.name ?? "Batch unavailable"} · {a.studentId ? (
                    <Link className="underline" href={`/dashboard/students/${a.studentId}`}>{a.studentNo}{a.existingStudent ? " · Existing student" : ""}</Link>
                  ) : "Student ID issued on acceptance"}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-3">
                <StatusBadge value={a.status} />
                <Link href={`/dashboard/admissions/${a.id}/print`} className="rounded-lg border px-3 py-2 text-sm font-medium underline-offset-2 hover:underline print:hidden">
                  Print application &amp; consent
                </Link>
              </div>
            </header>

            <ol aria-label="Admission progress" className="mt-5 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {steps.map((step, index) => (
                <li key={step.title} className={`flex items-center gap-3 rounded-lg border p-3 text-sm ${step.active ? "border-primary bg-primary/5 font-medium" : step.done ? "border-emerald-200 bg-emerald-50/50 dark:border-emerald-900" : "text-muted-foreground"}`}>
                  <span className={`flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold ${step.done ? "bg-emerald-600 text-white" : step.active ? "bg-primary text-primary-foreground" : "bg-muted"}`}>{step.done ? "✓" : index + 1}</span>
                  <span>{step.title}</span>
                </li>
              ))}
            </ol>

            {preAcceptance && (
              <div className="mt-5 space-y-4">
                <div className="rounded-xl border bg-muted/20 p-4">
                  <h3 className="font-semibold">{a.status === "DRAFT" ? "Review this application" : "Admission review"}</h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Confirm the student, guardian, programme placement and published fee plan. Keep the guardian-signed paper in the physical student file. Referral and consent must be recorded before you accept.
                  </p>
                  <div className="mt-3 grid gap-2 text-sm sm:grid-cols-2">
                    <p><span className="text-muted-foreground">Guardian:</span> {a.guardian} · {a.mobile}</p>
                    <p><span className="text-muted-foreground">Placement:</span> {batch?.offeringName ?? "Programme"} · {batch?.name ?? "Batch unavailable"}</p>
                    <p><span className="text-muted-foreground">Fee plan:</span> Version {a.feeVersion} · initial charges BDT {total.toFixed(2)}</p>
                    <p><span className="text-muted-foreground">Referral:</span> {referral ? referral.source === "ORGANIC" ? "Organic" : referrals.people.find((person) => person.id === referral.referrer_id)?.full_name ?? "Referred person" : "Not recorded"}</p>
                  </div>
                </div>
                {a.status === "READY" && !referralReady && manage && <ReferralForm admissionId={a.id} people={referrals} choice={referral} />}
                {a.status === "READY" && referralReady && (
                  <section className="rounded-xl border p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h3 className="font-semibold">3. Signed paper consent</h3>
                      <p className="mt-1 text-sm text-muted-foreground">{hasConsent ? "Receipt recorded. Keep the original in the student file." : "Print the form, have the guardian review and sign it, then confirm receipt here."}</p>
                    </div>
                    {!hasConsent && <Link className="text-sm font-medium underline" href={`/dashboard/admissions/${a.id}/print`}>Print form</Link>}
                  </div>
                  {paperReceipts.length > 0 && <ul className="mt-3 space-y-1 text-sm">{paperReceipts.map((receipt) => (
                    <li key={receipt.id}>Paper copy received · guardian signed {receipt.guardian_signed_on}{receipt.student_signed ? " · student also signed" : ""}{receipt.physical_copy_reference ? ` · Filed: ${receipt.physical_copy_reference}` : ""}</li>
                  ))}</ul>}
                  {signedForms.length > 0 && <p className="mt-3 text-sm">Legacy digital consent record exists ({signedForms.map((item) => `v${item.version}`).join(", ")}).</p>}
                  {!hasConsent && manage && <div className="mt-4"><PhysicalConsentForm admissionId={a.id} /></div>}
                  </section>
                )}
                {manage && !a.existingStudent && (
                  <details className="rounded-xl border p-4 print:hidden">
                    <summary className="cursor-pointer font-medium">Correct student or guardian details</summary>
                    <p className="mt-2 text-sm text-muted-foreground">Corrections return the case to Draft and remain in its audit history.</p>
                    <div className="mt-3"><AdmissionCommandForm action="EDIT_DRAFT" admissionId={a.id} data={data} identity={a} label="Save corrected details" description="Use the guardian-confirmed information from the application." /></div>
                  </details>
                )}
                {manage && a.status === "DRAFT" && (
                  <AdmissionCommandForm
                    key={`${a.id}-READY`}
                    action="READY"
                    admissionId={a.id}
                    data={data}
                    label="Complete verification"
                    description="Move this application to the acceptance review queue after checking identity, placement and fees. Referral and signed paper consent are checked before final acceptance."
                  />
                )}
                {a.status === "READY" && (
                  <section className="rounded-xl border-2 border-primary/20 bg-primary/[0.03] p-4">
                    <h3 className="font-semibold">Ready for acceptance</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {canAccept ? "The referral source and signed consent are recorded. Review the case once more, then accept to issue the permanent Student ID." : `Still needed: ${[!referralReady && "record the admission source", !hasConsent && "confirm the guardian-signed paper form"].filter(Boolean).join(" and ")}.`}
                    </p>
                    {manage && canAccept && next && <div className="mt-4"><AdmissionCommandForm key={`${a.id}-ACCEPT`} {...next} admissionId={a.id} data={data} /></div>}
                  </section>
                )}
              </div>
            )}

            {!preAcceptance && a.status !== "CANCELLED" && (
              <div className="mt-5 space-y-4">
                <section className="rounded-xl border bg-muted/20 p-4">
                  <h3 className="font-semibold">{!requiredRecordsComplete ? "Complete the admission file before continuing" : a.status === "ACCEPTED" ? "Next: create the initial bill" : a.status === "ACTIVE_ENROLLMENT" ? "Enrollment is active" : "Next: finish enrollment"}</h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {!requiredRecordsComplete ? "This older admission is missing a required record. Complete the referral and signed-consent steps below; billing and enrollment stay blocked until then." : a.status === "ACCEPTED" ? "Post the initial charges from the fee plan reviewed at acceptance. This creates an invoice; it does not record money received." : a.status === "ACTIVE_ENROLLMENT" ? "The student is enrolled. Record later payments, discounts or refunds in Finance." : "Check payment requirements and seat availability before activating enrollment. Record any money received separately in Finance."}
                  </p>
                  {a.invoice && <p className="mt-3 text-sm">Invoice {a.invoice.number} · billed BDT {a.invoice.total.toFixed(2)} · outstanding BDT {a.invoice.due.toFixed(2)}</p>}
                  {!referralReady && manage && <div className="mt-4"><ReferralForm admissionId={a.id} people={referrals} choice={referral} /></div>}
                  {!hasConsent && manage && <div className="mt-4"><PhysicalConsentForm admissionId={a.id} /></div>}
                  {manage && next && requiredRecordsComplete && <div className="mt-4"><AdmissionCommandForm key={`${a.id}-${a.status}`} {...next} admissionId={a.id} data={data} /></div>}
                  {a.status !== "ACCEPTED" && <Link href="/dashboard/finance/billing" className="mt-3 inline-block text-sm font-medium underline">Open Finance billing and payments</Link>}
                </section>
                <details className="rounded-xl border p-4">
                  <summary className="cursor-pointer font-medium">Application and fee record</summary>
                  <div className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                    <p><span className="text-muted-foreground">Guardian:</span> {a.guardian} · {a.mobile}</p>
                    <p><span className="text-muted-foreground">Fee plan:</span> Version {a.feeVersion}</p>
                    <p><span className="text-muted-foreground">Activation policy:</span> {a.policyVersion ? `Version ${a.policyVersion} · ${a.paymentRequirement?.replaceAll("_", " ")}` : "Pinned at acceptance"}</p>
                    <p><span className="text-muted-foreground">Initial charge total:</span> BDT {total.toFixed(2)}</p>
                  </div>
                  {a.invoice && <div className="mt-3 border-t pt-3 text-sm">
                    <p>{a.invoice.number} · Paid BDT {a.invoice.paid.toFixed(2)} · Outstanding BDT {a.invoice.due.toFixed(2)}</p>
                    {!!a.receipts.length && <ul className="mt-2 space-y-1">{a.receipts.map((receipt) => <li key={receipt.number}>{receipt.number} · BDT {receipt.amount.toFixed(2)} received · {receipt.method}</li>)}</ul>}
                    <Link href="/dashboard/finance/billing" className="mt-2 inline-block underline">Manage billing, discounts, refunds and receipts</Link>
                  </div>}
                </details>
              </div>
            )}

            {a.status === "CANCELLED" && <p className="mt-4 rounded-xl border p-4 text-sm text-muted-foreground">This case is cancelled and retained in the admission history.</p>}
          </article>
        );
      })}
      {!data.cases.length && (
        <p className="rounded-xl border border-dashed p-6 text-sm">
          No admission cases yet. Start with a new applicant or select a verified Prospect above. Confirm that the programme has a published Fee Plan and an available batch.
        </p>
      )}
    </div>
  );
}
