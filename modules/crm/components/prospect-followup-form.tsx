"use client";

import { useMemo, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { PhoneCall } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ErpFormField, ErpFormStatus } from "@/components/erp/form-field";
import { WorkflowGuide } from "@/components/erp/workflow-guide";
import { recordProspectFollowup } from "@/modules/crm/actions";
import {
  allowedProspectStatuses,
  type ProspectStatus,
} from "@/modules/crm/prospect-status";

const inputClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none transition focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-[invalid=true]:border-destructive";

export function ProspectFollowupForm({
  prospectId,
  currentStatus,
}: {
  prospectId: string;
  currentStatus: ProspectStatus;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [newStatus, setNewStatus] = useState<ProspectStatus>(currentStatus);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [fieldError, setFieldError] = useState<{ field?: string; text: string } | null>(null);

  const statuses = useMemo(
    () => allowedProspectStatuses(currentStatus),
    [currentStatus]
  );

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);
    setFieldError(null);

    startTransition(async () => {
      const result = await recordProspectFollowup({
        prospectId,
        followupType: String(data.get("followupType") ?? "") as
          | "CALL"
          | "WHATSAPP"
          | "IN_PERSON"
          | "COUNSELLING"
          | "TRIAL"
          | "OTHER",
        notes: String(data.get("notes") ?? ""),
        outcome: String(data.get("outcome") ?? ""),
        newStatus,
        nextFollowUpAt: String(data.get("nextFollowUpAt") ?? ""),
        lostReason: String(data.get("lostReason") ?? ""),
      });

      if (result.ok) {
        form.reset();
        setMessage({
          ok: true,
          text: `Follow-up recorded. Prospect status is now ${result.status.replaceAll("_", " ")}.`,
        });
        router.refresh();
      } else {
        setMessage({ ok: false, text: result.error });
        setFieldError({ field: result.field, text: result.error });
      }
    });
  }

  return (
    <section className="rounded-2xl border bg-card p-5 sm:p-6">
      <div className="mb-5">
        <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-700 dark:text-blue-300">
          CRM workflow
        </p>
        <h2 className="mt-1 text-lg font-semibold">Record Follow-up</h2>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Record what happened, update the controlled Prospect status if needed,
          and schedule the next action in one auditable transaction.
        </p>
      </div>

      <WorkflowGuide
        steps={[
          "Choose how the follow-up happened and record a useful factual note.",
          "Select the resulting Prospect status. Only valid lifecycle transitions are offered.",
          "Schedule the next follow-up when future action is required.",
          "The timeline and Prospect record update together under one correlation ID.",
        ]}
      />

      <form onSubmit={submit} className="mt-6 grid gap-5 md:grid-cols-2">
        <ErpFormField
          id="followup-type"
          label="Follow-up Type"
          required
          error={fieldError?.field === "followupType" ? fieldError.text : null}
        >
          {({ id, describedBy, invalid }) => (
            <select
              id={id}
              name="followupType"
              required
              defaultValue="CALL"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            >
              <option value="CALL">Phone Call</option>
              <option value="WHATSAPP">WhatsApp / Messaging</option>
              <option value="IN_PERSON">In Person</option>
              <option value="COUNSELLING">Counselling</option>
              <option value="TRIAL">Trial Class</option>
              <option value="OTHER">Other</option>
            </select>
          )}
        </ErpFormField>

        <ErpFormField
          id="followup-status"
          label="Resulting Status"
          required
          hint="Conversion to Student is not performed here; it belongs to the Admission workflow."
          error={fieldError?.field === "newStatus" ? fieldError.text : null}
        >
          {({ id, describedBy, invalid }) => (
            <select
              id={id}
              name="newStatus"
              required
              value={newStatus}
              onChange={(event) =>
                setNewStatus(event.target.value as ProspectStatus)
              }
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            >
              {statuses.map((status) => (
                <option key={status} value={status}>
                  {status.replaceAll("_", " ")}
                </option>
              ))}
            </select>
          )}
        </ErpFormField>

        <ErpFormField
          id="followup-notes"
          label="Follow-up Notes"
          required
          hint="Record the meaningful facts discussed or observed. Avoid vague notes such as ‘talked’."
          error={fieldError?.field === "notes" ? fieldError.text : null}
          className="md:col-span-2"
        >
          {({ id, describedBy, invalid }) => (
            <textarea
              id={id}
              name="notes"
              rows={4}
              required
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={`${inputClass} py-2.5`}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="followup-outcome"
          label="Outcome"
          hint="Optional concise outcome, for example: guardian wants a trial class before admission."
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="outcome"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="followup-next"
          label="Next Follow-up"
          required={newStatus === "FUTURE_FOLLOW_UP"}
          hint="Use this whenever another contact is expected. Action Center will surface it when due."
          error={fieldError?.field === "nextFollowUpAt" ? fieldError.text : null}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="nextFollowUpAt"
              type="datetime-local"
              required={newStatus === "FUTURE_FOLLOW_UP"}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        {newStatus === "LOST" && (
          <ErpFormField
            id="followup-lost-reason"
            label="Lost Reason"
            required
            hint="Use a factual reason that management can analyze later."
            error={fieldError?.field === "lostReason" ? fieldError.text : null}
            className="md:col-span-2"
          >
            {({ id, describedBy, invalid }) => (
              <textarea
                id={id}
                name="lostReason"
                rows={3}
                required
                aria-describedby={describedBy}
                aria-invalid={invalid}
                className={`${inputClass} py-2.5`}
              />
            )}
          </ErpFormField>
        )}

        <div className="md:col-span-2">
          <ErpFormStatus message={message} />
        </div>

        <div className="md:col-span-2 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            <PhoneCall className="mr-2 size-4" aria-hidden="true" />
            {pending ? "Saving Follow-up…" : "Record Follow-up"}
          </Button>
        </div>
      </form>
    </section>
  );
}
