import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import { PhysicalConsentForm } from "@/modules/admissions/components/physical-consent-form";
import { ReferralForm } from "@/modules/admissions/components/referral-form";
import { getConsentDocuments, getPhysicalConsentReceipts } from "@/modules/admissions/consent";
import { getAdmissionReferrals } from "@/modules/admissions/referrals";
import { StaffAdmissionIntakeForm } from "@/modules/admissions/components/staff-intake-form";

const nextAction: Record<
  string,
  { action: "READY" | "ACCEPT" | "BILL" | "ACTIVATE"; label: string; description: string } | null
> = {
  DRAFT: {
    action: "READY",
    label: "Mark Ready for Acceptance",
    description:
      "Confirm the application is complete and verified. Referral source and signed paper consent are recorded next.",
  },
  READY: {
    action: "ACCEPT",
    label: "Accept Admission",
    description:
      "Creates the permanent Student identity and pins the current activation policy. No payment or enrollment is created yet.",
  },
  ACCEPTED: {
    action: "BILL",
    label: "Post Initial Bill",
    description:
      "Creates the first invoice from the fee plan reviewed at acceptance. Money is recorded separately when received.",
  },
  BILLING_POSTED: {
    action: "ACTIVATE",
    label: "Evaluate Enrollment Activation",
    description:
      "Checks activation policy and batch capacity. An unpaid receivable can remain when the policy permits activation.",
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
  searchParams: Promise<{ prospect?: string; start?: string }>;
}) {
  const context = await requirePermission("admissions.view");
  const { prospect: prospectParam, start: startParam } = await searchParams;
  const [data, consentDocuments, physicalReceipts, referrals] = await Promise.all([getAdmissionWorkspace(), getConsentDocuments(), getPhysicalConsentReceipts(), getAdmissionReferrals()]);
  const manage = context.permissions.includes("admissions.create");
  const defaultProspectId =
    prospectParam && data.prospects.some((p) => p.id === prospectParam)
      ? prospectParam
      : undefined;
  const preselected = defaultProspectId
    ? data.prospects.find((p) => p.id === defaultProspectId)
    : undefined;
  const startMode =
    startParam === "staff" || startParam === "enquiry"
      ? startParam
      : defaultProspectId
        ? "enquiry"
        : null;
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Student Lifecycle"
        title="Admissions"
        description="Verify the application, record referral and paper consent, then accept. Billing and enrollment follow as separate steps."
      />
      <div className="flex flex-wrap gap-4 text-sm print:hidden">
        <Link href="/dashboard/crm/prospects" className="underline">Enquiries</Link>
        <Link href="/dashboard/academics/batches" className="underline">Batch setup</Link>
        <Link href="/dashboard/students" className="underline">Student register</Link>
      </div>
      {manage && (
        <section id="start-admission" className="space-y-4 rounded-2xl border bg-muted/10 p-5 sm:p-6">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-700 dark:text-blue-300">Choose how to begin</p>
            <h2 className="mt-1 text-xl font-semibold">Start an admission</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Pick a path below. The matching form opens on this page. Online
              entry creates an unconfirmed draft. A blank paper form must be
              entered by staff before a case exists.
            </p>
          </div>
          <div className="grid gap-3 md:grid-cols-3">
            <Link
              href="/dashboard/admissions?start=staff"
              className={`rounded-xl border bg-card p-4 transition hover:border-primary/60 ${
                startMode === "staff" ? "border-primary ring-2 ring-primary/20" : ""
              }`}
            >
              <p className="text-sm font-semibold">New applicant with staff assistance</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">
                Enter the student and guardian details while they are with you.
                Creates the admission application and draft case directly; does
                not create a CRM Enquiry.
              </p>
              <span className="mt-3 inline-block text-sm font-medium text-primary underline">
                {startMode === "staff" ? "Form open below" : "Open staff intake form"}
              </span>
            </Link>
            <Link
              href={
                defaultProspectId
                  ? `/dashboard/admissions?start=enquiry&prospect=${defaultProspectId}`
                  : "/dashboard/admissions?start=enquiry"
              }
              className={`rounded-xl border bg-card p-4 transition hover:border-primary/60 ${
                startMode === "enquiry" ? "border-primary ring-2 ring-primary/20" : ""
              }`}
            >
              <p className="text-sm font-semibold">Already in Enquiries</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">
                Continue a verified enquiry. Choose the intended offering and an
                available batch. Identity is inherited from the CRM record.
              </p>
              <span className="mt-3 inline-block text-sm font-medium text-primary underline">
                {startMode === "enquiry" ? "Form open below" : "Open enquiry conversion form"}
              </span>
            </Link>
            <Link
              href="/dashboard/admissions/application-form"
              className="rounded-xl border bg-card p-4 transition hover:border-primary/60"
            >
              <p className="text-sm font-semibold">Paper application</p>
              <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">
                Print a blank A4 form for the student and guardian to complete
                and sign in person.
              </p>
              <span className="mt-3 inline-block text-sm font-medium text-primary underline">
                Print blank application
              </span>
            </Link>
          </div>

          {startMode === "staff" && (
            <div
              id="new-applicant"
              className="scroll-mt-24 space-y-3 rounded-xl border border-primary/30 bg-card p-4 sm:p-5"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.16em] text-muted-foreground">
                    Staff intake
                  </p>
                  <h3 className="mt-1 text-lg font-semibold">Enter a new applicant online</h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Complete the form below. On success you are taken to the
                    admission case workbench.
                  </p>
                </div>
                <Link
                  href="/dashboard/admissions"
                  className="rounded-lg border px-3 py-1.5 text-sm font-medium"
                >
                  Close form
                </Link>
              </div>
              <StaffAdmissionIntakeForm data={data} />
            </div>
          )}

          {startMode === "enquiry" && (
            <div
              id="from-prospect"
              className="scroll-mt-24 space-y-3 rounded-xl border border-primary/30 bg-card p-4 sm:p-5"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.16em] text-muted-foreground">
                    Enquiry conversion
                  </p>
                  <h3 className="mt-1 text-lg font-semibold">
                    Create a draft from an existing Enquiry
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Select the Prospect, programme offering and batch. The case
                    opens after the draft is created.
                  </p>
                </div>
                <Link
                  href="/dashboard/admissions"
                  className="rounded-lg border px-3 py-1.5 text-sm font-medium"
                >
                  Close form
                </Link>
              </div>
              {preselected && (
                <p className="rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-950 dark:border-blue-900 dark:bg-blue-950/30 dark:text-blue-100">
                  Starting from <strong>{preselected.number} · {preselected.name}</strong>.
                  Confirm the correct offering and batch before creating the draft.
                </p>
              )}
              {!data.prospects.length && (
                <p className="rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">
                  No open enquiries are available. Use staff intake for a new
                  applicant, or continue work in CRM first.
                </p>
              )}
              <AdmissionCommandForm
                action="CREATE"
                data={data}
                defaultProspectId={defaultProspectId}
                label="Create admission draft"
                description="Student and guardian identity are inherited from the Prospect. The selected offering and batch are revalidated before the draft is created."
              />
            </div>
          )}

          {!startMode && (
            <p className="text-sm text-muted-foreground">
              Select a card above to open the matching form on this page.
            </p>
          )}
        </section>
      )}
      <section id="case-register" className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div><h2 className="text-xl font-semibold">Admission cases</h2><p className="mt-1 text-sm text-muted-foreground">Each case shows the next decision and the checks needed to complete it. Financial operations continue in Finance after acceptance.</p></div>
          <p className="text-sm text-muted-foreground">{data.cases.length} {data.cases.length === 1 ? "case" : "cases"}</p>
        </div>
        {data.cases.length === 0 && <p className="rounded-xl border border-dashed p-6 text-sm text-muted-foreground">No admission cases yet. Start from a new applicant or continue an existing Enquiry above.</p>}
      </section>
      {data.cases.map((a) => {
        const next = nextAction[a.status] ?? null;
        const consentDocumentsForCase = consentDocuments.filter((item) => item.admission_id === a.id);
        const signedForms = consentDocumentsForCase;
        const paperReceipts = physicalReceipts.filter((item) => item.admission_id === a.id);
        const hasConsent = signedForms.length > 0 || paperReceipts.length > 0;
        const referral = referrals.choices.find((item) => item.admission_id === a.id);
        const referralReady = Boolean(referral);
        const isVerified = a.status !== "DRAFT";
        const canAccept = isVerified && hasConsent && referralReady && a.status === "READY";
        const batch = data.batches.find((item) => item.id === a.batchId);
        const preAcceptance = ["DRAFT", "READY"].includes(a.status);
        const requiredRecordsComplete = referralReady && hasConsent;
        return (
          <article key={a.id} className="rounded-2xl border bg-card p-5 sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="text-lg font-semibold">{a.number}</h3>
                  <StatusBadge value={a.status} />
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{a.name} · {a.offeringName} · {a.batchName}</p>
                {a.studentId && (
                  <p className="mt-1 text-sm">
                    Student{" "}
                    <Link className="underline" href={`/dashboard/students/${a.studentId}`}>{a.studentNo}{a.existingStudent ? " · Existing student" : ""}</Link>
                  </p>
                )}
              </div>
              <Link href={`/dashboard/admissions/${a.id}`} className="rounded-lg border px-3 py-2 text-sm font-medium">
                Open case workbench
              </Link>
            </div>
            {preAcceptance && manage && (
              <div className="mt-5 space-y-4">
                <section className="rounded-xl border bg-muted/20 p-4">
                  <h3 className="font-semibold">
                    {a.status === "DRAFT"
                      ? "Verify application"
                      : !referralReady
                        ? "Record referral"
                        : !hasConsent
                          ? "File paper consent"
                          : "Ready for acceptance"}
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {a.status === "DRAFT"
                      ? "Confirm identity, placement and fee terms. Mark ready only when verification is complete."
                      : !referralReady
                        ? "Choose the verified referrer or Organic before acceptance."
                        : !hasConsent
                          ? "Record that the signed paper consent is on file."
                          : "Review once more, then accept to issue the permanent Student ID."}
                  </p>
                  {a.status === "DRAFT" && (
                    <div className="mt-3">
                      <AdmissionCommandForm action="EDIT_DRAFT" admissionId={a.id} data={data} identity={a} label="Save corrected details" description="Use the guardian-confirmed information from the application." />
                    </div>
                  )}
                  {a.status === "DRAFT" && next && (
                    <AdmissionCommandForm
                      key={`${a.id}-READY`}
                      action="READY"
                      admissionId={a.id}
                      data={data}
                      label={next.label}
                      description={next.description}
                    />
                  )}
                  {a.status === "READY" && !referralReady && (
                    <div className="mt-4"><ReferralForm admissionId={a.id} people={referrals} choice={referral} /></div>
                  )}
                  {a.status === "READY" && referralReady && !hasConsent && (
                    <div className="mt-4"><PhysicalConsentForm admissionId={a.id} /></div>
                  )}
                  {manage && canAccept && next && <div className="mt-4"><AdmissionCommandForm key={`${a.id}-ACCEPT`} {...next} admissionId={a.id} data={data} /></div>}
                </section>
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
                    {batch && <p><span className="text-muted-foreground">Seats:</span> {batch.occupied}/{batch.capacity}</p>}
                    <Link href="/dashboard/finance/billing" className="mt-2 inline-block underline">Manage billing, discounts, refunds and receipts</Link>
                  </div>
                </details>
              </div>
            )}
          </article>
        );
      })}
    </div>
  );
}
