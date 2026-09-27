"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { reviewAdmissionRequirement } from "@/modules/crm/actions";

type Review = { id: string; requirementLabel: string; status: string; note: string; revision: number; reviewedAt: string };

export function AdmissionRequirementReview({ applicationId, prospectId, reviews }: {
  applicationId: string; prospectId: string; reviews: Review[];
}) {
  const [label, setLabel] = useState("");
  const [status, setStatus] = useState<"PENDING" | "VERIFIED" | "FOLLOW_UP">("PENDING");
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const latest = new Map<string, Review>();
  for (const row of reviews) if (!latest.has(row.requirementLabel) || latest.get(row.requirementLabel)!.revision < row.revision)
    latest.set(row.requirementLabel, row);

  return <section className="mt-5 rounded-xl border p-4">
    <h3 className="font-semibold">Requirements checklist</h3>
    <p className="mt-1 text-xs text-muted-foreground">Review each requirement from the submitted terms. Changes retain their earlier revisions. Follow-up notes are for staff; contact the guardian through the recorded CRM follow-up process.</p>
    {latest.size ? <ul className="mt-4 space-y-2 text-sm">{Array.from(latest.values()).map((row) =>
      <li key={row.id} className="rounded-lg border p-3">
        <span className="font-medium">{row.requirementLabel}</span> · {row.status.replaceAll("_", " ")} · revision {row.revision}
        {row.note ? <p className="mt-1 text-muted-foreground">{row.note}</p> : null}
      </li>)}</ul> : <p className="mt-3 text-sm text-muted-foreground">No requirements have been reviewed yet.</p>}
    <form className="mt-4 grid gap-3 sm:grid-cols-2" onSubmit={(event) => {
      event.preventDefault(); setMessage("");
      const requirementLabel = label.trim();
      startTransition(async () => {
        const result = await reviewAdmissionRequirement({ applicationId, prospectId, requirementLabel,
          status, note: note.trim(), expectedRevision: latest.get(requirementLabel)?.revision ?? 0 });
        if (result.ok) { setNote(""); setMessage("Review recorded."); router.refresh(); }
        else setMessage(result.error);
      });
    }}>
      <label className="text-sm">Requirement
        <input required minLength={3} maxLength={160} value={label} onChange={(e) => setLabel(e.target.value)}
          placeholder="e.g. Previous school record" className="mt-1 min-h-11 w-full rounded-lg border bg-background px-3" />
      </label>
      <label className="text-sm">Review state
        <select value={status} onChange={(e) => setStatus(e.target.value as typeof status)} className="mt-1 min-h-11 w-full rounded-lg border bg-background px-3">
          <option value="PENDING">Pending</option><option value="VERIFIED">Verified</option><option value="FOLLOW_UP">Follow-up needed</option>
        </select>
      </label>
      <label className="text-sm sm:col-span-2">Review note
        <textarea value={note} onChange={(e) => setNote(e.target.value)} maxLength={1000} required={status === "FOLLOW_UP"}
          className="mt-1 min-h-20 w-full rounded-lg border bg-background p-3" />
      </label>
      <button disabled={pending} className="min-h-11 rounded-lg bg-blue-700 px-4 text-sm font-semibold text-white disabled:opacity-50">
        {pending ? "Saving…" : "Record review"}
      </button>
      {message ? <p role="status" className="self-center text-sm">{message}</p> : null}
    </form>
    {reviews.length ? <details className="mt-4 text-xs"><summary className="cursor-pointer">Review history</summary>
      <ol className="mt-2 space-y-1">{reviews.map((row) => <li key={row.id}>{row.requirementLabel} · {row.status} · {new Date(row.reviewedAt).toLocaleString()} · revision {row.revision}</li>)}</ol>
    </details> : null}
  </section>;
}
