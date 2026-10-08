"use client";
import { startTransition, useState } from "react";
import Link from "next/link";
import { DocumentPanel } from "@/modules/finance/documents/panel";
import { reimbursementAction } from "./actions";
import type { ClaimData } from "./queries";
type Row = ClaimData["rows"][number];
export function ClaimsRegister({
  data,
  status,
}: {
  data: ClaimData;
  status: string;
}) {
  const [form, setForm] = useState<{
    action: "SAVE" | "SUBMIT" | "RETURN" | "CANCEL" | "POST" | "PAY";
    row?: Row;
  } | null>(null);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState("");
  const [request, setRequest] = useState("");
  const [last, setLast] = useState("");
  function open(action: NonNullable<typeof form>["action"], row?: Row) {
    setForm({ action, row });
    setRequest(crypto.randomUUID());
    setLast("");
    setNotice("");
  }
  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!form || pending) return;
    const v = Object.fromEntries(new FormData(e.currentTarget));
    const input = {
      ...v,
      action: form.action,
      ...(form.row ? { id: form.row.id, revision: form.row.revision } : {}),
      ...(v.amount ? { amount: Number(v.amount) } : {}),
      ...(form.action === "SUBMIT" ? { own_funds: v.own_funds === "on" } : {}),
    };
    const fp = JSON.stringify(input);
    const req = last && last !== fp ? crypto.randomUUID() : request;
    setRequest(req);
    setLast(fp);
    setPending(true);
    startTransition(async () => {
      try {
        const r = await reimbursementAction({ ...input, request_id: req });
        setNotice(r.message);
        if (r.ok) setForm(null);
      } finally {
        setPending(false);
      }
    });
  }
  const opts = (rows: { id: string; name: string }[]) =>
    rows.map((r) => (
      <option key={r.id} value={r.id}>
        {r.name}
      </option>
    ));
  const input = (
    label: string,
    name: string,
    type = "text",
    value?: string,
  ) => (
    <label className="grid gap-1">
      {label}
      <input
        name={name}
        type={type}
        required
        defaultValue={value}
        min={type === "number" ? "0.01" : undefined}
        step={type === "number" ? "0.01" : undefined}
        className="rounded border bg-background p-2"
      />
    </label>
  );
  return (
    <div className="space-y-4">
      <button
        className="rounded border p-2"
        disabled={pending}
        onClick={() => open("SAVE")}
      >
        Create expense claim
      </button>
      {notice && <p role="status">{notice}</p>}
      {form && (
        <form
          data-editor
          data-busy={pending ? "true" : "false"}
          key={`${form.action}:${form.row?.id ?? "new"}`}
          onSubmit={submit}
          className="rounded border p-4"
        >
          <fieldset disabled={pending} className="contents">
            <h2 className="mb-3 text-xl">
              {form.action.replace("SAVE", "Create / edit")} claim{" "}
              {form.row?.claim_no}
            </h2>
            <fieldset disabled={pending} className="grid gap-3 md:grid-cols-2">
              {form.action === "SAVE" && (
                <>
                  <label className="grid gap-1">
                    Staff identity
                    <select
                      name="staff_id"
                      required
                      disabled={!!form.row}
                      defaultValue={form.row?.staff_id ?? ""}
                      className="rounded border bg-background p-2"
                    >
                      <option value="">Select staff</option>
                      {opts(data.staff)}
                    </select>
                    {form.row && (
                      <input
                        type="hidden"
                        name="staff_id"
                        value={form.row.staff_id}
                      />
                    )}
                  </label>
                  <label className="grid gap-1">
                    Expense category
                    <select
                      name="category_id"
                      required
                      defaultValue={form.row?.category_id ?? ""}
                      className="rounded border bg-background p-2"
                    >
                      <option value="">Select category</option>
                      {opts(data.categories)}
                    </select>
                  </label>
                  {input(
                    "Expense date",
                    "expense_date",
                    "date",
                    form.row?.expense_date,
                  )}
                  {input(
                    "Amount personally spent (BDT)",
                    "amount",
                    "number",
                    form.row ? String(form.row.amount) : undefined,
                  )}
                  {input(
                    "Purpose",
                    "description",
                    "text",
                    form.row?.description,
                  )}
                  {input(
                    "Receipt reference",
                    "receipt_reference",
                    "text",
                    form.row?.receipt_reference,
                  )}
                </>
              )}
              {form.action === "SUBMIT" && (
                <label className="flex items-center gap-2">
                  <input name="own_funds" type="checkbox" required />I paid from
                  personal funds and have not claimed an academy advance or
                  another reimbursement for this expense.
                </label>
              )}
              {form.action === "POST" && (
                <p>
                  Verify the receipt, beneficiary, expense date/category and
                  personal-fund declaration. Post staff payable; this does not
                  record payment.
                </p>
              )}
              {form.action === "RETURN" && (
                <p>
                  Return this submitted claim to Draft with a clear correction
                  note.
                </p>
              )}
              {form.action === "CANCEL" && (
                <p>Cancel unused draft; preserve its history and documents.</p>
              )}
              {form.action === "PAY" && (
                <>
                  {input(
                    "Actual amount paid (BDT)",
                    "amount",
                    "number",
                    String(form.row?.remaining ?? 0),
                  )}
                  {input("Payment reference", "reference")}
                  <label className="grid gap-1">
                    Paid from
                    <select
                      name="payment_account_id"
                      required
                      className="rounded border bg-background p-2"
                    >
                      <option value="">Select account</option>
                      {opts(data.accounts)}
                    </select>
                  </label>
                </>
              )}
              <label className="grid gap-1">
                Reason
                <textarea
                  name="reason"
                  minLength={5}
                  maxLength={1000}
                  required
                  className="rounded border bg-background p-2"
                />
              </label>
              <div className="flex gap-3">
                <button
                  type="submit"
                  className="rounded bg-primary p-2 text-primary-foreground"
                >
                  {pending ? "Saving…" : "Confirm"}
                </button>
                <button type="button" onClick={() => setForm(null)}>
                  Close
                </button>
              </div>
            </fieldset>
          </fieldset>
        </form>
      )}
      <form className="flex gap-3">
        <select
          name="status"
          defaultValue={status}
          className="rounded border bg-background p-2"
        >
          {["ALL", "DRAFT", "SUBMITTED", "POSTED", "CANCELLED"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <button>Filter</button>
      </form>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr>
              {[
                "Claim / staff",
                "Expense / receipt",
                "Amount / due",
                "Stage",
                "Actions",
              ].map((s) => (
                <th className="p-3 text-left" key={s}>
                  {s}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="p-3">
                  {r.claim_no}
                  <p>{r.staff_name}</p>
                  <DocumentPanel
                    entityType="REIMBURSEMENT"
                    entityId={r.id}
                    documents={r.documents}
                  />
                </td>
                <td className="p-3">
                  {r.description}
                  <p>
                    {r.category_name} · {r.expense_date}
                  </p>
                  <p>{r.receipt_reference}</p>
                  {r.review_note && <p>Finance note: {r.review_note}</p>}
                </td>
                <td className="p-3">
                  BDT {r.amount.toFixed(2)}
                  {r.status === "POSTED" && <p>Due {r.remaining.toFixed(2)}</p>}
                </td>
                <td className="p-3">
                  {r.status === "POSTED" && r.remaining === 0
                    ? "REIMBURSED"
                    : r.status}
                </td>
                <td className="p-3">
                  <div className="flex flex-wrap gap-3">
                    {r.status === "DRAFT" && (
                      <>
                        <button
                          disabled={pending}
                          onClick={() => open("SAVE", r)}
                        >
                          Edit
                        </button>
                        <button
                          disabled={pending}
                          onClick={() => open("SUBMIT", r)}
                        >
                          Submit
                        </button>
                        <button
                          disabled={pending}
                          onClick={() => open("CANCEL", r)}
                        >
                          Cancel
                        </button>
                      </>
                    )}
                    {r.status === "SUBMITTED" && data.manager && (
                      <>
                        <button
                          disabled={pending}
                          onClick={() => open("POST", r)}
                        >
                          Verify & post
                        </button>
                        <button
                          disabled={pending}
                          onClick={() => open("RETURN", r)}
                        >
                          Request correction
                        </button>
                      </>
                    )}
                    {r.status === "POSTED" &&
                      r.remaining > 0 &&
                      data.canPay && (
                        <button
                          disabled={pending}
                          onClick={() => open("PAY", r)}
                        >
                          Pay reimbursement
                        </button>
                      )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.rows.length && <p>No matching claims.</p>}
      </div>
      <div className="flex justify-between">
        <p>
          {data.total} claims · page {data.page}
        </p>
        <div className="flex gap-4">
          {data.page > 1 && (
            <Link href={`?page=${data.page - 1}&status=${status}`}>
              Previous
            </Link>
          )}
          {data.page * 25 < data.total && (
            <Link href={`?page=${data.page + 1}&status=${status}`}>Next</Link>
          )}
        </div>
      </div>
    </div>
  );
}
