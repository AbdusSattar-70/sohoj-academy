import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import {
  getConsentDocuments,
  getPhysicalConsentReceipts,
} from "@/modules/admissions/consent";
import { getAdmissionReferrals } from "@/modules/admissions/referrals";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
import { PhysicalConsentForm } from "@/modules/admissions/components/physical-consent-form";
import { ReferralForm } from "@/modules/admissions/components/referral-form";

const orderedStatuses = [
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

export default async function AdmissionCasePage({
  params,
}: {
  params: Promise<{ admissionId: string }>;
}) {
  const context = await requirePermission("admissions.view");
  const { admissionId } = await params;

  const [data, consentDocuments, physicalReceipts, referrals] =
    await Promise.all([
      getAdmissionWorkspace(),
      getConsentDocuments(),
      getPhysicalConsentReceipts(),
      getAdmissionReferrals(),
    ]);

  const admission = data.cases.find((row) => row.id === admissionId);
  if (!admission) notFound();

  const batch = data.batches.find((row) => row.id === admission.batchId);
  const offering = data.offerings.find((row) => row.id === batch?.offeringId);
  const referral = referrals.choices.find(
    (row) => row.admission_id === admission.id,
  );
  const signedForms = consentDocuments.filter(
    (row) => row.admission_id === admission.id,
  );
  const paperReceipts = physicalReceipts.filter(
    (row) => row.admission_id === admission.id,
  );

  const hasConsent = signedForms.length > 0 || paperReceipts.length > 0;
  const hasReferral = Boolean(referral);
  const reviewComplete = hasConsent && hasReferral;
  const manage = context.permissions.includes("admissions.create");
  const isCancelled = admission.status === "CANCELLED";

  const currentIndex = orderedStatuses.indexOf(
    admission.status as (typeof orderedStatuses)[number],
  );

  const stepState = [
    {
      title: "Verify identity and placement",
      complete: admission.status !== "DRAFT" && !isCancelled,
      active: admission.status === "DRAFT",
    },
    {
      title: "Record referral",
      complete: hasReferral,
      active: admission.status === "READY" && !hasReferral,
    },
    {
      title: "File paper consent",
      complete: hasConsent,
      active: admission.status === "READY" && hasReferral && !hasConsent,
    },
    {
      title: "Accept admission",
      complete: currentIndex >= 2 && reviewComplete,
      active: admission.status === "READY" && reviewComplete,
    },
    {
      title: "Post initial bill",
      complete: currentIndex >= 3 && reviewComplete,
      active: admission.status === "ACCEPTED",
    },
    {
      title: "Activate enrollment",
      complete: admission.status === "ACTIVE_ENROLLMENT" && reviewComplete,
      active:
        reviewComplete &&
        (admission.status === "BILLING_POSTED" ||
          admission.status === "PENDING_PAYMENT"),
    },
  ];

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
            "Confirm the applicant identity, guardian details, placement and effective fee terms before moving the case to acceptance review.",
        }
      : admission.status === "READY" && reviewComplete
        ? {
            action: "ACCEPT" as const,
            label: "Accept admission",
            description:
              "Record the admission decision and issue or retain the permanent Student ID. Acceptance does not itself post payment.",
          }
        : admission.status === "ACCEPTED"
          ? {
              action: "BILL" as const,
              label: "Post initial bill",
              description:
                "Create the initial invoice from the Fee Plan pinned to this admission. Money received is recorded separately in Finance.",
            }
          : admission.status === "BILLING_POSTED" ||
              admission.status === "PENDING_PAYMENT"
            ? {
                action: "ACTIVATE" as const,
                label: "Evaluate enrollment activation",
                description:
                  "Apply the pinned activation policy and current batch capacity. An unpaid receivable may remain when the policy permits activation.",
              }
            : null;

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Admissions & Students"
        title={admission.number}
        description="Complete this admission from one working page. Each step records a separate business fact and keeps the case context visible."
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
              {admission.existingStudent ? "Existing student admission" : "New admission"}
            </p>
            <h2 className="mt-1 text-2xl font-semibold">{admission.name}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {offering?.name ?? "Programme unavailable"} ·{" "}
              {batch?.name ?? "Batch unavailable"}
              {admission.studentNo ? ` · ${admission.studentNo}` : ""}
            </p>
          </div>
          <StatusBadge value={admission.status} />
        </div>

        <ol
          aria-label="Admission progress"
          className="mt-6 grid gap-2 sm:grid-cols-2 lg:grid-cols-3"
        >
          {stepState.map((step, index) => (
            <li
              key={step.title}
              className={`rounded-xl border p-3 text-sm ${
                step.active
                  ? "border-primary bg-primary/5 font-medium"
                  : step.complete
                    ? "border-emerald-200 bg-emerald-50/60 dark:border-emerald-900"
                    : "text-muted-foreground"
              }`}
            >
              <div className="flex items-center gap-3">
                <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-bold">
                  {step.complete ? "✓" : index + 1}
                </span>
                <span>{step.title}</span>
              </div>
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
            <Row label="Programme" value={offering?.name ?? "—"} />
            <Row label="Class" value={offering?.className ?? "—"} />
            <Row label="Batch" value={batch?.name ?? "—"} />
            <Row
              label="Seats"
              value={
                batch
                  ? `${batch.occupied}/${batch.capacity} occupied`
                  : "—"
              }
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
            Pinned Fee Plan terms. Approved discounts and later financial
            corrections are recorded separately.
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
        <>
          <section className="space-y-4 rounded-2xl border bg-card p-5 sm:p-6">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.16em] text-muted-foreground">
                Working steps
              </p>
              <h2 className="mt-1 text-xl font-semibold">Complete the case</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Do only the next available action. Blockers are shown here
                instead of sending the operator to another register.
              </p>
            </div>

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
              manage && (
                <PhysicalConsentForm admissionId={admission.id} />
              )}

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
                data={data}
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
                  The student is now part of the selected batch. Continue
                  billing, payments, discounts or refunds from Student
                  Accounts.
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

          <details className="rounded-2xl border bg-card p-5">
            <summary className="cursor-pointer font-semibold">
              Application record and history
            </summary>
            <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
              <Row label="Admission reference" value={admission.number} />
              <Row label="Status" value={admission.status.replaceAll("_", " ")} />
              <Row
                label="Activation policy"
                value={
                  admission.policyVersion
                    ? `Version ${admission.policyVersion} · ${admission.paymentRequirement?.replaceAll("_", " ") ?? "configured"}`
                    : "Pinned at acceptance"
                }
              />
              <Row
                label="Referral"
                value={
                  referral
                    ? referral.source === "ORGANIC"
                      ? "Organic"
                      : referrals.people.find(
                            (person) => person.id === referral.referrer_id,
                          )?.full_name ?? "Referred person"
                    : "Not recorded"
                }
              />
              <Row
                label="Consent"
                value={
                  paperReceipts.length
                    ? `Paper receipt v${paperReceipts.at(0)?.version ?? "?"}`
                    : signedForms.length
                      ? `Digital record v${signedForms.at(0)?.version ?? "?"}`
                      : "Not recorded"
                }
              />
              <Row label="Created" value={new Date(admission.createdAt).toLocaleString()} />
            </dl>
          </details>
        </>
      )}

      {isCancelled && (
        <section className="rounded-2xl border border-amber-300 bg-amber-50 p-5 text-sm text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">
          <p className="font-semibold">This admission is cancelled</p>
          <p className="mt-1">
            The case remains available as historical evidence. No active
            enrollment or future billing work should be started from it.
          </p>
        </section>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium">{value}</dd>
    </div>
  );
}
