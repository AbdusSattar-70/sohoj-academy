"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { reviewStaffAccess } from "./actions";
type RequestRow = {
  id: string;
  full_name: string;
  email: string;
  mobile: string;
  requested_role: string;
  purpose: string;
  status: string;
  assigned_role: string | null;
};
export function AccessRequestRegister({ rows }: { rows: RequestRow[] }) {
  return (
    <div className="space-y-4">
      {rows.length ? (
        rows.map((r) => <RequestCard key={r.id} row={r} />)
      ) : (
        <p className="rounded-xl border p-6">No staff requests yet.</p>
      )}
    </div>
  );
}
function RequestCard({ row: r }: { row: RequestRow }) {
  const [role, setRole] = useState(r.assigned_role ?? r.requested_role),
    [note, setNote] = useState(
      "Verified identity, contact details and required responsibilities",
    ),
    [message, setMessage] = useState("");
  const [pending, start] = useTransition();
  const router = useRouter();
  function act(action: "VERIFY" | "DECLINE" | "INVITE") {
    start(async () => {
      try {
        const result = await reviewStaffAccess({
          id: r.id,
          action,
          assigned_role: role,
          reason: note,
        });
        setMessage(result.message);
        if (result.ok) router.refresh();
      } catch {
        setMessage(
          "Could not finish this action. Refresh the request before retrying.",
        );
      }
    });
  }
  return (
    <article className="rounded-2xl border bg-card p-5">
      <div className="flex flex-wrap justify-between gap-3">
        <div>
          <h2 className="font-semibold">{r.full_name}</h2>
          <p className="text-sm">
            {r.email} · {r.mobile}
          </p>
        </div>
        <span className="text-xs font-bold">{r.status}</span>
      </div>
      <p className="my-3 text-sm">
        Requested {r.requested_role}: {r.purpose}
      </p>
      {["PENDING", "VERIFIED", "INVITED"].includes(r.status) && (
        <div className="space-y-3">
          <label className="block text-sm">
            Verified role
            <select
              disabled={r.status === "INVITED"}
              value={role}
              onChange={(e) => setRole(e.target.value)}
              className="ml-3 rounded-lg border bg-background p-2"
            >
              {["ADMIN", "OPERATOR", "TEACHER", "ACCOUNTANT"].map((v) => (
                <option key={v}>{v}</option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            Verification note
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="mt-1 w-full rounded-lg border bg-background p-3"
            />
          </label>
          <div className="flex gap-3">
            {r.status !== "INVITED" && (
              <>
                <button
                  disabled={pending}
                  className="rounded-lg border p-3 text-sm"
                  onClick={() => act("VERIFY")}
                >
                  Verify role
                </button>
                <button
                  disabled={pending}
                  className="rounded-lg border p-3 text-sm"
                  onClick={() => act("DECLINE")}
                >
                  Decline
                </button>
              </>
            )}
            {["VERIFIED", "INVITED"].includes(r.status) && (
              <button
                disabled={pending}
                className="rounded-lg bg-primary p-3 text-sm text-primary-foreground"
                onClick={() => act("INVITE")}
              >
                {r.status === "INVITED"
                  ? "Resend setup link"
                  : "Send Supabase setup link"}
              </button>
            )}
          </div>
        </div>
      )}
      {message && (
        <p role="status" className="mt-3 text-sm">
          {message}
        </p>
      )}
    </article>
  );
}
