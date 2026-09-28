"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  createPublicContentVersion,
  publishPublicContentVersion,
  submitPublicContentVersion,
} from "@/modules/offerings/actions";
import type { OfferingOverview } from "@/modules/offerings/queries";
import { SHOWCASE_ICON_VALUES } from "@/modules/offerings/schema";

type Offering = OfferingOverview["offerings"][number];
type Version = OfferingOverview["publicVersions"][number];

export function PublicVersionWorkflow({ offering, versions }: { offering: Offering; versions: Version[] }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [reason, setReason] = useState("");
  const [message, setMessage] = useState("");
  const offeringVersions = versions.filter((version) => version.offering_id === offering.id);

  const content = {
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
  };

  function run(action: () => Promise<{ ok: true; reference: string } | { ok: false; error: string }>) {
    setMessage("");
    startTransition(async () => {
      const result = await action();
      setMessage(result.ok ? "Public content workflow updated." : result.error);
      if (result.ok) router.refresh();
    });
  }

  return (
    <section className="mt-4 rounded-xl border-dashed bg-muted/20 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold">Reviewed public content versions</h3>
          <p className="mt-1 text-xs leading-5 text-muted-foreground">Create a snapshot from the current live copy, submit it for independent review, then publish it to the public contract.</p>
        </div>
        <div className="flex gap-2">
          <input value={reason} onChange={(event) => setReason(event.target.value)} minLength={5} maxLength={500} placeholder="Reason for snapshot" className="min-h-10 rounded-lg border bg-background px-3 text-xs" />
          <button type="button" disabled={pending || reason.trim().length < 5} onClick={() => run(() => createPublicContentVersion({ offeringId: offering.id, reason: reason.trim(), content: { ...content, showcaseSortOrder: offering.showcase_sort_order, showcaseIcon: SHOWCASE_ICON_VALUES.includes(offering.showcase_icon as (typeof SHOWCASE_ICON_VALUES)[number]) ? offering.showcase_icon as (typeof SHOWCASE_ICON_VALUES)[number] : "", isWebsiteVisible: offering.is_website_visible, isAcceptingApplications: offering.is_accepting_applications, applicationsOpenOn: offering.applications_open_on ?? "", applicationsCloseOn: offering.applications_close_on ?? "", subjectIds: [], } }))} className="min-h-10 rounded-lg bg-blue-700 px-3 text-xs font-semibold text-white disabled:opacity-50">Create draft</button>
        </div>
      </div>
      {offeringVersions.length ? <ul className="mt-4 space-y-2 text-xs">{offeringVersions.map((version) => <li key={version.id} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border bg-background p-3"><span><strong>v{version.version}</strong> · {version.status.replaceAll("_", " ")} · {version.change_reason}</span><span className="flex gap-2">{version.status === "DRAFT" ? <button type="button" disabled={pending} onClick={() => run(() => submitPublicContentVersion(version.id))} className="font-semibold underline-offset-4">Submit review</button> : null}{version.status === "PENDING_REVIEW" ? <button type="button" disabled={pending} onClick={() => run(() => publishPublicContentVersion(version.id, offering.id))} className="font-semibold text-emerald-700 underline-offset-4">Publish</button> : null}</span></li>)}</ul> : <p className="mt-3 text-xs text-muted-foreground">No version snapshots yet.</p>}
      {message ? <p role="status" className="mt-3 text-xs">{message}</p> : null}
    </section>
  );
}
