import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionCase } from "@/modules/admissions/queries";
import {
  getConsentDocuments,
  getPhysicalConsentReceipts,
} from "@/modules/admissions/consent";
import { getAdmissionReferrals } from "@/modules/admissions/referrals";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import { PhysicalConsentForm } from "@/modules/admissions/components/physical-consent-form";
import { ReferralForm } from "@/modules/admissions/components/referral-form";
import type { AdmissionCommandFormData } from "@/modules/admissions/schema";

const commandData: AdmissionCommandFormData = {
  capacityLimit: null,
  offerings: [],
  batches: [],
  prospects: [],
  paymentMethods: [],
};

const originLabels = {
  DIRECT_STAFF: "Direct staff intake",
  PROSPECT_CONVERSION: "Enquiry conversion",
  PUBLIC_APPLICATION: "Public application",
  EXISTING_STUDENT: "Existing Student",
} as const;

const statusOrder = [
  "DRAFT",
  "READY",
  "ACCEPTED",
  "BILLING_POSTED",
  "PENDING_PAYMENT",
  "ACTIVE_ENROLLMENT",
] as const;

function money(value: number) {
  return new Intl.NumberFormat("en-BD", {
    style: "currency",
    currency: "BDT",
    minimumFractionDigits: 2,
  }).format(value);
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium">{value}</dd>
    </div>
  );
}

