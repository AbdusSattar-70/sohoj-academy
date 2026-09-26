"use client";
import Link from "next/link";
import { useState } from "react";
import { StatusBadge } from "@/components/erp/status-badge";
import { FinanceForm, inputClass, type FinanceField } from "./command-form";
import { RecurringBilling } from "./recurring-billing";
import type { FinanceWorkspace } from "./schema";
const money = (n: number) => `BDT ${n.toFixed(2)}`;
const date = (s: string) =>
  new Date(s).toLocaleString("en-GB", { timeZone: "Asia/Dhaka" });
export function FinanceOperations({
  data,
  permissions,
  profileId,
}: {
  data: FinanceWorkspace;
  permissions: string[];
  profileId: string;
}) {
  const [tab, setTab] = useState("accounts");
  const [selected, setSelected] = useState("");
  const [query, setQuery] = useState("");
  const can = (p: string) => permissions.includes(p);
  const admission = data.admissions.find((a) => a.id === selected);
  const invoices = data.invoices.filter((i) => i.admissionId === selected);
  const pending = data.approvals.filter((a) => a.status === "PENDING");
  const paymentFields: FinanceField[] = [
    {
      key: "payment_method_id",
      label: "Payment Method",
      options: data.paymentMethods,
    },
    {
      key: "external_reference",
      label: "Transaction Reference",
      optional: true,
    },
  ];
  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          ["Outstanding", money(data.invoices.reduce((s, i) => s + i.due, 0))],
          [
            "Customer credit",
            money(data.invoices.reduce((s, i) => s + i.credit, 0)),
          ],
          ["Awaiting decision", pending.length],
        ].map(([label, value]) => (
          <div key={label} className="rounded-2xl border bg-card p-5">
            <p className="text-sm text-muted-foreground">{label}</p>
            <p className="mt-2 text-2xl font-semibold">{value}</p>
          </div>
        ))}
      </div>
      <nav aria-label="Finance sections" className="flex flex-wrap gap-2">
        {[
          ["accounts", "Student Accounts"],
          ["approvals", `Approvals (${pending.length})`],
          ["recurring", "Recurring Billing"],
        ].map(([key, label]) => (
          <button
            key={key}
            type="button"
            aria-pressed={tab === key}
            className={`min-h-11 rounded-xl border px-4 text-sm font-medium ${tab === key ? "bg-primary text-primary-foreground" : "bg-card"}`}
            onClick={() => setTab(key)}
          >
            {label}
          </button>
        ))}
      </nav>
      {tab === "accounts" && (
        <>
          <section className="space-y-3 rounded-2xl border bg-card p-5">
            <h2 className="font-semibold">Open a Student Account</h2>
            <input
              aria-label="Search student accounts"
              placeholder="Search student name or admission number"
              className={inputClass}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            <select
              aria-label="Student account"
              className={inputClass}
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
            >
              <option value="">Select an admission</option>
              {data.admissions
                .filter(
                  (a) =>
                    a.id === selected ||
                    `${a.name} ${a.number}`
                      .toLowerCase()
                      .includes(query.toLowerCase()),
                )
                .map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.number} · {a.name} · {a.status.replaceAll("_", " ")}
                  </option>
                ))}
            </select>
            {!data.admissions.length && (
              <p className="text-sm">
                Create an admission first from the{" "}
                <Link href="/dashboard/admissions" className="underline">
                  Admissions workspace
                </Link>
                .
              </p>
            )}
          </section>
          {admission && (
            <div className="space-y-5" key={admission.id}>
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-xl font-semibold">{admission.name}</h2>
                  <Link
                    href={`/dashboard/admissions#${admission.id}`}
                    className="text-sm underline"
                  >
                    {admission.number} · Admission record
                  </Link>
                </div>
                <StatusBadge value={admission.status} />
              </div>
              {data.discounts
                .filter((d) => d.admissionId === selected)
                .map((d) => (
                  <p
                    key={d.id}
                    className="rounded-xl border bg-muted/30 p-4 text-sm"
                  >
                    Approved tuition discount:{" "}
                    <strong>
                      {d.kind === "PERCENT" ? `${d.value}%` : money(d.value)}
                    </strong>{" "}
                    per eligible invoice, {d.startsOn} – {d.endsOn}. Effective
                    dates match the billing period.
                  </p>
                ))}
              {admission.status !== "CANCELLED" && (
                <div className="grid gap-4 lg:grid-cols-2">
                  {can("finance.billing.manage") && (
                    <details className="rounded-xl border p-4">
                      <summary className="cursor-pointer font-medium">
                        Request a Discount
                      </summary>
                      <div className="mt-4">
                        <FinanceForm
                          defaults={{
                            action: "REQUEST_DISCOUNT",
                            admission_id: selected,
                          }}
                          label="Submit Discount for Approval"
                          description="Applies only to tuition, capped at the tuition charge. Existing eligible invoices receive credit after independent approval; original charges stay unchanged."
                          fields={[
                            {
                              key: "kind",
                              label: "Discount Type",
                              options: [
                                {
                                  id: "PERCENT",
                                  name: "Percentage of tuition",
                                },
                                { id: "FIXED", name: "Fixed BDT per invoice" },
                              ],
                            },
                            {
                              key: "value",
                              label: "Discount Value",
                              type: "number",
                            },
                            {
                              key: "starts_on",
                              label: "First Eligible Billing Date",
                              type: "date",
                              hint: "Use the first day of the month for monthly invoices.",
                            },
                            {
                              key: "ends_on",
                              label: "Last Eligible Billing Date",
                              type: "date",
                            },
                          ]}
                        />
                      </div>
                    </details>
                  )}
                  {can("admissions.create") && (
                    <details className="rounded-xl border p-4">
                      <summary className="cursor-pointer font-medium">
                        Request Cancellation
                      </summary>
                      <div className="mt-4">
                        <FinanceForm
                          defaults={{
                            action: "REQUEST_CANCEL",
                            admission_id: selected,
                          }}
                          label="Submit Cancellation for Approval"
                          description="Approval withdraws enrollment and stops future billing. Credit all charges makes paid money refundable; it does not record a refund payout."
                          fields={[
                            {
                              key: "settlement",
                              label: "Existing Charges",
                              options: [
                                {
                                  id: "KEEP_CHARGES",
                                  name: "Keep outstanding charges payable",
                                },
                                {
                                  id: "CREDIT_ALL",
                                  name: "Credit all remaining charges",
                                },
                              ],
                            },
                          ]}
                        />
                      </div>
                    </details>
                  )}
                </div>
              )}
              {!invoices.length && (
                <p className="rounded-xl border border-dashed p-5 text-sm">
                  No invoices yet. Post initial billing from the admission
                  record.
                </p>
              )}
              {invoices.map((i) => (
                <article
                  key={i.id}
                  className="space-y-4 rounded-2xl border bg-card p-5"
                >
                  <div className="flex flex-wrap justify-between gap-3">
                    <div>
                      <h3 className="font-semibold">
                        {i.number} ·{" "}
                        {i.kind === "INITIAL"
                          ? "Initial billing"
                          : "Recurring billing"}
                      </h3>
                      <p className="text-sm text-muted-foreground">
                        Period {i.period} · Due {i.dueOn}
                      </p>
                    </div>
                    <Link
                      href={`/dashboard/finance/billing/${i.id}/print`}
                      className="text-sm underline"
                    >
                      Print Account Statement
                    </Link>
                  </div>
                  <div className="grid gap-3 sm:grid-cols-4">
                    {[
                      ["Original charges", i.gross],
                      ["Approved credits", i.credits],
                      ["Net charges", i.net],
                      ["Money received", i.paid],
                      ["Actual refunds", i.refunded],
                      ["Outstanding", i.due],
                      ["Customer credit", i.credit],
                      ["Reserved refunds", i.reserved],
                    ].map(([label, amount]) => (
                      <div key={label}>
                        <p className="text-xs text-muted-foreground">{label}</p>
                        <p className="font-medium">{money(Number(amount))}</p>
                      </div>
                    ))}
                  </div>
                  <details>
                    <summary className="cursor-pointer text-sm">
                      Original charge lines
                    </summary>
                    <ul className="mt-2 space-y-1 text-sm">
                      {i.lines.map((l, n) => (
                        <li key={n} className="flex justify-between">
                          <span>{l.name}</span>
                          <span>{money(l.amount)}</span>
                        </li>
                      ))}
                    </ul>
                  </details>
                  {i.due > 0 && can("finance.payments.post") && (
                    <details>
                      <summary className="cursor-pointer text-sm font-medium">
                        Collect Payment
                      </summary>
                      <div className="mt-3">
                        <FinanceForm
                          defaults={{
                            action: "PAY",
                            admission_id: selected,
                            invoice_id: i.id,
                          }}
                          label="Post Actual Payment"
                          description={`Enter only money actually received. Outstanding: ${money(i.due)}.`}
                          fields={[
                            {
                              key: "amount",
                              label: "Amount Received (BDT)",
                              type: "number",
                              max: i.due,
                            },
                            ...paymentFields,
                          ]}
                        />
                      </div>
                    </details>
                  )}
                  {data.payments
                    .filter((p) => p.invoiceId === i.id)
                    .map((p) => (
                      <div key={p.id} className="rounded-xl border p-4">
                        <p className="text-sm font-semibold">
                          {p.number} · {money(p.amount)} received
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {p.method} · {date(p.postedAt)}
                        </p>
                        {can("finance.payments.post") &&
                          Math.min(p.remaining, i.credit - i.reserved) > 0 && (
                            <details className="mt-3">
                              <summary className="cursor-pointer text-sm">
                                Request Refund
                              </summary>
                              <div className="mt-3">
                                <FinanceForm
                                  defaults={{
                                    action: "REQUEST_REFUND",
                                    payment_id: p.id,
                                  }}
                                  label="Submit Refund for Approval"
                                  description={`Maximum available: ${money(Math.min(p.remaining, i.credit - i.reserved))}. Approval reserves the credit; record the actual payout separately.`}
                                  fields={[
                                    {
                                      key: "amount",
                                      label: "Refund Amount (BDT)",
                                      type: "number",
                                      max: Math.min(
                                        p.remaining,
                                        i.credit - i.reserved,
                                      ),
                                    },
                                  ]}
                                />
                              </div>
                            </details>
                          )}
                      </div>
                    ))}
                  {data.refunds
                    .filter((r) => r.invoiceId === i.id)
                    .map((r) => (
                      <div
                        key={r.id}
                        className="space-y-3 rounded-xl border p-4"
                      >
                        <p className="text-sm font-semibold">
                          {r.number ?? "Approved refund · awaiting payout"} ·{" "}
                          {money(r.amount)}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Original receipt:{" "}
                          {
                            data.payments.find((p) => p.id === r.paymentId)
                              ?.number
                          }
                          {r.postedAt
                            ? ` · ${date(r.postedAt)} · ${r.method} · ${r.reference ?? "No external reference"}`
                            : " · No money recorded as returned yet."}
                        </p>
                        {!r.number && can("finance.payments.post") && (
                          <FinanceForm
                            defaults={{
                              action: "POST_REFUND",
                              authorization_id: r.id,
                            }}
                            label="Record Actual Refund Payout"
                            description={`Confirm ${money(r.amount)} has actually been returned. This creates a permanent refund record.`}
                            fields={paymentFields}
                          />
                        )}
                      </div>
                    ))}
                </article>
              ))}
            </div>
          )}
        </>
      )}
      {tab === "approvals" && (
        <section className="space-y-4">
          <div>
            <h2 className="text-lg font-semibold">Independent Review</h2>
            <p className="text-sm text-muted-foreground">
              The requester cannot approve or reject their own request.
              Decisions and reasons remain in the audit trail.
            </p>
          </div>
          {!data.approvals.length && (
            <p className="rounded-xl border border-dashed p-5">
              No finance or cancellation requests yet.
            </p>
          )}
          {data.approvals.map((a) => {
            const account = data.admissions.find((r) => r.id === a.admissionId);
            const p = a.payload;
            const permission =
              a.type === "FINANCE_DISCOUNT"
                ? "finance.discounts.approve"
                : a.type === "ADMISSION_CANCEL"
                  ? "admissions.approve"
                  : "finance.payments.reverse";
            const accountInvoices = data.invoices.filter(
              (i) => i.admissionId === a.admissionId,
            );
            return (
              <article
                key={a.id}
                className="space-y-3 rounded-2xl border bg-card p-5"
              >
                <div className="flex justify-between gap-3">
                  <h3 className="font-semibold">
                    {account?.name} · {a.type.replaceAll("_", " ")}
                  </h3>
                  <StatusBadge value={a.status} />
                </div>
                <p className="text-xs text-muted-foreground">
                  Requested by {a.requester} · {date(a.createdAt)}
                </p>
                <p className="text-sm">{a.reason}</p>
                <p className="rounded-xl bg-muted/40 p-3 text-sm">
                  {a.type === "FINANCE_DISCOUNT"
                    ? `${p.kind === "PERCENT" ? `${p.value}%` : money(Number(p.value))} tuition discount per eligible invoice, ${p.starts_on} – ${p.ends_on}.`
                    : a.type === "ADMISSION_CANCEL"
                      ? `${p.settlement === "CREDIT_ALL" ? "Credit all remaining charges" : "Keep existing charges payable"}. Current net charges: ${money(accountInvoices.reduce((s, i) => s + i.net, 0))}. Current customer credit: ${money(accountInvoices.reduce((s, i) => s + i.credit, 0))}. Enrollment will be withdrawn and future billing stopped.`
                      : `Refund ${money(Number(p.amount))} from ${data.payments.find((x) => x.id === p.payment_id)?.number ?? "original payment"}. Approval reserves credit; payout must be recorded separately.`}
                </p>
                {a.status === "PENDING" ? (
                  a.requesterId === profileId ? (
                    <p className="text-sm text-muted-foreground">
                      Waiting for a different authorized reviewer.
                    </p>
                  ) : (
                    can(permission) && (
                      <FinanceForm
                        defaults={{ action: "DECIDE", approval_id: a.id }}
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
                        label="Record Decision"
                      />
                    )
                  )
                ) : (
                  <p className="text-sm text-muted-foreground">
                    Decision note: {a.decisionNote}
                  </p>
                )}
              </article>
            );
          })}
        </section>
      )}
      {tab === "recurring" && (
        <div className="space-y-5">
          {can("finance.billing.manage") ? (
            <>
              <RecurringBilling terms={data.terms} />
              <details className="rounded-xl border p-5">
                <summary className="cursor-pointer font-medium">
                  Create an Academic Billing Term
                </summary>
                <div className="mt-4">
                  <FinanceForm
                    defaults={{ action: "CREATE_TERM" }}
                    label="Create Billing Term"
                    description="For TERM Fee Plans. The initial invoice covers the first cycle; later terms generate recurring charges. Terms cannot overlap or be changed after creation."
                    fields={[
                      {
                        key: "academic_year_id",
                        label: "Academic Year",
                        options: data.years,
                      },
                      { key: "name", label: "Term Name" },
                      { key: "starts_on", label: "Starts On", type: "date" },
                      { key: "ends_on", label: "Ends On", type: "date" },
                      { key: "due_on", label: "Payment Due On", type: "date" },
                    ]}
                  />
                </div>
              </details>
            </>
          ) : (
            <p>
              Billing management permission is required to post recurring
              charges.
            </p>
          )}
          <section className="rounded-2xl border p-5">
            <h2 className="font-semibold">Billing Run History</h2>
            {!data.runs.length && (
              <p className="mt-2 text-sm text-muted-foreground">
                No recurring billing runs posted.
              </p>
            )}
            <ul className="mt-3 space-y-3 text-sm">
              {data.runs.map((r) => (
                <li
                  key={r.id}
                  className="flex flex-wrap justify-between gap-2 border-b pb-3"
                >
                  <span>
                    {r.period} · {r.count} invoices
                  </span>
                  <span>
                    Gross {money(r.gross)} · {date(r.postedAt)}
                  </span>
                </li>
              ))}
            </ul>
          </section>
        </div>
      )}
    </div>
  );
}
