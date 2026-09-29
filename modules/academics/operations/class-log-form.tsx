"use client";

import { useState, useTransition } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import {
  classLogDraftCommandSchema,
  classLogReviewCommandSchema,
  type ClassLogDraftCommand,
  type ClassLogWorkspace,
} from "./schema";
import { runClassLogCommand } from "./actions";

const cls =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm";

export function ClassLogForm({
  sessionId,
  workspace,
  canReview = false,
  actorId = "",
}: {
  sessionId: string;
  workspace: ClassLogWorkspace;
  canReview?: boolean;
  actorId?: string;
}) {
  const last = workspace.logs[0];
  const awaitingReview = last?.status === "SUBMITTED";
  const hasSavedDraft = last?.status === "DRAFT";
  const canEdit =
    !awaitingReview &&
    (!last?.authored_by || last.authored_by === actorId || !actorId);

  const initialProgress = workspace.units.map((_, unit_index) => {
    const saved = last?.unit_progress.find((x) => x.unit_index === unit_index);
    return {
      unit_index,
      status: saved?.status ?? ("COVERED" as const),
      note: saved?.note ?? "",
    };
  });

  const form = useForm<ClassLogDraftCommand>({
    resolver: zodResolver(classLogDraftCommandSchema),
    mode: "onChange",
    defaultValues: {
      action: "SAVE_DRAFT",
      request_id: crypto.randomUUID(),
      session_id: sessionId,
      reason: hasSavedDraft ? last.reason : "",
      class_summary: last?.class_summary ?? "",
      unfinished_reason: last?.unfinished_reason ?? "",
      homework: last?.homework ?? "",
      next_session_plan: last?.next_session_plan ?? "",
      unit_progress: initialProgress,
    },
  });

  const fields = useFieldArray({
    control: form.control,
    name: "unit_progress",
  });

  const [pending, start] = useTransition();
  const [reviewPending, startReview] = useTransition();
  const [message, setMessage] = useState("");
  const [reviewNote, setReviewNote] = useState("");
  const [reviewDecision, setReviewDecision] =
    useState<"APPROVED" | "REJECTED">("APPROVED");

  const submit = (action: "SAVE_DRAFT" | "SUBMIT") =>
    form.handleSubmit((values) =>
      start(async () => {
        const result = await runClassLogCommand({
          ...values,
          action,
          request_id: crypto.randomUUID(),
        });

        setMessage(result.message);
        if (result.ok) window.location.reload();
      }),
    )();

  const decide = () => {
    if (!last?.id) return;

    const checked = classLogReviewCommandSchema.safeParse({
      action: "DECIDE",
      request_id: crypto.randomUUID(),
      session_id: sessionId,
      class_log_id: last.id,
      decision: reviewDecision,
      review_note: reviewNote,
      reason: reviewNote,
    });

    if (!checked.success) {
      setMessage(checked.error.issues[0]?.message ?? "Enter a review note.");
      return;
    }

    startReview(async () => {
      const result = await runClassLogCommand(checked.data);
      setMessage(result.message);
      if (result.ok) window.location.reload();
    });
  };

  if (awaitingReview) {
    return (
      <section className="space-y-4 rounded-2xl border bg-card p-5">
        <div>
          <h2 className="font-semibold">Actual class log</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Revision {last.revision} is waiting for admin review. Its teaching
            evidence is locked until the reviewer approves or rejects it.
          </p>
        </div>

        <div className="rounded-xl bg-muted/40 p-4 text-sm leading-6">
          <p className="font-medium">{last.class_summary}</p>
          {last.unfinished_reason && (
            <p className="mt-2">
              <strong>Unfinished content:</strong> {last.unfinished_reason}
            </p>
          )}
          {last.homework && (
            <p className="mt-2">
              <strong>Homework:</strong> {last.homework}
            </p>
          )}
          {last.next_session_plan && (
            <p className="mt-2">
              <strong>Next class:</strong> {last.next_session_plan}
            </p>
          )}
        </div>

        {canReview && last.authored_by !== actorId ? (
          <section className="space-y-3 rounded-xl border border-primary/20 bg-primary/5 p-4">
            <h3 className="font-semibold">Admin review</h3>
            <div className="grid gap-3 sm:grid-cols-[180px_1fr]">
              <label className="text-sm">
                Decision
                <select
                  className={`${cls} mt-1`}
                  value={reviewDecision}
                  onChange={(event) =>
                    setReviewDecision(
                      event.target.value as "APPROVED" | "REJECTED",
                    )
                  }
                >
                  <option value="APPROVED">Approve</option>
                  <option value="REJECTED">Reject for correction</option>
                </select>
              </label>
              <label className="text-sm">
                Review note
                <textarea
                  className={`${cls} mt-1 min-h-20 py-2`}
                  value={reviewNote}
                  onChange={(event) => setReviewNote(event.target.value)}
                  placeholder="Explain the decision and any correction needed."
                />
              </label>
            </div>
            <Button
              type="button"
              disabled={reviewPending || reviewNote.trim().length < 5}
              onClick={decide}
            >
              {reviewPending ? "Recording review…" : "Record admin review"}
            </Button>
          </section>
        ) : (
          <p className="rounded-xl border border-dashed p-4 text-sm text-muted-foreground">
            {last.authored_by === actorId
              ? "The submitting teacher cannot review their own class log."
              : "Admin review permission is required."}
          </p>
        )}

        {message && (
          <p role="status" className="text-sm">
            {message}
          </p>
        )}
      </section>
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        void submit("SAVE_DRAFT");
      }}
      className="space-y-5 rounded-2xl border bg-card p-5"
    >
      <div>
        <h2 className="font-semibold">Actual class log</h2>
        <p className="text-sm text-muted-foreground">
          {last?.status === "APPROVED"
            ? `Start correction revision ${last.revision + 1}. The approved record remains unchanged.`
            : last?.status === "REJECTED"
              ? `Correct the rejected revision ${last.revision} and submit a new revision for admin review.`
              : "Record what was taught. Planned targets remain separate; partial coverage does not silently complete the curriculum."}
        </p>
      </div>

      {!canEdit && (
        <p className="rounded-xl border border-dashed p-4 text-sm text-muted-foreground">
          This draft belongs to another staff member.
        </p>
      )}

      <fieldset disabled={pending || !canEdit} className="space-y-5">
        {workspace.units.length > 0 && (
          <div className="space-y-3">
            <h3 className="text-sm font-semibold">Pinned curriculum coverage</h3>
            {fields.fields.map((field, index) => (
              <div
                key={field.id}
                className="grid gap-2 rounded-xl border p-3 sm:grid-cols-[1fr_180px]"
              >
                <div className="text-sm">
                  <strong>{workspace.units[index]?.title}</strong>
                  <span className="block text-xs text-muted-foreground">
                    Target {workspace.units[index]?.target_date}
                  </span>
                </div>
                <div className="space-y-2">
                  <select
                    className={cls}
                    {...form.register(`unit_progress.${index}.status`)}
                  >
                    <option value="COVERED">Covered</option>
                    <option value="PARTIAL">Partially covered</option>
                    <option value="NOT_COVERED">Not covered</option>
                  </select>
                  <input
                    className={cls}
                    placeholder="Short note (optional)"
                    {...form.register(`unit_progress.${index}.note`)}
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        {workspace.units.length === 0 && (
          <p className="text-sm text-muted-foreground">
            No curriculum version was pinned to this session. Record the class
            summary below; planned curriculum remains unmodified.
          </p>
        )}

        <label className="block text-sm font-medium">
          What was taught?
          <textarea
            className={`${cls} mt-1 min-h-24 py-2`}
            {...form.register("class_summary")}
          />
          {form.formState.errors.class_summary && (
            <span className="text-xs text-destructive">
              {form.formState.errors.class_summary.message}
            </span>
          )}
        </label>

        <label className="block text-sm font-medium">
          Why was planned content left incomplete?
          <span className="font-normal text-muted-foreground">
            {" "}
            Required when a curriculum unit is partial or not covered.
          </span>
          <textarea
            className={`${cls} mt-1 min-h-20 py-2`}
            {...form.register("unfinished_reason")}
          />
          {form.formState.errors.unfinished_reason && (
            <span className="text-xs text-destructive">
              {form.formState.errors.unfinished_reason.message}
            </span>
          )}
        </label>

        <label className="block text-sm font-medium">
          Homework / practice
          <textarea
            className={`${cls} mt-1 min-h-20 py-2`}
            {...form.register("homework")}
          />
        </label>

        <label className="block text-sm font-medium">
          Plan for next class
          <textarea
            className={`${cls} mt-1 min-h-20 py-2`}
            {...form.register("next_session_plan")}
          />
        </label>

        <label className="block text-sm font-medium">
          Reason for this record
          <input className={`${cls} mt-1`} {...form.register("reason")} />
          {form.formState.errors.reason && (
            <span className="text-xs text-destructive">
              {form.formState.errors.reason.message}
            </span>
          )}
        </label>
      </fieldset>

      <div className="flex flex-wrap gap-2">
        <Button
          type="submit"
          disabled={
            pending ||
            !canEdit ||
            !form.formState.isValid ||
            !form.formState.isDirty
          }
        >
          {pending ? "Saving…" : "Save draft"}
        </Button>

        <Button
          type="button"
          variant="outline"
          disabled={
            !hasSavedDraft ||
            !canEdit ||
            !form.formState.isValid ||
            form.formState.isDirty ||
            pending
          }
          onClick={() => void submit("SUBMIT")}
        >
          {pending ? "Submitting…" : "Submit saved class log"}
        </Button>
      </div>

      {form.formState.isDirty && hasSavedDraft && (
        <p className="text-xs text-muted-foreground">
          Save changes before submitting. Submission sends the saved draft.
        </p>
      )}

      {message && (
        <p role="status" className="text-sm">
          {message}
        </p>
      )}
    </form>
  );
}
