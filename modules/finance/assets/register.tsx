"use client";
import { startTransition, useState } from "react";
import Link from "next/link";
import { assetAction } from "./actions";
import { DocumentPanel } from "@/modules/finance/documents/panel";
import type { AssetData } from "./queries";
type Row = AssetData["rows"][number];
type Action = "SAVE" | "ACQUIRE" | "DETAILS" | "TRANSFER" | "MARK_INACTIVE" | "ACTIVATE" | "CANCEL" | "ACKNOWLEDGE" | "DEPRECIATE" | "PAY" | "DISPOSE" | "MAINTENANCE";
const money = (n: number) => `BDT ${n.toFixed(2)}`;
export function AssetsRegister({ data, status, search }: {
    data: AssetData;
    status: string;
    search: string;
}) {
    const [form, setForm] = useState<{
        action: Action;
        row?: Row;
    } | null>(null);
    const [pending, setPending] = useState(false);
    const [notice, setNotice] = useState("");
    const [request, setRequest] = useState("");
    const [last, setLast] = useState("");
    const [source, setSource] = useState("");
    function open(action: Action, row?: Row) { setForm({ action, row }); setSource(row?.source_purchase_id ?? ""); setRequest(crypto.randomUUID()); setLast(""); setNotice(""); }
    function submit(e: React.FormEvent<HTMLFormElement>) { e.preventDefault(); if (!form || pending)
        return; const values = Object.fromEntries(new FormData(e.currentTarget)); const v: Record<string, unknown> = { ...values }; for (const key of ["cost", "residual", "life_months", "proceeds", "amount"]) {
        if (key in v)
            v[key] = v[key] === "" ? undefined : Number(v[key]);
    } for (const key of ["vendor_id", "source_purchase_id", "payment_account_id", "custodian_id", "expense_id"]) {
        if (v[key] === "")
            v[key] = undefined;
    } for (const key of ["month", "depreciation_start"]) {
        if (v[key])
            v[key] = `${v[key]}-01`;
    } const input = { ...v, action: form.action, ...(form.row ? { id: form.row.id, revision: form.row.revision, transfer_id: form.row.transfer_id ?? undefined } : {}), confirmed: values.confirmed === "on" }; const fp = JSON.stringify(input); const id = last && last !== fp ? crypto.randomUUID() : request; setRequest(id); setLast(fp); setPending(true); startTransition(async () => { try {
        const r = await assetAction({ ...input, request_id: id });
        setNotice(r.message);
        if (r.ok)
            setForm(null);
    }
    finally {
        setPending(false);
    } }); }
    const opts = (choices: {
        id: string;
        name: string;
    }[]) => choices.map(c => <option key={c.id} value={c.id}>{c.name}</option>);
    const field = (label: string, name: string, type = "text", value?: string, required = true) => <label className="grid gap-1">{label}<input name={name} type={type} defaultValue={value} required={required} min={type === "number" ? "0" : undefined} step={type === "number" ? "0.01" : undefined} className="rounded border bg-background p-2"/></label>;
    const select = (label: string, name: string, choices: {
        id: string;
        name: string;
    }[], value?: string, required = true) => <label className="grid gap-1">{label}<select name={name} defaultValue={value ?? ""} required={required} className="rounded border bg-background p-2"><option value="">Choose…</option>{opts(choices)}</select></label>;
    const row = form?.row;
    return <div className="space-y-4">{data.manager && <button className="rounded border px-4 py-2" disabled={pending} onClick={() => open("SAVE")}>Create asset draft</button>}<p className="text-sm text-muted-foreground">One asset record per identifiable unit/group. Straight-line depreciation uses the configured first month and complete calendar months; inactive assets still depreciate. Invoice references may include a line identifier for multiple assets on one supplier invoice.</p>{notice && <p role="status">{notice}</p>}
 {form && <form key={`${form.action}:${row?.id ?? "new"}`} onSubmit={submit} className="rounded border p-5"><h2 className="mb-4 text-xl">{form.action.replaceAll("_", " ")} · {row?.asset_no ?? "New asset"}</h2><fieldset disabled={pending} className="grid gap-4 md:grid-cols-2">
 {(form.action === "SAVE" || form.action === "DETAILS") && <>{field("Asset name", "name", "text", row?.name)}{field("Serial / tag (optional)", "serial_no", "text", row?.serial_no ?? "", false)}</>}
 {form.action === "SAVE" && <><label className="grid gap-1">Source (optional)<select name="source_purchase_id" value={source} onChange={e => setSource(e.target.value)} className="rounded border bg-background p-2"><option value="">New acquisition · not already posted as expense</option>{row?.source_purchase_id && !data.purchases.some(p => p.id === row.source_purchase_id) && <option value={row.source_purchase_id}>Existing linked purchase</option>}{opts(data.purchases)}</select></label><p>{source ? "Selected purchase supplies cost, supplier and acquisition date; capitalization reclassifies expense without another cash payment." : "Enter actual cost, supplier and acquisition date. Posting will create cash payment or supplier payable."}</p>{select("Supplier", "vendor_id", data.vendors, row?.vendor_id, !source)}{select("Fixed asset account", "asset_account_id", data.assetAccounts, row?.asset_account_id)}{field("Cost (BDT)", "cost", "number", row ? String(row.cost) : undefined, !source)}{field("Residual value (BDT)", "residual", "number", String(row?.residual ?? 0))}{field("Useful life (whole months, 1–600)", "life_months", "number", String(row?.life_months ?? 36))}{field("Acquired on", "acquired_on", "date", row?.acquired_on, !source)}{field("Placed in service on", "in_service_on", "date", row?.in_service_on)}{field("First depreciation month", "depreciation_start", "month", row?.depreciation_start.slice(0, 7))}{field("Invoice / line reference", "invoice_reference", "text", row?.invoice_reference)}<label className="grid gap-1">Location<input name="location" list="asset-locations" defaultValue={row?.location} required className="rounded border bg-background p-2"/></label></>}
 {form.action === "ACQUIRE" && <><p className="md:col-span-2">Capitalize {money(row?.cost ?? 0)}. {row?.source_purchase_id ? "Existing expense is reclassified; its payment/payable is reused." : "Paid now credits the paying account; payable later creates supplier liability."}</p>{field("Capitalization / journal date", "date", "date", row?.acquired_on)}{!row?.source_purchase_id && <><label>Payment treatment<select name="payment_mode" className="ml-2 rounded border bg-background p-2"><option value="ON_ACCOUNT">Supplier payable</option>{data.canPay && <option value="PAID_NOW">Fully paid now</option>}</select></label>{select("Paying account (if paid now)", "payment_account_id", data.accounts, undefined, false)}</>}<label><input name="confirmed" type="checkbox" required/>Asset received, cost/classification and invoice verified</label></>}
 {form.action === "TRANSFER" && <>{select("Custodian (optional)", "custodian_id", data.staff, row?.custodian_id ?? undefined, false)}<label className="grid gap-1">Location<input name="location" list="asset-locations" defaultValue={row?.location} required className="rounded border bg-background p-2"/></label></>}
 {form.action === "ACKNOWLEDGE" && <p>Confirm you received this assigned asset at {row?.location}. The assignment identity is checked again before acknowledgement.</p>}
 {form.action === "DEPRECIATE" && <>{field("Next complete month", "month", "month", row?.next_month.slice(0, 7))}<p>Post in order. Depreciation reduces book value to the residual over {row?.life_months} months; no cash payment is created.</p></>}
 {form.action === "PAY" && <>{field("Actual supplier amount paid (BDT)", "amount", "number", String(row?.remaining ?? 0))}{field("Payment reference", "reference")}{select("Paying account", "payment_account_id", data.accounts)}</>}
 {form.action === "DISPOSE" && <>{field("Disposal date", "date", "date")}{field("Actual proceeds received (BDT; 0 for write-off)", "proceeds", "number", "0")}{field("Disposal / receipt reference", "reference")}{select("Proceeds account (if money received)", "payment_account_id", data.accounts, undefined, false)}<label><input name="confirmed" type="checkbox" required/>Disposal and actual proceeds verified</label><p>Post all completed depreciation months first. Original purchase/custody history remains; unpaid supplier liabilities still need settlement.</p></>}
 {form.action === "MAINTENANCE" && <label className="grid gap-1">Maintenance / inspection details<textarea name="details" minLength={5} maxLength={1000} required className="rounded border bg-background p-2"/></label>}
 {form.action === "MARK_INACTIVE" && <p>Stop new custody assignments. Keep accounting/custody history; depreciation continues.</p>}{form.action === "ACTIVATE" && <p>Reactivate this asset for academy use.</p>}{form.action === "CANCEL" && <p>Cancel an unused draft; no financial history is deleted.</p>}
 <label className="grid gap-1">Reason<textarea name="reason" minLength={5} maxLength={1000} required className="rounded border bg-background p-2"/></label><div className="flex gap-3"><button type="submit" className="rounded bg-primary px-4 py-2 text-primary-foreground">{pending ? "Saving…" : "Confirm"}</button><button type="button" onClick={() => setForm(null)}>Close</button></div></fieldset></form>}
 <datalist id="asset-locations">{data.locations.map(x => <option key={x} value={x}/>)}</datalist><form className="flex flex-wrap gap-3"><input name="q" maxLength={100} defaultValue={search} aria-label="Search assets" placeholder="Asset, tag or location" className="rounded border bg-background p-2"/><select name="status" defaultValue={status} className="rounded border bg-background p-2">{["ALL", "DRAFT", "ACTIVE", "INACTIVE", "DISPOSED", "CANCELLED"].map(s => <option key={s}>{s}</option>)}</select><button>Search</button></form>
 <div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr>{["Asset / evidence", "Custody / location", "Cost / book value", "Status / actions"].map(x => <th className="p-3 text-left" key={x}>{x}</th>)}</tr></thead><tbody>{data.rows.map(a => <tr key={a.id} className="border-t"><td className="p-3"><strong>{a.asset_no} · {a.name}</strong><p>{a.serial_no}</p>{data.manager && <DocumentPanel entityType="ASSET" entityId={a.id} documents={a.documents}/>}<details><summary>Recent history ({a.events.length})</summary>{a.events.map((e, i) => <div className="border-b p-2" key={i}>{e.action} · {e.actor ?? "Staff"} · {new Date(e.date).toLocaleString()}<p>{e.reason}</p><p>{e.details}</p></div>)}</details></td><td className="p-3">{a.custodian ?? "Unassigned"}<p>{a.location}</p>{a.transfer_id && <p>{a.acknowledged ? "Receipt acknowledged" : "Acknowledgement pending"}</p>}{a.own_custody && a.transfer_id && !a.acknowledged && <button disabled={pending} onClick={() => open("ACKNOWLEDGE", a)}>Acknowledge receipt</button>}</td><td className="p-3">Cost {money(a.cost)}<p>Depreciated {money(a.depreciated)}</p><p>Book {money(a.book_value)}</p>{a.payable_id && <p>Supplier due {money(a.remaining)}</p>}</td><td className="p-3"><span className={a.status === "ACTIVE" ? "text-emerald-500" : "text-muted-foreground"}>{a.status}</span>{data.manager && <div className="mt-2 flex flex-wrap gap-3">{a.status === "DRAFT" && <><button disabled={pending} onClick={() => open("SAVE", a)}>Edit</button><button disabled={pending} onClick={() => open("ACQUIRE", a)}>Verify & capitalize</button><button disabled={pending} onClick={() => open("CANCEL", a)}>Cancel draft</button></>}{["ACTIVE", "INACTIVE"].includes(a.status) && <><button disabled={pending} onClick={() => open("DETAILS", a)}>Edit identity</button><button disabled={pending} onClick={() => open(a.status === "ACTIVE" ? "MARK_INACTIVE" : "ACTIVATE", a)}>{a.status === "ACTIVE" ? "Mark inactive" : "Reactivate"}</button>{a.status === "ACTIVE" && <button disabled={pending} onClick={() => open("TRANSFER", a)}>Assign / transfer</button>}<button disabled={pending} onClick={() => open("DEPRECIATE", a)}>Depreciate next month</button><button disabled={pending} onClick={() => open("MAINTENANCE", a)}>Log maintenance</button><button disabled={pending} onClick={() => open("DISPOSE", a)}>Dispose / write off</button></>}{a.payable_id && a.remaining > 0 && data.canPay && <button disabled={pending} onClick={() => open("PAY", a)}>Pay supplier</button>}</div>}</td></tr>)}</tbody></table>{!data.rows.length && <p>No matching assets.</p>}</div><div className="flex justify-between"><p>{data.total} assets · page {data.page}</p><div className="flex gap-4">{data.page > 1 && <Link href={`?${new URLSearchParams({ page: String(data.page - 1), status, q: search })}`}>Previous</Link>}{data.page * 25 < data.total && <Link href={`?${new URLSearchParams({ page: String(data.page + 1), status, q: search })}`}>Next</Link>}</div></div></div>;
}
