import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getStudentProfile } from "@/modules/students/lifecycle/queries";
import { StudentForm } from "@/modules/students/lifecycle/command-form";
const money = (n: number) => `BDT ${n.toFixed(2)}`;
const when = (s: string) =>
  new Date(s).toLocaleString("en-GB", { timeZone: "Asia/Dhaka" });
export default async function StudentProfilePage({
  params,
}: {
  params: Promise<{ studentId: string }>;
}) {
  const context = await requirePermission("students.view");
  const { studentId } = await params;
  if (!z.string().uuid().safeParse(studentId).success) notFound();
  const data = await getStudentProfile(studentId);
  if (!data) notFound();
  const s = data.student;
  const canonical = s.id === s.canonicalId;
  const can = (p: string) => context.permissions.includes(p);
  const usable = canonical && s.status !== "ARCHIVED";
  const options = data.batches.map((b) => ({
    id: b.id,
    name: `${b.name} · ${b.year} · ${b.class} · ${b.offering} · ${b.occupied}/${b.capacity} seats`,
  }));
  const openSource =
    data.admissions.some(
      (a) => a.studentId === s.id && a.status !== "CANCELLED",
    ) ||
    data.enrollments.some((e) => e.studentId === s.id && e.status === "ACTIVE");
  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Student Record"
        title={`${s.number} · ${s.name}`}
        description="Permanent identity, guardian contacts, enrollment history and controlled lifecycle actions."
      />
      <div className="flex flex-wrap gap-4 text-sm">
        <Link className="underline" href="/dashboard/students">
          Student register
        </Link>
        {can("admissions.view") && (
          <Link className="underline" href="/dashboard/admissions">
            Admissions
          </Link>
        )}
        {can("finance.view") && (
          <Link className="underline" href="/dashboard/finance/billing">
            Billing & Adjustments
          </Link>
        )}
        <StatusBadge value={s.status} />
      </div>
      {!canonical && (
        <p className="rounded-xl border bg-muted/40 p-5 text-sm">
          This duplicate identity was archived after independent approval. Use{" "}
          <Link
            className="font-semibold underline"
            href={`/dashboard/students/${s.canonicalId}`}
          >
            {s.canonicalNumber}
          </Link>{" "}
          for new work. Original records remain under their original IDs; the
          history below includes the linked identities.
        </p>
      )}
      <section className="rounded-2xl border bg-card p-5">
        <h2 className="font-semibold">Student Identity</h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-3">
          {[
            ["Name", s.name],
            ["Bangla name", s.nameBn ?? "Not recorded"],
            ["Date of birth", s.birthDate ?? "Not recorded"],
            ["School", s.school ?? "Not recorded"],
            ["Created", when(s.createdAt)],
            ["Canonical Student ID", s.canonicalNumber],
          ].map(([label, value]) => (
            <div key={label}>
              <dt className="text-xs text-muted-foreground">{label}</dt>
              <dd className="mt-1 text-sm font-medium">{value}</dd>
            </div>
          ))}
        </dl>
        {data.identities.length > 1 && (
          <p className="mt-4 text-sm">
            Linked historical identities:{" "}
            {data.identities.map((i) => (
              <Link
                key={i.id}
                className="mr-3 underline"
                href={`/dashboard/students/${i.id}`}
              >
                {i.number}
              </Link>
            ))}
          </p>
        )}
      </section>
      <section>
        <h2 className="mb-3 font-semibold">Guardian Contacts</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          {data.guardians.map((g) => (
            <article key={g.id} className="rounded-xl border bg-card p-4">
              <h3 className="font-medium">
                {g.name}{" "}
                {g.primary && (
                  <span className="text-xs text-muted-foreground">
                    · Primary for{" "}
                    {data.identities.find((i) => i.id === g.studentId)?.number}
                  </span>
                )}
              </h3>
              <p className="mt-1 text-sm">
                {g.relationship ?? "Guardian"} · {g.mobile}
                {g.alternateMobile ? ` · ${g.alternateMobile}` : ""}
              </p>
            </article>
          ))}
        </div>
      </section>
      {usable && can("admissions.create") && (
        <details className="rounded-2xl border p-5">
          <summary className="cursor-pointer font-semibold">
            Enroll This Existing Student
          </summary>
          <div className="mt-4">
            <StudentForm
              defaults={{ action: "CREATE_EXISTING", student_id: s.id }}
              fields={[
                {
                  key: "batch_id",
                  label: "Programme / Batch",
                  options: options.filter((o) => {
                    const b = data.batches.find((b) => b.id === o.id)!;
                    return b.occupied < b.capacity;
                  }),
                  hint: "Choose placement for this enrollment. Only batches with available capacity are listed; seats are checked again at activation.",
                },
              ]}
              label="Create Enrollment Draft"
              description="Keeps this Student ID and primary guardian. The selected Fee Plan, including its one-time charges, is loaded into a new draft for review. Earlier debts and discounts stay with their original admission. One active enrollment per academic year is currently supported."
            />
          </div>
        </details>
      )}
      <section className="space-y-3">
        <h2 className="font-semibold">Admission Cases</h2>
        {data.admissions.map((a) => (
          <article
            key={a.id}
            className="space-y-3 rounded-xl border bg-card p-4"
          >
            <div className="flex flex-wrap justify-between gap-3">
              <div>
                {can("admissions.view") ? (
                  <Link
                    className="font-semibold underline"
                    href={`/dashboard/admissions#${a.id}`}
                  >
                    {a.number}
                  </Link>
                ) : (
                  <p className="font-semibold">{a.number}</p>
                )}
                <p className="mt-1 text-sm text-muted-foreground">
                  {a.batch} · Fee Plan v{a.feeVersion} · {when(a.createdAt)}
                </p>
              </div>
              <StatusBadge value={a.status} />
            </div>
            {usable &&
              a.studentId === s.id &&
              a.status === "ACTIVE_ENROLLMENT" &&
              can("students.manage") && (
                <details>
                  <summary className="cursor-pointer text-sm font-medium">
                    Request Batch Transfer
                  </summary>
                  <div className="mt-3">
                    <StudentForm
                      defaults={{
                        action: "REQUEST_TRANSFER",
                        student_id: s.id,
                        admission_id: a.id,
                      }}
                      fields={[
                        {
                          key: "batch_id",
                          label: "Destination Batch",
                          options: options.filter((o) => {
                            const b = data.batches.find((b) => b.id === o.id)!;
                            return (
                              b.offeringId === a.offeringId &&
                              b.id !== a.batchId &&
                              b.occupied < b.capacity
                            );
                          }),
                        },
                      ]}
                      label="Submit Transfer for Approval"
                      description="Choose a different batch in the same offering. An independent reviewer must approve. Capacity is checked again; Fee Plan, invoices and payment history are preserved."
                    />
                  </div>
                </details>
              )}
          </article>
        ))}
        {!data.admissions.length && (
          <p className="text-sm text-muted-foreground">
            No admission history recorded.
          </p>
        )}
      </section>
      <section className="rounded-2xl border bg-card p-5">
        <h2 className="font-semibold">Enrollment History</h2>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full min-w-[600px] text-left text-sm">
            <thead>
              <tr className="border-b">
                <th className="py-2">Academic year</th>
                <th>Class / Batch</th>
                <th>Start</th>
                <th>End</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {data.enrollments.map((e) => (
                <tr key={e.id} className="border-b">
                  <td className="py-3">{e.year}</td>
                  <td>
                    {e.class} · {e.batch ?? "—"}
                  </td>
                  <td>{e.startsOn}</td>
                  <td>{e.endsOn ?? "—"}</td>
                  <td>
                    <StatusBadge value={e.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!data.enrollments.length && (
          <p className="mt-3 text-sm text-muted-foreground">
            No enrollment has been activated.
          </p>
        )}
        {data.transfers.map((t) => (
          <p key={t.id} className="mt-3 text-sm">
            Approved transfer on {t.date}: {t.fromBatch} → {t.toBatch}. The
            previous enrollment was closed and retained.
          </p>
        ))}
      </section>
      {data.financeVisible && (
        <section className="space-y-3 rounded-2xl border bg-card p-5">
          <h2 className="font-semibold">Financial History</h2>
          <p className="text-sm">
            Outstanding:{" "}
            <strong>
              {money(data.invoices.reduce((sum, i) => sum + i.due, 0))}
            </strong>{" "}
            · Customer credit:{" "}
            <strong>
              {money(data.invoices.reduce((sum, i) => sum + i.credit, 0))}
            </strong>
            . Balances remain separate per invoice.
          </p>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[700px] text-left text-sm">
              <thead>
                <tr className="border-b">
                  <th className="py-2">Invoice / Period</th>
                  <th>Gross</th>
                  <th>Credits</th>
                  <th>Paid</th>
                  <th>Refunded</th>
                  <th>Due</th>
                </tr>
              </thead>
              <tbody>
                {data.invoices.map((i) => (
                  <tr key={i.id} className="border-b">
                    <td className="py-3">
                      <Link
                        className="underline"
                        href={`/dashboard/finance/billing/${i.id}/print`}
                      >
                        {i.number}
                      </Link>
                      <span className="block text-xs text-muted-foreground">
                        {i.period} ·{" "}
                        {
                          data.identities.find((s) => s.id === i.studentId)
                            ?.number
                        }
                      </span>
                    </td>
                    {[i.gross, i.credits, i.paid, i.refunded, i.due].map(
                      (amount, n) => (
                        <td key={n}>{amount.toFixed(2)}</td>
                      ),
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {!data.invoices.length && (
            <p className="text-sm text-muted-foreground">No posted invoices.</p>
          )}
        </section>
      )}
      {usable && can("students.manage") && (
        <section className="space-y-4 rounded-2xl border p-5">
          <h2 className="font-semibold">Duplicate Identity Review</h2>
          <p className="text-sm text-muted-foreground">
            Matches are suggestions, not proof. Siblings may share a guardian
            number. Review both profiles and verify the same person before
            requesting a merge.
          </p>
          {data.candidates.map((c) => (
            <div key={c.id} className="rounded-xl border p-4 text-sm">
              <Link
                className="font-medium underline"
                href={`/dashboard/students/${c.id}`}
              >
                {c.number} · {c.name}
              </Link>
              <p className="mt-1 text-muted-foreground">
                {c.status} · Birth date {c.birthDate ?? "not recorded"} ·{" "}
                {c.school ?? "School not recorded"} ·{" "}
                {c.mobile ?? "No primary mobile"}
              </p>
            </div>
          ))}
          {!data.candidates.length ? (
            <p className="text-sm">
              No matching name or guardian mobile found.
            </p>
          ) : openSource ? (
            <p className="text-sm">
              This identity has an open admission or active enrollment. Resolve
              those through the controlled cancellation workflow before
              requesting to archive this identity as a duplicate.
            </p>
          ) : (
            <StudentForm
              defaults={{ action: "REQUEST_MERGE", student_id: s.id }}
              fields={[
                {
                  key: "target_id",
                  label: "Keep This Canonical Student ID",
                  options: data.candidates.map((c) => ({
                    id: c.id,
                    name: `${c.number} · ${c.name}`,
                  })),
                },
              ]}
              label="Submit Duplicate Resolution"
              description={`Approval archives ${s.number} and links its history to the selected Student ID. No original invoice, payment, guardian link or number is deleted or reassigned. Explain the identity evidence in your reason. This merge cannot be undone through this screen.`}
            />
          )}
        </section>
      )}
      <section id="reviews" className="space-y-4">
        <h2 className="font-semibold">Lifecycle Requests & Decisions</h2>
        {!data.approvals.length && (
          <p className="text-sm text-muted-foreground">
            No transfer or duplicate-resolution requests yet.
          </p>
        )}
        {data.approvals.map((r) => {
          const p = r.payload;
          const source = p.source_snapshot as
            { student_no?: string; full_name?: string } | undefined;
          const target = p.target_snapshot as
            { student_no?: string; full_name?: string } | undefined;
          return (
            <article
              key={r.id}
              className="space-y-3 rounded-xl border bg-card p-5"
            >
              <div className="flex flex-wrap justify-between gap-3">
                <h3 className="font-semibold">
                  {r.type === "STUDENT_TRANSFER"
                    ? "Batch transfer"
                    : "Duplicate resolution"}
                </h3>
                <StatusBadge value={r.status} />
              </div>
              <p className="text-sm">
                {r.type === "STUDENT_TRANSFER"
                  ? `${p.student_no} · ${p.from_batch_name} → ${p.to_batch_name}`
                  : `Archive ${source?.student_no} (${source?.full_name}) → keep ${target?.student_no} (${target?.full_name})`}
              </p>
              <p className="text-sm">{r.reason}</p>
              <p className="text-xs text-muted-foreground">
                Requested by {r.requester} · {when(r.createdAt)}
              </p>
              {r.type === "STUDENT_MERGE" && (
                <div className="flex gap-4 text-sm">
                  <Link
                    className="underline"
                    href={`/dashboard/students/${String(p.student_id)}`}
                  >
                    Review source profile
                  </Link>
                  <Link
                    className="underline"
                    href={`/dashboard/students/${String(p.target_id)}`}
                  >
                    Review retained profile
                  </Link>
                </div>
              )}
              {r.status === "PENDING" ? (
                r.requesterId === context.profileId ? (
                  <p className="text-sm text-muted-foreground">
                    A different authorized person must review this request.
                  </p>
                ) : (
                  can(
                    r.type === "STUDENT_MERGE"
                      ? "students.merge.approve"
                      : "admissions.approve",
                  ) && (
                    <StudentForm
                      defaults={{ action: "DECIDE", approval_id: r.id }}
                      fields={[
                        {
                          key: "decision",
                          label: "Decision",
                          options: [
                            { id: "APPROVED", name: "Approve" },
                            { id: "REJECTED", name: "Reject" },
                          ],
                        },
                      ]}
                      label="Record Independent Decision"
                      description="Verify the identities and impact before approving. The database rechecks eligibility when the decision is posted."
                    />
                  )
                )
              ) : (
                <p className="text-sm text-muted-foreground">
                  Decision: {r.decisionNote}
                </p>
              )}
            </article>
          );
        })}
      </section>
    </div>
  );
}
