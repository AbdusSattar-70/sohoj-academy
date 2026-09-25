"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { saveAttendance } from "@/app/actions/transactions";
import { decideApproval, submitForApproval } from "@/modules/platform/approvals/actions";
import { Button } from "@/components/ui/button";
import type { AppRole } from "@/lib/constants";

type Batch = { id: string; name: string };
type Session = {
  id: string;
  batch_id: string;
  session_date: string;
  starts_at: string;
  ends_at: string;
  subject_name: string | null;
};
type Student = {
  id: string;
  student_no: string;
  name: string;
  batch_id: string | null;
};
type AttendanceStatus = "PRESENT" | "ABSENT" | "LATE" | "EXCUSED";
type Existing = {
  session_id: string;
  student_id: string;
  status: AttendanceStatus;
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

export function AttendanceManager({
  batches,
  sessions,
  students,
  existing,
  approvals,
  role,
}: {
  batches: Batch[];
  sessions: Session[];
  students: Student[];
  existing: Existing[];
  approvals: Approval[];
  role: AppRole;
}) {
  const router = useRouter();
  const [batchId, setBatchId] = useState(batches[0]?.id ?? "");
  const batchSessions = useMemo(
    () => sessions.filter((session) => session.batch_id === batchId),
    [sessions, batchId]
  );
  const [sessionId, setSessionId] = useState("");
  const selectedSessionId =
    sessionId && batchSessions.some((session) => session.id === sessionId)
      ? sessionId
      : batchSessions[0]?.id ?? "";

  const roster = useMemo(
    () => students.filter((student) => student.batch_id === batchId),
    [students, batchId]
  );

  const [changes, setChanges] = useState<
    Record<string, { status: AttendanceStatus | ""; remarks: string }>
  >({});
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const existingMap = useMemo(
    () =>
      Object.fromEntries(
        existing
          .filter((entry) => entry.session_id === selectedSessionId)
          .map((entry) => [entry.student_id, entry])
      ),
    [existing, selectedSessionId]
  );

  const latestApproval = useMemo(
    () =>
      approvals
        .filter((approval) => approval.entity_id === selectedSessionId)
        .sort(
          (a, b) =>
            new Date(b.requested_at).getTime() -
            new Date(a.requested_at).getTime()
        )[0],
    [approvals, selectedSessionId]
  );

  const locked =
    latestApproval?.status === "PENDING" ||
    latestApproval?.status === "APPROVED";

  function current(studentId: string) {
    return (
      changes[studentId] ?? {
        status: existingMap[studentId]?.status ?? "",
        remarks: existingMap[studentId]?.remarks ?? "",
      }
    );
  }

  function setStatus(studentId: string, status: AttendanceStatus | "") {
    setChanges((value) => ({
      ...value,
      [studentId]: { ...current(studentId), status },
    }));
  }

  function setRemarks(studentId: string, remarks: string) {
    setChanges((value) => ({
      ...value,
      [studentId]: { ...current(studentId), remarks },
    }));
  }

  function markAllPresent() {
    if (locked) return;
    setChanges(
      Object.fromEntries(
        roster.map((student) => [
          student.id,
          { ...current(student.id), status: "PRESENT" as const },
        ])
      )
    );
    setMessage(null);
  }

  const markedCount = roster.filter(
    (student) => current(student.id).status !== ""
  ).length;

  function saveDraft() {
    if (!selectedSessionId) return;

    const entries = roster
      .map((student) => ({
        student_id: student.id,
        ...current(student.id),
      }))
      .filter((entry) => entry.status !== "");

    if (!entries.length) {
      setMessage("Mark at least one student before saving a draft.");
      return;
    }

    const formData = new FormData();
    formData.set("session_id", selectedSessionId);
    formData.set("entries", JSON.stringify(entries));

    startTransition(async () => {
      const result = await saveAttendance(formData);
      if (result.ok) {
        setChanges({});
        setMessage(
          `Draft saved for ${result.count ?? entries.length} student(s). Review the full roster before submitting for approval.`
        );
        router.refresh();
      } else {
        setMessage(result.error ?? "Could not save the attendance draft.");
      }
    });
  }

  function submitApproval() {
    if (!selectedSessionId) return;

    if (Object.keys(changes).length > 0) {
      setMessage("Save your current changes before submitting for approval.");
      return;
    }

    startTransition(async () => {
      const result = await submitForApproval({
        workflowType: "ATTENDANCE_FINALIZATION",
        entityType: "CLASS_SESSION",
        entityId: selectedSessionId,
        requestedAction: "FINALIZE",
        note: "Attendance roster submitted for final approval.",
      });

      setMessage(
        result.ok
          ? "Attendance submitted for approval. It is now locked until a decision is made."
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
            ? "Attendance reviewed and approved."
            : "Attendance returned for correction.",
      });

      setMessage(
        result.ok
          ? decision === "APPROVED"
            ? "Attendance approved and finalised."
            : "Attendance rejected. The teacher/operator can correct and resubmit it."
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
    <section className="rounded-xl border bg-card p-5">
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold">Daily Attendance</h2>
          <p className="text-sm text-muted-foreground">
            Save the roster as a draft first. Submitted attendance is locked until an administrator approves or rejects it.
          </p>
        </div>
        <div className="rounded-full border px-3 py-1 text-xs font-semibold">
          {approvalLabel()}
        </div>
      </div>

      <div className="mb-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-1.5 text-sm">
          <span className="font-medium">Batch</span>
          <select
            value={batchId}
            onChange={(event) => {
              setBatchId(event.target.value);
              setSessionId("");
              setChanges({});
              setMessage(null);
            }}
            className="min-h-11 rounded-md border bg-background px-3 text-sm"
          >
            <option value="">Select batch</option>
            {batches.map((batch) => (
              <option key={batch.id} value={batch.id}>
                {batch.name}
              </option>
            ))}
          </select>
        </label>

        <label className="grid gap-1.5 text-sm">
          <span className="font-medium">Class session</span>
          <select
            value={selectedSessionId}
            onChange={(event) => {
              setSessionId(event.target.value);
              setChanges({});
              setMessage(null);
            }}
            className="min-h-11 rounded-md border bg-background px-3 text-sm"
          >
            <option value="">Select class session</option>
            {batchSessions.map((session) => (
              <option key={session.id} value={session.id}>
                {session.session_date} • {session.starts_at.slice(0, 5)} •{" "}
                {session.subject_name ?? "Class"}
              </option>
            ))}
          </select>
        </label>
      </div>

      {!selectedSessionId ? (
        <p className="text-sm text-muted-foreground">
          No class session is available for this batch yet.
        </p>
      ) : (
        <>
          <div className="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-xl bg-muted/50 p-3">
            <p className="text-sm text-muted-foreground">
              Marked <span className="font-semibold text-foreground">{markedCount}</span> of{" "}
              <span className="font-semibold text-foreground">{roster.length}</span> students.
              Unmarked students are never assumed present.
            </p>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={markAllPresent}
              disabled={pending || locked || !roster.length}
            >
              Mark all Present
            </Button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left">
                  <th className="p-3">Student</th>
                  <th className="p-3">Attendance status</th>
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
                        <select
                          value={value.status}
                          disabled={locked}
                          onChange={(event) =>
                            setStatus(
                              student.id,
                              event.target.value as AttendanceStatus | ""
                            )
                          }
                          aria-label={`Attendance status for ${student.name}`}
                          className="min-h-10 rounded-md border bg-background px-2 text-sm"
                        >
                          <option value="">Not marked</option>
                          <option value="PRESENT">Present</option>
                          <option value="ABSENT">Absent</option>
                          <option value="LATE">Late</option>
                          <option value="EXCUSED">Excused</option>
                        </select>
                      </td>
                      <td className="p-3">
                        <input
                          value={value.remarks}
                          disabled={locked}
                          onChange={(event) =>
                            setRemarks(student.id, event.target.value)
                          }
                          aria-label={`Attendance remarks for ${student.name}`}
                          placeholder="Optional context"
                          className="min-h-10 w-full rounded-md border bg-background px-3 text-sm"
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            {!roster.length && (
              <p className="py-8 text-center text-muted-foreground">
                No active students are enrolled in this batch.
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
          disabled={pending || locked || !selectedSessionId || !roster.length}
        >
          {pending ? "Working…" : "Save Draft"}
        </Button>

        {!locked && (
          <Button
            type="button"
            onClick={submitApproval}
            disabled={pending || !selectedSessionId || !roster.length}
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
