"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { saveAssessmentResults } from "@/app/actions/transactions";
import { decideApproval, submitForApproval } from "@/modules/platform/approvals/actions";
import { Button } from "@/components/ui/button";
import type { AppRole } from "@/lib/constants";

type Assessment = {
  id: string;
  title: string;
  batch_id: string;
  total_marks: number;
  held_on: string;
};
type Student = {
  id: string;
  student_no: string;
  name: string;
  batch_id: string | null;
};
type Result = {
  assessment_id: string;
  student_id: string;
  marks: number;
  remarks: string | null;
};
type Approval = {
  id: string;
  entity_id: string;
  status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED";
  requested_by: string;
  requested_at: string;
  decision_note: string | null;
};

export function AssessmentResultsManager({
  assessments,
  students,
  results,
  approvals,
  role,
}: {
  assessments: Assessment[];
  students: Student[];
  results: Result[];
  approvals: Approval[];
  role: AppRole;
}) {
  const router = useRouter();
  const [assessmentId, setAssessmentId] = useState(assessments[0]?.id ?? "");
  const assessment = assessments.find((item) => item.id === assessmentId);
  const roster = useMemo(
    () => students.filter((student) => student.batch_id === assessment?.batch_id),
    [students, assessment]
  );
  const existing = useMemo(
    () =>
      Object.fromEntries(
        results
          .filter((result) => result.assessment_id === assessmentId)
          .map((result) => [result.student_id, result])
      ),
    [results, assessmentId]
  );
  const latestApproval = useMemo(
    () =>
      approvals
        .filter((approval) => approval.entity_id === assessmentId)
        .sort(
          (a, b) =>
            new Date(b.requested_at).getTime() -
            new Date(a.requested_at).getTime()
        )[0],
    [approvals, assessmentId]
  );

  const locked =
    latestApproval?.status === "PENDING" ||
    latestApproval?.status === "APPROVED";

  const [changes, setChanges] = useState<
    Record<string, { marks: string; remarks: string }>
  >({});
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function current(id: string) {
    return (
      changes[id] ?? {
        marks: existing[id]?.marks?.toString() ?? "",
        remarks: existing[id]?.remarks ?? "",
      }
    );
  }

  function update(id: string, key: "marks" | "remarks", value: string) {
    setChanges((items) => ({
      ...items,
      [id]: { ...current(id), [key]: value },
    }));
  }

  const enteredCount = roster.filter(
    (student) => current(student.id).marks !== ""
  ).length;

  function saveDraft() {
    if (!assessment) return;

    const entries = roster
      .map((student) => ({
        student_id: student.id,
        marks: current(student.id).marks,
        remarks: current(student.id).remarks,
      }))
      .filter((entry) => entry.marks !== "")
      .map((entry) => ({
        ...entry,
        marks: Number(entry.marks),
      }));

    if (!entries.length) {
      setMessage("Enter at least one result before saving a draft.");
      return;
    }

    const invalid = entries.some(
      (entry) =>
        !Number.isFinite(entry.marks) ||
        entry.marks < 0 ||
        entry.marks > assessment.total_marks
    );
    if (invalid) {
      setMessage(
        `Marks must be between 0 and ${assessment.total_marks} for every entered student.`
      );
      return;
    }

    const formData = new FormData();
    formData.set("assessment_id", assessment.id);
    formData.set("entries", JSON.stringify(entries));

    startTransition(async () => {
      const result = await saveAssessmentResults(formData);
      if (result.ok) {
        setChanges({});
        setMessage(
          `Draft saved for ${result.count ?? entries.length} student(s). Complete the roster before submitting for approval.`
        );
        router.refresh();
      } else {
        setMessage(result.error ?? "Could not save the result draft.");
      }
    });
  }

  function submitApproval() {
    if (!assessment) return;

    if (Object.keys(changes).length > 0) {
      setMessage("Save your current changes before submitting for approval.");
      return;
    }

    startTransition(async () => {
      const result = await submitForApproval({
        workflowType: "ASSESSMENT_RESULTS_FINALIZATION",
        entityType: "ASSESSMENT",
        entityId: assessment.id,
        requestedAction: "FINALIZE",
        note: "Assessment results submitted for final approval.",
      });

      setMessage(
        result.ok
          ? "Results submitted for approval. They are now locked until a decision is made."
          : result.error
      );
      if (result.ok) router.refresh();
    });
  }

  function decide(decision: "APPROVED" | "REJECTED") {
    if (!latestApproval || latestApproval.status !== "PENDING") return;

    startTransition(async () => {
      const result = await decideApproval({
        approvalRequestId: latestApproval.id,
        decision,
        note:
          decision === "APPROVED"
            ? "Assessment results reviewed and approved."
            : "Assessment results returned for correction.",
      });

      setMessage(
        result.ok
          ? decision === "APPROVED"
            ? "Results approved and finalised."
            : "Results rejected. They can now be corrected and resubmitted."
          : result.error
      );
      if (result.ok) router.refresh();
    });
  }

  function approvalLabel() {
    if (!latestApproval) return "Draft";
    if (latestApproval.status === "PENDING") return "Awaiting approval";
    if (latestApproval.status === "APPROVED") return "Approved / Final";
    if (latestApproval.status === "REJECTED") return "Rejected — correction required";
    return "Draft";
  }

  return (
    <section className="mt-6 rounded-xl border bg-card p-5">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold">Assessment Results</h2>
          <p className="text-sm text-muted-foreground">
            Save marks as a draft, complete the full batch roster, then submit for administrator approval.
          </p>
        </div>
        <div className="rounded-full border px-3 py-1 text-xs font-semibold">
          {approvalLabel()}
        </div>
      </div>

      <label className="mb-5 grid max-w-xl gap-1.5 text-sm">
        <span className="font-medium">Assessment</span>
        <select
          value={assessmentId}
          onChange={(event) => {
            setAssessmentId(event.target.value);
            setChanges({});
            setMessage(null);
          }}
          className="min-h-11 w-full rounded-md border bg-background px-3 text-sm"
        >
          <option value="">Select assessment</option>
          {assessments.map((item) => (
            <option key={item.id} value={item.id}>
              {item.held_on} • {item.title} • {item.total_marks} marks
            </option>
          ))}
        </select>
      </label>

      {assessment && (
        <>
          <div className="mb-3 rounded-xl bg-muted/50 p-3 text-sm text-muted-foreground">
            Results entered for{" "}
            <span className="font-semibold text-foreground">{enteredCount}</span> of{" "}
            <span className="font-semibold text-foreground">{roster.length}</span>{" "}
            students. Approval is blocked until the complete active roster has marks.
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left">
                  <th className="p-3">Student</th>
                  <th className="p-3">Marks / {assessment.total_marks}</th>
                  <th className="p-3">Remarks</th>
                </tr>
              </thead>
              <tbody>
                {roster.map((student) => {
                  const value = current(student.id);
                  return (
                    <tr key={student.id} className="border-b">
                      <td className="p-3">
                        <div className="font-medium">{student.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {student.student_no}
                        </div>
                      </td>
                      <td className="p-3">
                        <input
                          type="number"
                          min="0"
                          max={assessment.total_marks}
                          step="0.01"
                          disabled={locked}
                          value={value.marks}
                          onChange={(event) =>
                            update(student.id, "marks", event.target.value)
                          }
                          aria-label={`Marks for ${student.name}`}
                          className="min-h-10 w-32 rounded-md border bg-background px-3"
                        />
                      </td>
                      <td className="p-3">
                        <input
                          value={value.remarks}
                          disabled={locked}
                          onChange={(event) =>
                            update(student.id, "remarks", event.target.value)
                          }
                          className="min-h-10 w-full rounded-md border bg-background px-3"
                          placeholder="Optional context"
                          aria-label={`Result remarks for ${student.name}`}
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {!roster.length && (
              <p className="py-8 text-center text-muted-foreground">
                No active students are enrolled in this assessment batch.
              </p>
            )}
          </div>
        </>
      )}

      {message && (
        <div
          className="mt-4 rounded-md border p-3 text-sm"
          role="status"
          aria-live="polite"
        >
          {message}
        </div>
      )}

      {latestApproval?.status === "REJECTED" && latestApproval.decision_note && (
        <div className="mt-4 rounded-md border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
          <span className="font-semibold">Review note:</span>{" "}
          {latestApproval.decision_note}
        </div>
      )}

      <div className="mt-5 flex flex-wrap justify-end gap-2">
        <Button
          type="button"
          variant="outline"
          onClick={saveDraft}
          disabled={pending || locked || !assessment || !roster.length}
        >
          {pending ? "Working…" : "Save Draft"}
        </Button>

        {!locked && (
          <Button
            type="button"
            onClick={submitApproval}
            disabled={pending || !assessment || !roster.length}
          >
            Submit for Approval
          </Button>
        )}

        {role === "ADMIN" && latestApproval?.status === "PENDING" && (
          <>
            <Button
              type="button"
              variant="outline"
              onClick={() => decide("REJECTED")}
              disabled={pending}
            >
              Reject for Correction
            </Button>
            <Button
              type="button"
              onClick={() => decide("APPROVED")}
              disabled={pending}
            >
              Approve & Finalise
            </Button>
          </>
        )}
      </div>
    </section>
  );
}