export default async function AdmissionCasePage({
  params,
}: {
  params: Promise<{ admissionId: string }>;
}) {
  const context = await requirePermission("admissions.view");
  const { admissionId } = await params;

  const [admission, consentDocuments, physicalReceipts, referrals] =
    await Promise.all([
      getAdmissionCase(admissionId),
      getConsentDocuments(),
      getPhysicalConsentReceipts(),
      getAdmissionReferrals(),
    ]);

  const referral = referrals.choices.find(
    (row) => row.admission_id === admission.id,
  );
  const signedForms = consentDocuments.filter(
    (row) => row.admission_id === admission.id,
  );
  const paperReceipts = physicalReceipts.filter(
    (row) => row.admission_id === admission.id,
  );

  const hasReferral = Boolean(referral);
  const hasConsent = signedForms.length > 0 || paperReceipts.length > 0;
  const reviewComplete = hasReferral && hasConsent;
  const manage = context.permissions.includes("admissions.create");
  const isCancelled = admission.status === "CANCELLED";
  const currentIndex = statusOrder.indexOf(
    admission.status as (typeof statusOrder)[number],
  );

  const initialCharges = admission.components.reduce(
    (sum, component) => sum + component.amount,
    0,
  );

  const nextAction =
    admission.status === "DRAFT"
      ? {
          action: "READY" as const,
          label: "Complete verification",
          description:
            "Confirm identity, guardian details, placement and effective Fee Plan terms before moving the case to acceptance review.",
        }
      : admission.status === "READY" && reviewComplete
        ? {
            action: "ACCEPT" as const,
            label: "Accept admission",
            description:
              "Record the admission decision and issue or retain the permanent Student ID. Acceptance is separate from payment.",
          }
        : admission.status === "ACCEPTED"
          ? {
              action: "BILL" as const,
              label: "Post initial bill",
              description:
                "Create the initial invoice from the Fee Plan pinned to this admission. Actual money received is recorded separately in Student Accounts.",
            }
            : admission.status === "BILLING_POSTED" ||
                admission.status === "PENDING_PAYMENT"
              ? {
                  action: "ACTIVATE" as const,
                  label: "Evaluate enrollment activation",
                  description:
                    "Apply the pinned activation policy and current batch capacity. An unpaid receivable can remain when the policy permits activation.",
                }
              : null;

  const steps = [
    {
      id: "step-verify",
      title: "Verify identity and placement",
      complete: admission.status !== "DRAFT" && !isCancelled,
      active: admission.status === "DRAFT",
    },
    {
      id: "step-referral",
      title: "Record admission source",
      complete: hasReferral,
      active: admission.status === "READY" && !hasReferral,
    },
    {
      id: "step-consent",
      title: "File paper consent",
      complete: hasConsent,
      active: admission.status === "READY" && hasReferral && !hasConsent,
    },
    {
      id: "step-accept",
      title: "Accept admission",
      complete: currentIndex >= 2 && reviewComplete,
      active: admission.status === "READY" && reviewComplete,
    },
    {
      id: "step-bill",
      title: "Post initial bill",
      complete: currentIndex >= 3 && reviewComplete,
      active: admission.status === "ACCEPTED",
    },
    {
      id: "step-activate",
      title: "Activate enrollment",
      complete: admission.status === "ACTIVE_ENROLLMENT" && reviewComplete,
      active:
        reviewComplete &&
        ["BILLING_POSTED", "PENDING_PAYMENT"].includes(admission.status),
    },
  ];
  const activeStep =
    steps.find((step) => step.active) ?? steps.find((step) => !step.complete);

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Admissions & Students"
        title={admission.number}
        description="Complete this admission from one working page. Each action records a separate business fact and keeps the case context visible."
        actions={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/dashboard/admissions"
              className="rounded-lg border px-3 py-2 text-sm font-medium"
            >
              Back to Admissions
            </Link>
            <Link
              href={`/dashboard/admissions/${admission.id}/print`}
              className="rounded-lg border px-3 py-2 text-sm font-medium"
            >
              Print form
            </Link>
          </div>
        }
      />

      <section className="rounded-2xl border bg-card p-5 sm:p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-muted-foreground">
              {originLabels[admission.origin]}
            </p>
            <h2 className="mt-1 text-2xl font-semibold">{admission.name}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {admission.offeringName} · {admission.batchName}
              {admission.studentNo ? ` · ${admission.studentNo}` : ""}
            </p>
          </div>
          <StatusBadge value={admission.status} />
        </div>

        <ol
          aria-label="Admission progress"
          className="mt-6 grid gap-2 sm:grid-cols-2 lg:grid-cols-3"
        >
          {steps.map((step, index) => (
            <li key={step.id}>
              <a
                href="#work-panel"
                className={`flex items-center gap-3 rounded-xl border p-3 text-sm transition hover:border-primary/60 ${
                  step.active
                    ? "border-primary bg-primary/5 font-medium"
                    : step.complete
                      ? "border-emerald-200 bg-emerald-50/60 dark:border-emerald-900"
                      : "text-muted-foreground"
                }`}
              >
                <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-bold">
                  {step.complete ? "✓" : index + 1}
                </span>
                <span className="min-w-0">
                  <span className="block">{step.title}</span>
                  {step.active ? (
                    <span className="mt-0.5 block text-xs font-normal text-primary">
                      Current — open work panel
                    </span>
                  ) : step.complete ? (
                    <span className="mt-0.5 block text-xs font-normal text-emerald-700 dark:text-emerald-300">
                      Done
                    </span>
                  ) : (
                    <span className="mt-0.5 block text-xs font-normal">
                      Waiting
                    </span>
                  )}
                </span>
              </a>
            </li>
          ))}
        </ol>
      </section>

      <section className="grid gap-4 lg:grid-cols-3">
        <article className="rounded-2xl border bg-card p-5">
          <h2 className="font-semibold">Identity & guardian</h2>
          <dl className="mt-4 space-y-3 text-sm">
            <Row label="Student" value={admission.name} />
            <Row label="Guardian" value={admission.guardian} />
            <Row label="Mobile" value={admission.mobile} />
            <Row
              label="Relationship"
              value={admission.guardianRelationship ?? "—"}
            />
            <Row label="School" value={admission.schoolName ?? "—"} />
          </dl>
        </article>

        <article className="rounded-2xl border bg-card p-5">
          <h2 className="font-semibold">Placement</h2>
          <dl className="mt-4 space-y-3 text-sm">
            <Row label="Programme" value={admission.offeringName} />
            <Row label="Class" value={admission.className} />
            <Row label="Batch" value={admission.batchName} />
            <Row
              label="Seats"
              value={`${admission.batchOccupied}/${admission.batchCapacity} occupied`}
            />
            <Row
              label="Fee Plan"
              value={`Version ${admission.feeVersion}`}
            />
          </dl>
        </article>

        <article className="rounded-2xl border bg-card p-5">
          <h2 className="font-semibold">Initial charges</h2>
          <p className="mt-4 text-2xl font-bold">{money(initialCharges)}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            Pinned Fee Plan terms. Discounts and financial corrections remain
            separate records.
          </p>
          {admission.invoice && (
            <div className="mt-4 border-t pt-4 text-sm">
              <p>
                {admission.invoice.number} · billed{" "}
                {money(admission.invoice.total)}
              </p>
              <p className="mt-1 text-muted-foreground">
                Paid {money(admission.invoice.paid)} · outstanding{" "}
                {money(admission.invoice.due)}
              </p>
              <Link
                href="/dashboard/finance/billing"
                className="mt-2 inline-block font-medium underline"
              >
                Open Student Accounts
              </Link>
            </div>
          )}
        </article>
      </section>

      {!isCancelled && (
        <section
          id="work-panel"
          className="scroll-mt-24 space-y-4 rounded-2xl border bg-card p-5 sm:p-6"
        >
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-muted-foreground">
              Work panel
            </p>
            <h2 className="mt-1 text-xl font-semibold">
              {activeStep ? activeStep.title : "Complete the case"}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Finish the current step here. The page stays on this case after
              every save. Open another register only when the action itself
              belongs there, then return here.
            </p>
          </div>

          {admission.status === "DRAFT" && manage && (
            <div className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Confirm student and guardian details before marking verification
                complete. Correct anything captured incorrectly on the public form
                or staff intake.
              </p>
              <AdmissionCommandForm
                action="EDIT_DRAFT"
                admissionId={admission.id}
                data={commandData}
                identity={{
                  name: admission.name,
                  guardian: admission.guardian,
                  mobile: admission.mobile,
                }}
                label="Save verified identity"
                description="Updates stay on this draft. Mark verification complete as the next action when ready."
              />
            </div>
          )}

          {admission.status === "READY" && !hasReferral && manage && (
            <ReferralForm
              admissionId={admission.id}
              people={referrals}
              choice={referral}
            />
          )}

          {admission.status === "READY" &&
            hasReferral &&
            !hasConsent &&
            manage && <PhysicalConsentForm admissionId={admission.id} />}

          {admission.status === "READY" && !reviewComplete && (
            <div className="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">
              <p className="font-semibold">Acceptance is blocked</p>
              <p className="mt-1">
                Complete{" "}
                {[
                  !hasReferral ? "the admission source" : null,
                  !hasConsent ? "the signed paper consent" : null,
                ]
                  .filter(Boolean)
                  .join(" and ")}{" "}
                before acceptance.
              </p>
            </div>
          )}

          {nextAction && manage && (
            <AdmissionCommandForm
              key={`${admission.id}-${nextAction.action}`}
              action={nextAction.action}
              admissionId={admission.id}
              data={commandData}
              label={nextAction.label}
              description={nextAction.description}
            />
          )}

          {admission.status === "READY" && !manage && (
            <p className="rounded-xl border border-dashed p-4 text-sm text-muted-foreground">
              Admission management permission is required to continue this
              case.
            </p>
          )}

          {admission.status === "ACTIVE_ENROLLMENT" && (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm dark:border-emerald-900 dark:bg-emerald-950/30">
              <p className="font-semibold">Enrollment is active</p>
              <p className="mt-1 text-muted-foreground">
                The student is now enrolled in the selected batch. Continue
                payments, discounts or refunds from Student Accounts.
              </p>
              <Link
                href="/dashboard/finance/billing"
                className="mt-3 inline-block font-medium underline"
              >
                Open Student Accounts
              </Link>
            </div>
          )}
        </section>
      )}

      <details className="rounded-2xl border bg-card p-5">
        <summary className="cursor-pointer font-semibold">
          Application record and history
        </summary>
        <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
          <Row label="Admission reference" value={admission.number} />
          <Row label="Origin" value={originLabels[admission.origin]} />
          <Row
            label="Prospect origin"
            value={admission.originProspectId ? "Linked to CRM Enquiry" : "Not applicable"}
          />
          <Row
            label="Activation policy"
            value={
              admission.policyVersion
                ? `Version ${admission.policyVersion} · ${admission.paymentRequirement?.replaceAll("_", " ") ?? "configured"}`
                : "Pinned at acceptance"
            }
          />
          <Row
            label="Consent"
            value={
              paperReceipts.length
                ? `Paper receipt v${paperReceipts[0]?.version ?? "?"}`
                : signedForms.length
                  ? `Digital record v${signedForms[0]?.version ?? "?"}`
                  : "Not recorded"
            }
          />
          <Row label="Created" value={new Date(admission.createdAt).toLocaleString()} />
        </dl>
      </details>

      {isCancelled && (
        <section className="rounded-2xl border border-amber-300 bg-amber-50 p-5 text-sm text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">
          <p className="font-semibold">This admission is cancelled</p>
          <p className="mt-1">
            The case remains available as historical evidence. No new
            enrollment or future billing work should be started from it.
          </p>
        </section>
      )}
    </div>
  );
}
