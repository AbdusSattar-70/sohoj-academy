"use client";

import { useState } from "react";
import type { FinanceAccountingWorkspaceData } from "./queries";

function money(value: number) {
  return new Intl.NumberFormat("en-BD", { style: "currency", currency: "BDT", maximumFractionDigits: 2 }).format(value);
}

export function FinanceAccountingWorkspace({ initialData }: { initialData: FinanceAccountingWorkspaceData }) {
  const [data] = useState(initialData);

  return (
    <div className="space-y-6">
      <section className="grid gap-4 md:grid-cols-4">
        <Summary title="Cash / Bank" value={money(data.accounts.filter((x) => ["CASH", "BANK", "MOBILE_BANK"].includes(x.subtype)).reduce((s, x) => s + x.balance, 0))} />
        <Summary title="Student Receivables" value={money(data.accounts.find((x) => x.subtype === "STUDENT_RECEIVABLE")?.balance ?? 0)} />
        <Summary title="Teacher Payable" value={money(data.accounts.find((x) => x.subtype === "TEACHER_PAYABLE")?.balance ?? 0)} />
        <Summary title="Open Advances" value={money(data.advances.filter((x) => !["SETTLED", "REFUNDED", "REJECTED"].includes(x.status)).reduce((s, x) => s + x.balance, 0))} />
      </section>

      <section className="rounded-2xl border bg-card p-5">
        <h2 className="text-lg font-semibold">Chart of Accounts</h2>
        <p className="mt-1 text-sm text-muted-foreground">Controlled financial accounts and current posted balances.</p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-sm">
            <thead><tr className="border-b text-left"><th className="py-2">Code</th><th>Name</th><th>Type</th><th className="text-right">Balance</th></tr></thead>
            <tbody>{data.accounts.map((account) => <tr key={account.id} className="border-b last:border-0"><td className="py-2 font-mono">{account.code}</td><td>{account.name}</td><td>{account.accountType}</td><td className="text-right">{money(account.balance)}</td></tr>)}</tbody>
          </table>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <Panel title="Payables" description="Teacher, vendor and staff obligations.">
          {data.payables.map((item) => <Row key={item.id} title={item.number} detail={item.beneficiary} value={money(item.amount)} status={item.status} />)}
          {!data.payables.length && <Empty />}
        </Panel>
        <Panel title="Advances" description="Advance balances stay separate from final expenses.">
          {data.advances.map((item) => <Row key={item.id} title={item.number} detail={item.beneficiary + " · " + item.purpose} value={money(item.requestedAmount)} status={item.status} />)}
          {!data.advances.length && <Empty />}
        </Panel>
        <Panel title="Expenses" description="Approval and reconciliation status.">
          {data.expenses.slice(0, 10).map((item) => <Row key={item.id} title={item.number} detail={item.description} value={money(item.amount)} status={item.status} />)}
          {!data.expenses.length && <Empty />}
        </Panel>
        <Panel title="Teacher Compensation" description="Policy-based earnings, approval and settlement runs.">
          {data.compensation.map((item) => <Row key={item.id} title={item.runNo} detail={item.from + " → " + item.to} value={money(item.total)} status={item.status} />)}
          {!data.compensation.length && <Empty />}
        </Panel>
      </section>
    </div>
  );
}

function Summary({ title, value }: { title: string; value: string }) {
  return <div className="rounded-2xl border bg-card p-5"><p className="text-sm text-muted-foreground">{title}</p><p className="mt-2 text-xl font-semibold">{value}</p></div>;
}

function Panel({ title, description, children }: { title: string; description: string; children: React.ReactNode }) {
  return <section className="rounded-2xl border bg-card p-5"><h2 className="text-lg font-semibold">{title}</h2><p className="text-sm text-muted-foreground">{description}</p><div className="mt-4 space-y-2">{children}</div></section>;
}

function Row({ title, detail, value, status }: { title: string; detail: string; value: string; status: string }) {
  return <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border p-3"><div><p className="font-medium">{title}</p><p className="text-sm text-muted-foreground">{detail}</p></div><div className="text-right"><p className="font-semibold">{value}</p><p className="text-xs text-muted-foreground">{status}</p></div></div>;
}

function Empty() {
  return <p className="rounded-xl border border-dashed p-4 text-sm text-muted-foreground">No records yet.</p>;
}
