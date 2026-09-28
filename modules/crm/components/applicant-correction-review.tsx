"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { reviewApplicantCorrection } from "@/modules/crm/actions";

type Correction = {
  id: string;
  requestedChanges: string;
  status: string;
  staffNote: string;
  submittedAt: string;
  reviewedAt: string | null;
};

export function ApplicantCorrectionReview({
  prospectId,
  corrections,
}: {
  prospectId: string;
  corrections: Correction[];
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");

  return (
    <section className="mt-5 rounded-xl border p-4">
      <h3 className="font-semibold">Applicant correction requests</h3>
      <p className="mt-1 text-xs text-muted-foreground">
        Requests are separate from the original application. Apply only after
        verifying the evidence with the applicant.
      </p>
      {corrections.length ? (
        <div className="mt-4 space-y-3">
          {corrections.map((correction) => (
            <article
              key={correction.id}
              className="rounded-lg border p-3 text-sm"
            >
              <div className="flex flex-wrap justify-between gap-2">
                <span className="font-semibold">
                  {correction.status.replaceAll("_", " ")}
                </span>
                <span className="text-xs text-muted-foreground">
                  {new Date(correction.submittedAt).toLocaleString()}
                </span>
              </div>
              <p className="mt-2 whitespace-pre-wrap leading-6">
                {correction.requestedChanges}
              </p>
              {correction.staffNote ? (
                <p className="mt-2 text-xs text-muted-foreground">
                  Staff note: {correction.staffNote}
                </p>
              ) : null}
              {correction.status !== "APPLIED" &&
              correction.status !== "REJECTED" ? (
                <div className="mt-3 grid gap-2 sm:grid-cols-[1fr_auto]">
                  <input
                    value={note}
                    onChange={(event) => setNote(event.target.value)}
                    placeholder="Staff note (optional)"
                    maxLength={1000}
                    className="min-h-10 rounded-lg border bg-background px-3 text-sm"
                  />
                  {(["ACKNOWLEDGED", "APPLIED", "REJECTED"] as const).map(
                    (status) => (
                      <button
                        key={status}
                        type="button"
                        disabled={pending}
                        onClick={() =>
                          startTransition(async () => {
                            setMessage("");
                            const result = await reviewApplicantCorrection({
                              correctionId: correction.id,
                              prospectId,
                              status,
                              staffNote: note.trim(),
                            });
                            if (result.ok) {
                              setNote("");
                              setMessage("Correction review recorded.");
                              router.refresh();
                            } else setMessage(result.error);
                          })
                        }
                        className="min-h-10 rounded-lg border px-3 text-xs font-semibold hover:bg-muted disabled:opacity-50"
                      >
                        {status.replaceAll("_", " ")}
                      </button>
                    ),
                  )}
                </div>
              ) : null}
            </article>
          ))}
        </div>
      ) : (
        <p className="mt-3 text-sm text-muted-foreground">
          No applicant correction requests.
        </p>
      )}
      {message ? (
        <p role="status" className="mt-3 text-sm">
          {message}
        </p>
      ) : null}
    </section>
  );
}
