"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm, type FieldPath, type Resolver } from "react-hook-form";
import { Button } from "@/components/ui/button";
import { ErpFormField, ErpFormStatus } from "@/components/erp/form-field";
import { updateProgrammeOfferingPublicControls } from "@/modules/offerings/actions";
import {
  SHOWCASE_ICON_VALUES,
  updateOfferingPublicControlsSchema,
  type UpdateOfferingPublicControlsInput,
} from "@/modules/offerings/schema";
import type { OfferingOverview } from "@/modules/offerings/queries";

const controlClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm focus-visible:ring-2 focus-visible:ring-ring/30 aria-[invalid=true]:border-destructive";

type OfferingRow = OfferingOverview["offerings"][number];

const ICON_LABELS: Record<(typeof SHOWCASE_ICON_VALUES)[number], string> = {
  "clipboard-check": "Clipboard (assessment)",
  "graduation-cap": "Graduation cap",
  "users-round": "Small batch / people",
  "book-open-check": "Book with check",
  "line-chart": "Progress chart",
  "shield-check": "Trust / verified",
};

export function PublicControlsForm({
  offering,
  subjects,
  linkedSubjectIds,
  onSuccess,
}: {
  offering: OfferingRow;
  subjects: OfferingOverview["subjects"];
  linkedSubjectIds: string[];
  onSuccess?: () => void;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null,
  );
  const isActive = offering.status === "ACTIVE";

  const {
    register,
    handleSubmit,
    setError,
    watch,
    formState: { errors, isDirty, isValid },
  } = useForm<UpdateOfferingPublicControlsInput>({
    resolver: zodResolver(
      updateOfferingPublicControlsSchema,
    ) as Resolver<UpdateOfferingPublicControlsInput>,
    mode: "onChange",
    defaultValues: {
      offeringId: offering.id,
      showcaseTitle: offering.showcase_title ?? "",
      showcaseTitleBn: offering.showcase_title_bn ?? "",
      showcaseDescription: offering.showcase_description ?? "",
      showcaseDescriptionBn: offering.showcase_description_bn ?? "",
      showcaseEyebrow: offering.showcase_eyebrow ?? "",
      showcaseEyebrowBn: offering.showcase_eyebrow_bn ?? "",
      publicSchedule: offering.public_schedule ?? "",
      publicScheduleBn: offering.public_schedule_bn ?? "",
      publicRequirements: offering.public_requirements ?? "",
      publicRequirementsBn: offering.public_requirements_bn ?? "",
      admissionPolicy: offering.admission_policy ?? "",
      admissionPolicyBn: offering.admission_policy_bn ?? "",
      showcaseIcon:
        (offering.showcase_icon as UpdateOfferingPublicControlsInput["showcaseIcon"]) ??
        "",
      showcaseSortOrder: offering.showcase_sort_order ?? 100,
      isWebsiteVisible: offering.is_website_visible ?? false,
      isAcceptingApplications: offering.is_accepting_applications ?? false,
      applicationsOpenOn: offering.applications_open_on ?? "",
      applicationsCloseOn: offering.applications_close_on ?? "",
      subjectIds: linkedSubjectIds,
      reason: "",
    },
  });

  const isVisible = watch("isWebsiteVisible");
  const canSubmit = isDirty && isValid && !pending;

  const submit = handleSubmit((input) => {
    setMessage(null);
    startTransition(async () => {
      const result = await updateProgrammeOfferingPublicControls(input).catch(
        () => ({
          ok: false as const,
          field: undefined as string | undefined,
          error: "Could not save. Your entries remain; retry when connected.",
        }),
      );
      if (!result.ok) {
        if (result.field) {
          setError(
            result.field as FieldPath<UpdateOfferingPublicControlsInput>,
            {
              message: result.error,
            },
          );
        }
        setMessage({ ok: false, text: result.error });
        return;
      }
      setMessage({
        ok: true,
        text: "Public controls saved. Website visibility and application intake are independent of operational status.",
      });
      onSuccess?.();
      router.refresh();
    });
  });

  return (
    <form
      data-editor
      data-busy={pending ? "true" : "false"}
      onSubmit={submit}
      className="mt-4 space-y-4 rounded-xl border border-dashed border-border bg-muted/20 p-4"
      noValidate
    >
      <fieldset disabled={pending} className="contents">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-sm font-semibold">
              Public controls —{" "}
              <span className="font-mono">{offering.code}</span>
            </p>
            <p className="mt-1 text-xs leading-5 text-muted-foreground">
              Operational status stays {offering.status}. Website visibility and
              accepting applications are separate switches. Homepage card design
              is fixed; only curated copy and icons change.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border bg-background px-3 text-sm font-medium">
              <input
                type="checkbox"
                className="size-4 rounded border-input"
                disabled={!isActive || pending}
                {...register("isWebsiteVisible")}
              />
              Website visible
            </label>
            <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border bg-background px-3 text-sm font-medium">
              <input
                type="checkbox"
                className="size-4 rounded border-input"
                disabled={offering.status === "RETIRED" || pending}
                {...register("isAcceptingApplications")}
              />
              Accepting applications
            </label>
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <ErpFormField
            id={`${offering.id}-eyebrow`}
            label="Eyebrow (English)"
            error={errors.showcaseEyebrow?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseEyebrow")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-eyebrow-bn`}
            label="Eyebrow (Bangla)"
            error={errors.showcaseEyebrowBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseEyebrowBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-title`}
            label="Title (English)"
            required={isVisible}
            error={errors.showcaseTitle?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseTitle")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-title-bn`}
            label="Title (Bangla)"
            error={errors.showcaseTitleBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseTitleBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-desc`}
            label="Description (English)"
            required={isVisible}
            className="sm:col-span-2"
            error={errors.showcaseDescription?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("showcaseDescription")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-desc-bn`}
            label="Description (Bangla)"
            className="sm:col-span-2"
            error={errors.showcaseDescriptionBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("showcaseDescriptionBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-schedule`}
            label="Public schedule (English)"
            className="sm:col-span-2"
            hint="State the intended days and times. Actual placement is confirmed by staff."
            error={errors.publicSchedule?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={2}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-20 py-2`}
                disabled={pending}
                {...register("publicSchedule")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-schedule-bn`}
            label="Public schedule (Bangla)"
            className="sm:col-span-2"
            error={errors.publicScheduleBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={2}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-20 py-2`}
                disabled={pending}
                {...register("publicScheduleBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-requirements`}
            label="Application requirements (English)"
            className="sm:col-span-2"
            hint="Describe eligibility and documents staff will verify. Applicants see this before submitting."
            error={errors.publicRequirements?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("publicRequirements")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-requirements-bn`}
            label="Application requirements (Bangla)"
            className="sm:col-span-2"
            error={errors.publicRequirementsBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("publicRequirementsBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-policy`}
            label="Admission policy (English)"
            className="sm:col-span-2"
            hint="Explain verification, placement and when admission becomes confirmed. Fees remain governed by the published plan."
            error={errors.admissionPolicy?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("admissionPolicy")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-policy-bn`}
            label="Admission policy (Bangla)"
            className="sm:col-span-2"
            error={errors.admissionPolicyBn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                rows={3}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${controlClass} min-h-22 py-2`}
                disabled={pending}
                {...register("admissionPolicyBn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-icon`}
            label="Icon"
            error={errors.showcaseIcon?.message}
          >
            {({ id, describedBy, invalid }) => (
              <select
                id={id}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseIcon")}
              >
                <option value="">Default (graduation cap)</option>
                {SHOWCASE_ICON_VALUES.map((value) => (
                  <option key={value} value={value}>
                    {ICON_LABELS[value]}
                  </option>
                ))}
              </select>
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-sort`}
            label="Sort order"
            hint="Lower numbers appear first."
            error={errors.showcaseSortOrder?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                type="number"
                min={0}
                max={9999}
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("showcaseSortOrder", { valueAsNumber: true })}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-open`}
            label="Applications open on"
            error={errors.applicationsOpenOn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                type="date"
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={controlClass}
                disabled={pending}
                {...register("applicationsOpenOn")}
              />
            )}
          </ErpFormField>
          <ErpFormField
            id={`${offering.id}-close`}
            label="Applications close on"
            error={errors.applicationsCloseOn?.message}
          >
            {({ id, describedBy, invalid }) => (
              <input
                id={id}
                type=…18276 tokens truncated…          ["notes", "Contact notes", person?.notes],
                ].map(([name, label, value]) => (
                  <label key={name} className="text-sm">
                    {label}
                    <input
                      name={name!}
                      defaultValue={value ?? ""}
                      required={name === "name"}
                      type={name === "email" ? "email" : "text"}
                      readOnly={name === "email" && !!person?.profileId}
                      className={input}
                    />
                  </label>
                ))}
                <label className="text-sm">
                  Correction reason
                  <input
                    name="reason"
                    required
                    minLength={5}
                    defaultValue="Verified referral contact details"
                    className={input}
                  />
                </label>
                <div className="flex gap-3 sm:col-span-2">
                  <button
                    disabled={pending}
                    className="rounded-lg bg-primary px-4 py-2 text-primary-foreground"
                  >
                    {pending ? "Saving…" : "Save referrer"}
                  </button>
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => setEditing(null)}
                  >
                    Cancel
                  </button>
                </div>
              </fieldset>
            </form>
          )}
        </section>
      )}
      {data.selected && (
        <>
          <h2 className="text-xl font-semibold">{data.name}</h2>
          <div className="grid gap-3 sm:grid-cols-3">
            {[
              ["Earned after corrections", data.earned],
              ["Actually settled", data.settled],
              [
                outstanding < 0
                  ? "Recovery / future offset"
                  : "Outstanding reward",
                Math.abs(outstanding),
              ],
            ].map(([label, n]) => (
              <div key={String(label)} className="rounded-xl border p-4">
                <p className="text-sm text-muted-foreground">{label}</p>
                <p className="mt-2 text-xl font-semibold">{money(Number(n))}</p>
              </div>
            ))}
          </div>
          {data.manager && outstanding > 0 && (
            <button
              className="rounded-lg border px-4 py-2"
              onClick={() => {
                request.current = "";
                setPay(!pay);
              }}
            >
              Record referrer payment
            </button>
          )}
          {pay && (
            <form
              data-editor
              data-busy={pending ? "true" : "false"}
              className="grid gap-4 rounded-xl border p-4 sm:grid-cols-2"
              onSubmit={(e) => {
                e.preventDefault();
                const f = new FormData(e.currentTarget);
                run({
                  action: "SETTLE",
                  id: data.selected,
                  amount: Number(f.get("amount")),
                  account_id: String(f.get("account_id")),
                  reference: String(f.get("reference")),
                  reason: String(f.get("reason")),
                });
              }}
            >
              <fieldset disabled={pending} className="contents">
                <label>
                  Actual amount paid
                  <input
                    className={input}
                    name="amount"
                    type="number"
                    min="0.01"
                    step="0.01"
                    max={outstanding}
                    required
                  />
                </label>
                <label>
                  Cash / bank
                  <select className={input} name="account_id" required>
                    <option value="">Choose…</option>
                    {data.accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Payment reference
                  <input name="reference" className={input} />
                </label>
                <label>
                  Reason
                  <input
                    name="reason"
                    className={input}
                    required
                    minLength={5}
                    defaultValue="Paid verified referral reward"
                  />
                </label>
                <button disabled={pending}>
                  {pending ? "Recording…" : "Record actual payment"}
                </button>
                <button
                  type="button"
                  disabled={pending}
                  onClick={() => setPay(false)}
                >
                  Cancel
                </button>
              </fieldset>
            </form>
          )}
          <section className="overflow-x-auto rounded-2xl border p-4">
            <h3 className="mb-3 font-semibold">
              {t("Referred students", "রেফার করা শিক্ষার্থী")}
            </h3>
            {!data.students.length && (
              <p className="mb-3 text-sm">
                {t(
                  "No referred admissions recorded yet.",
                  "এখনো রেফার করা ভর্তি রেকর্ড হয়নি।",
                )}
              </p>
            )}
            <table className="w-full min-w-[700px] text-sm">
              <thead>
                <tr className="border-b text-left">
                  <th>Student / programme</th>
                  <th>Status</th>
                  <th>Discounts / scholarships</th>
                  <th>Net tuition collected</th>
                  <th>Acquisition reward</th>
                </tr>
              </thead>
              <tbody>
                {data.students.map((s) => (
                  <tr className="border-b align-top" key={s.id}>
                    <td className="py-4">
                      <p className="font-semibold">
                        {s.name} · {s.studentNo ?? s.number}
                      </p>
                      <p className="text-xs">{s.programme}</p>
                      <details className="mt-2">
                        <summary className="cursor-pointer">
                          Collections ({s.collections.length})
                        </summary>
                        <ul className="mt-2 space-y-2">
                          {s.collections.map((c) => (
                            <li key={c.receipt}>
                              {new Date(c.receivedOn).toLocaleDateString(
                                "en-GB",
                              )}{" "}
                              · {c.receipt} · {money(c.allocated)} · billing{" "}
                              {c.billingPeriod}
                            </li>
                          ))}
                        </ul>
                      </details>
                    </td>
                    <td className="py-4">
                      <StatusBadge value={s.status} />
                    </td>
                    <td className="py-4">
                      {s.discountPercent}% admission discount
                      <br />
                      {money(s.discountAmount)} total reductions
                    </td>
                    <td className="py-4">{money(s.netTuition)}</td>
                    <td className="py-4">
                      {money(s.reward)}
                      <br />
                      <span className="text-xs">
                        {s.rate ?? "—"}% · first qualifying billing month
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
          {data.teacher && (
            <section className="space-y-4 rounded-2xl border p-5">
              <h3 className="font-semibold">
                {t(
                  "Teaching and retention account",
                  "পাঠদান ও রিটেনশনের হিসাব",
                )}
              </h3>
              <div className="grid gap-3 sm:grid-cols-4">
                {[
                  [t("Approved earnings", "অনুমোদিত আয়"), data.teachingEarned],
                  [
                    t(
                      "Settled including advance offsets",
                      "অগ্রিম সমন্বয়সহ পরিশোধ",
                    ),
                    data.teachingSettled,
                  ],
                  [
                    t("Outstanding compensation", "বকেয়া পারিশ্রমিক"),
                    data.teachingEarned - data.teachingSettled,
                  ],
                  [
                    t("Unsettled advances", "অসমন্বিত অগ্রিম"),
                    data.advanceOutstanding,
                  ],
                ].map(([label, n]) => (
                  <div key={String(label)} className="rounded-xl border p-3">
                    <p className="text-sm">{label}</p>
                    <p className="font-semibold">{money(Number(n))}</p>
                  </div>
                ))}
              </div>
              <p className="text-sm text-muted-foreground">
                {t(
                  "Approved runs only. Acquisition rewards appear separately above and are not counted twice. Pending calculations do not constitute payable earnings.",
                  "শুধু অনুমোদিত হিসাব দেখানো হয়। শিক্ষার্থী আনার বোনাস উপরে আলাদা দেখানো হয়েছে, দুবার গণনা হয়নি। অপেক্ষমাণ হিসাব এখনো প্রাপ্য আয় নয়।",
                )}
              </p>
              <details>
                <summary className="cursor-pointer">
                  {t("Earnings details", "আয়ের বিবরণ")} (
                  {data.teachingLines.length})
                </summary>
                {data.teachingLines.map((l) => (
                  <div key={l.id} className="border-b py-3 text-sm">
                    <p>
                      {l.run} · {l.from} — {l.to} ·{" "}
                      {l.type.replaceAll("_", " ")} ·{" "}
                      <strong>{money(l.amount)}</strong>
                    </p>
                    {l.netTuition !== null && (
                      <p>
                        {t("Net tuition basis", "নিট টিউশনের ভিত্তি")}:{" "}
                        {money(l.netTuition)} · {t("Pool", "তহবিল")}:{" "}
                        {l.poolPercent}% ·{" "}
                        {l.workloadUnit === "HOURS"
                          ? t(
                              "Approved teaching hours",
                              "অনুমোদিত পাঠদানের ঘণ্টা",
                            )
                          : t("Approved sessions", "অনুমোদিত ক্লাস")}
                        : {l.approvedSessions}/{l.batchApprovedSessions}
                      </p>
                    )}
                  </div>
                ))}
              </details>
              <details>
                <summary className="cursor-pointer">
                  {t("Payments and advance offsets", "পরিশোধ ও অগ্রিম সমন্বয়")}{" "}
                  ({data.teachingPayments.length})
                </summary>
                {data.teachingPayments.map((p, i) => (
                  <p className="py-3 text-sm" key={i}>
                    {p.date.slice(0, 10)} · {p.run} ·{" "}
                    {t("Cash / bank paid", "নগদ / ব্যাংকে পরিশোধ")}{" "}
                    {money(p.cash)} · {t("Advance offset", "অগ্রিম সমন্বয়")}{" "}
                    {money(p.advanceOffset)} · {p.reference ?? "—"}
                  </p>
                ))}
              </details>
            </section>
          )}
          <details className="rounded-xl border p-4">
            <summary className="cursor-pointer font-semibold">
              Reward calculation history
            </summary>
            {data.entries.map((e) => (
              <p className="mt-3 text-sm" key={e.id}>
                {new Date(e.date).toLocaleString("en-GB")} · {money(e.amount)}{" "}
                {e.amount < 0 ? "correction" : "accrual"} · {e.rate}% of{" "}
                {money(e.collected)} net tuition
              </p>
            ))}
          </details>
          <details className="rounded-xl border p-4">
            <summary className="cursor-pointer font-semibold">
              Settlement history
            </summary>
            {data.settlements.map((s, i) => (
              <p className="mt-3 text-sm" key={i}>
                {new Date(s.date).toLocaleString("en-GB")} · {money(s.amount)} ·{" "}
                {s.reference ?? "Office cash record"}
              </p>
            ))}
          </details>
        </>
      )}
    </div>
  );
}
