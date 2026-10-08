"use client";
import Link from "next/link";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useLanguage } from "@/components/providers/language-provider";
import { saveSimpleFinance } from "./actions";
import type { SimpleFinanceData } from "./queries";
const inputClass = "mt-1 w-full rounded-lg border bg-background p-3";
const buttonClass =
  "cursor-pointer rounded-lg border px-4 py-2 hover:bg-muted disabled:cursor-wait disabled:opacity-50";
const money = (n: number) =>
  `BDT ${n.toLocaleString("en-BD", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
export function SimpleFinance({
  data,
  mode = "overview",
  query = "",
}: {
  data: SimpleFinanceData;
  mode?: "overview" | "operations";
  query?: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter(),
    [panel, setPanel] = useState<{
      action: string;
      payable?: SimpleFinanceData["rows"][number];
    } | null>(null),
    [pending, start] = useTransition(),
    [uncertain, setUncertain] = useState(false),
    [message, setMessage] = useState(""),
    [paymentMode, setPaymentMode] = useState("PAID_NOW"),
    [reason, setReason] = useState("RECORDED"),
    [request, setRequest] = useState<{
      request_id: string;
      payload: Record<string, unknown>;
    } | null>(null);
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Dhaka",
  }).format(new Date());
  const labels: Record<string, [string, string]> = {
    EXPENSE: ["Record running expense", "দৈনন্দিন খরচ লিখুন"],
    OTHER_INCOME: ["Record other income", "অন্যান্য আয় লিখুন"],
    OWNER_FUNDS: [
      "Record opening / owner funds",
      "শুরুর / মালিকের দেওয়া টাকা লিখুন",
    ],
    CATEGORY: ["Add missing category", "নতুন খরচের ধরন যোগ করুন"],
    PAY_COST: ["Pay an unpaid cost", "বকেয়া খরচ পরিশোধ করুন"],
  };
  function open(action: string, payable?: SimpleFinanceData["rows"][number]) {
    if (pending || uncertain) return;
    setPanel({ action, payable });
    setMessage("");
    setReason("RECORDED");
    setPaymentMode("PAID_NOW");
    setRequest(null);
  }
  function send(attempt: {
    request_id: string;
    payload: Record<string, unknown>;
  }) {
    start(async () => {
      try {
        const result = await saveSimpleFinance({
          ...attempt.payload,
          request_id: attempt.request_id,
        });
        setMessage(result.message);
        if ("uncertain" in result && result.uncertain) {
          setUncertain(true);
          return;
        }
        setUncertain(false);
        setRequest(null);
        if (result.ok) {
          setPanel(null);
          router.refresh();
        }
      } catch {
        setUncertain(true);
        setMessage(
          t(
            "Result unconfirmed. Confirm the same request.",
            "ফল নিশ্চিত নয়। একই অনুরোধ আবার নিশ্চিত করুন।",
          ),
        );
      }
    });
  }
  function prepare(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!panel || pending || uncertain) return;
    const f = new FormData(e.currentTarget),
      payload: Record<string, unknown> = {
        action: panel.action,
        locale,
        reason:
          reason === "OTHER"
            ? String(f.get("customReason") ?? "")
            : t(
                "Recorded and verified the actual academy transaction",
                "একাডেমির প্রকৃত লেনদেন যাচাই করে লিখেছি",
              ),
        description: String(f.get("description") ?? ""),
      };
    if (panel.action !== "CATEGORY") {
      payload.amount = String(f.get("amount") ?? "");
      payload.reference = String(f.get("reference") ?? "");
      if (f.get("account_id")) payload.account_id = String(f.get("account_id"));
      if (panel.action === "PAY_COST")
        payload.payable_id = panel.payable?.payable_id;
      else payload.date = String(f.get("date") ?? "");
      if (panel.action === "EXPENSE") {
        payload.payment_mode = paymentMode;
        payload.category_id = String(f.get("category_id"));
      }
    }
    const attempt = { request_id: crypto.randomUUID(), payload };
    setRequest(attempt);
    send(attempt);
  }
  const href = (p: number) =>
    `?${new URLSearchParams({ month: data.month.slice(0, 7), q: query, page: String(p) })}`;
  return (
    <section className="space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">
          {mode === "overview"
            ? t(
                "Academy income, expenses & profit",
                "একাডেমির আয়, খরচ ও লাভ-লোকসান",
              )
            : t("Income & running expenses", "আয় ও দৈনন্দিন খরচ")}
        </h1>
        <p className="mt-2 text-muted-foreground">
          {t(
            "Record real activity. Fees, salary and running costs feed the same simple monthly result.",
            "প্রকৃত কাজের হিসাব লিখুন। ফি, বেতন ও দৈনন্দিন খরচ থেকে মাসের ফলাফল তৈরি হয়।",
          )}
        </p>
      </header>
      <nav className="flex flex-wrap gap-2 print:hidden">
        <Link className={buttonClass} href="/dashboard/finance">
          {t("Monthly result", "মাসের ফলাফল")}
        </Link>
        <Link className={buttonClass} href="/dashboard/finance/operations">
          {t("Income & expenses", "আয় ও খরচ")}
        </Link>
        {data.links.billing && (
          <Link className={buttonClass} href="/dashboard/finance/billing">
            {t("Student fees & dues", "শিক্ষার্থীর ফি ও বকেয়া")}
          </Link>
        )}
        {data.links.salary && (
          <Link className={buttonClass} href="/dashboard/finance/payroll">
            {t("Staff salary", "স্টাফের বেতন")}
          </Link>
        )}
        {data.links.referrals && (
          <Link className={buttonClass} href="/dashboard/referrals">
            {t("Referral earnings", "রেফারেল পাওনা")}
          </Link>
        )}
        <Link className={buttonClass} href="/dashboard/help/finance">
          {t("How to use finance", "হিসাব পরিচালনার নিয়ম")}
        </Link>
      </nav>
      <form className="flex flex-wrap items-end gap-3 print:hidden">
        <label>
          {t("Month", "মাস")}
          <input
            name="month"
            type="month"
            defaultValue={data.month.slice(0, 7)}
            max={today.slice(0, 7)}
            className={inputClass}
          />
        </label>
        {mode === "operations" && (
          <label>
            {t("Search description / category", "বিবরণ / খরচের ধরন খুঁজুন")}
            <input
              name="q"
              defaultValue={query}
              maxLength={160}
              className={inputClass}
            />
          </label>
        )}
        <button className={buttonClass}>{t("Show", "দেখুন")}</button>
      </form>
      {mode === "overview" && (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              [t("Income after fee reductions", "ছাড়ের পর আয়"), data.netIncome],
              [
                t(
                  "Running costs & earned staff pay",
                  "দৈনন্দিন খরচ ও অর্জিত পারিশ্রমিক",
                ),
                data.expenses,
              ],
              [
                data.profit >= 0
                  ? t("Operating profit", "পরিচালনায় লাভ")
                  : t("Operating loss", "পরিচালনায় লোকসান"),
                Math.abs(data.profit),
              ],
              [
                t("Discounts / fee reductions", "ছাড় / ফি হ্রাস"),
                data.reductions,
              ],
            ].map(([label, n]) => (
              <div
                key={String(label)}
                className="rounded-xl border bg-card p-5"
              >
                <p className="text-sm text-muted-foreground">{label}</p>
                <p className="mt-2 text-xl font-semibold">{money(Number(n))}</p>
              </div>
            ))}
          </div>
          <p className="text-sm text-muted-foreground">
            {t(
              "Income is based on issued fees and other operating income. Costs include recorded unpaid expenses and earned salary/rewards. Paying their dues later does not count another cost. This is the academy operating result; assets and depreciation are handled outside the app.",
              "আয় নির্ধারিত ফি ও অন্যান্য পরিচালন আয় অনুযায়ী। খরচে রেকর্ড করা বকেয়া খরচ ও অর্জিত বেতন/বোনাস থাকে। পরে টাকা দিলে একই খরচ দ্বিতীয়বার গণনা হয় না। এটি পরিচালনার ফলাফল; সম্পদ ও অবচয় অ্যাপের বাইরে হিসাব করবেন।",
            )}
          </p>
          <section className="rounded-xl border p-5">
            <h2 className="font-semibold">
              {t(
                "Actual money during this month",
                "এই মাসে বাস্তব টাকা গ্রহণ / পরিশোধ",
              )}
            </h2>
            <div className="mt-3 grid gap-3 sm:grid-cols-3">
              {[
                [
                  t(
                    "Collected, less student refunds",
                    "আদায়, শিক্ষার্থীকে ফেরত বাদ",
                  ),
                  data.collected,
                ],
                [t("Operating payments", "পরিচালন কাজে পরিশোধ"), data.paid],
                [
                  t("Collection less payments", "আদায় থেকে পরিশোধ বাদ"),
                  data.cashResult,
                ],
              ].map(([label, n]) => (
                <div key={String(label)}>
                  <p>{label}</p>
                  <strong>{money(Number(n))}</strong>
                </div>
              ))}
            </div>
            <p className="mt-3 text-sm text-muted-foreground">
              {t(
                "Money movement is separate from profit. Owner funding and internal transfers are not income.",
                "টাকার আসা-যাওয়া লাভ থেকে আলাদা। মালিকের দেওয়া টাকা বা নিজের অ্যাকাউন্টে স্থানান্তর আয় নয়।",
              )}
            </p>
          </section>
          <section className="grid gap-3 sm:grid-cols-3">
            <div className="rounded-xl border p-4">
              <p>{t("Current student dues", "বর্তমান শিক্ষার্থী বকেয়া")}</p>
              <strong>{money(data.studentDue)}</strong>
              <Link
                className="mt-2 block underline"
                href="/dashboard/finance/receivables"
              >
                {t("Follow up dues", "বকেয়ার খোঁজ নিন")}
              </Link>
            </div>
            <div className="rounded-xl border p-4">
              <p>
                {t(
                  "Current staff / operating amounts unpaid",
                  "স্টাফ / পরিচালনায় বর্তমান অপরিশোধিত টাকা",
                )}
              </p>
              <strong>{money(data.costDue)}</strong>
            </div>
            <div className="rounded-xl border p-4">
              <p>
                {t(
                  "Recorded main cash / bank / mobile money now",
                  "মূল নগদ / ব্যাংক / মোবাইলে এখন রেকর্ড করা টাকা",
                )}
              </p>
              <strong>
                {money(data.accounts.reduce((s, a) => s + a.balance, 0))}
              </strong>
            </div>
          </section>
          <details className="rounded-xl border p-4">
            <summary className="cursor-pointer">
              {t("Recorded payment sources", "টাকা রাখার রেকর্ড করা জায়গা")}
            </summary>
            {data.accounts.map((a) => (
              <p key={a.id} className="mt-2">
                {a.name}: {money(a.balance)}
              </p>
            ))}
          </details>
        </>
      )}
      {mode === "operations" && (
        <>
          <div className="flex flex-wrap gap-3">
            {data.canExpense && (
              <button
                className={buttonClass}
                disabled={pending || uncertain}
                onClick={() => open("EXPENSE")}
              >
                {t(...labels.EXPENSE)}
              </button>
            )}
            {data.canIncome &&
              ["OTHER_INCOME", "OWNER_FUNDS"].map((cmd) => (
                <button
                  key={cmd}
                  className={buttonClass}
                  disabled={pending || uncertain}
                  onClick={() => open(cmd)}
                >
                  {t(...labels[cmd])}
                </button>
              ))}
            {data.canExpense && (
              <button
                className={buttonClass}
                disabled={pending || uncertain}
                onClick={() => open("CATEGORY")}
              >
                {t(...labels.CATEGORY)}
              </button>
            )}
          </div>
          {message && (
            <p role="status" className="rounded-xl border p-4">
              {message}
            </p>
          )}
          {panel && (
            <form
              data-editor
              data-busy={pending ? "true" : "false"}
              key={panel.action + panel.payable?.id}
              onSubmit={prepare}
              className="space-y-4 rounded-xl border p-5"
            >
              <fieldset disabled={pending} className="contents">
                <h2 className="font-semibold">{t(...labels[panel.action])}</h2>
                <fieldset
                  disabled={pending || uncertain}
                  className="grid gap-4 sm:grid-cols-2"
                >
                  {panel.action === "CATEGORY" ? (
                    <label>
                      {t("Category name", "খরচের ধরন")}
                      <input
                        name="description"
                        required
                        minLength={2}
                        maxLength={120}
                        className={inputClass}
                      />
                    </label>
                  ) : (
                    <>
                      <label>
                        {t("Amount (BDT)", "টাকার পরিমাণ (BDT)")}
                        <input
                          name="amount"
                          required
                          type="number"
                          min=".01"
                          step=".01"
                          max={panel.payable?.remaining}
                          className={inputClass}
                        />
                      </label>
                      {panel.action !== "PAY_COST" && (
                        <label>
                          {t("Actual date", "প্রকৃত তারিখ")}
                          <input
                            required
                            name="date"
                            type="date"
                            defaultValue={today}
                            max={today}
                            className={inputClass}
                          />
                        </label>
                      )}
                      {panel.action === "EXPENSE" && (
                        <>
                          <label>
                            {t("Expense category", "খরচের ধরন")}
                            <select
                              name="category_id"
                              required
                              className={inputClass}
                            >
                              <option value="">
                                {t("Select…", "নির্বাচন…")}
                              </option>
                              {data.categories.map((c) => (
                                <option key={c.id} value={c.id}>
                                  {c.name}
                                </option>
                              ))}
                            </select>
                          </label>
                          <label>
                            {t("Payment status", "টাকা দেওয়া হয়েছে?")}
                            <select
                              value={paymentMode}
                              onChange={(e) => setPaymentMode(e.target.value)}
                              className={inputClass}
                            >
                              <option value="PAID_NOW">
                                {t("Paid now", "এখন পরিশোধ")}
                              </option>
                              <option value="ON_ACCOUNT">
                                {t(
                                  "Pay later — keep due",
                                  "পরে পরিশোধ — বকেয়া থাকবে",
                                )}
                              </option>
                            </select>
                          </label>
                        </>
                      )}
                      {(panel.action !== "EXPENSE" ||
                        paymentMode === "PAID_NOW") && (
                        <label>
                          {t(
                            "Money source / destination",
                            "টাকা দেওয়া / রাখার জায়গা",
                          )}
                          <select
                            name="account_id"
                            required
                            className={inputClass}
                          >
                            <option value="">
                              {t("Select…", "নির্বাচন…")}
                            </option>
                            {data.accounts.map((a) => (
                              <option key={a.id} value={a.id}>
                                {a.name} · {money(a.balance)}
                              </option>
                            ))}
                          </select>
                        </label>
                      )}
                      {panel.action !== "PAY_COST" && (
                        <label>
                          {t(
                            panel.action === "EXPENSE"
                              ? "Details (optional; category used if blank)"
                              : "Income / funding details",
                            panel.action === "EXPENSE"
                              ? "বিবরণ (ঐচ্ছিক; ফাঁকা হলে খরচের ধরন)"
                              : "আয় / দেওয়া টাকার বিবরণ",
                          )}
                          <input
                            name="description"
                            required={panel.action !== "EXPENSE"}
                            maxLength={300}
                            defaultValue={
                              panel.action === "OWNER_FUNDS"
                                ? t(
                                    "Owner startup / opening funds",
                                    "মালিকের শুরুর টাকা",
                                  )
                                : ""
                            }
                            className={inputClass}
                          />
                        </label>
                      )}
                      <label>
                        {t(
                          "Receipt / transaction reference (optional)",
                          "রসিদ / লেনদেনের নম্বর (ঐচ্ছিক)",
                        )}
                        <input
                          name="reference"
                          maxLength={160}
                          className={inputClass}
                        />
                      </label>
                    </>
                  )}
                  <label>
                    {t("Reason", "কারণ")}
                    <select
                      value={reason}
                      onChange={(e) => setReason(e.target.value)}
                      className={inputClass}
                    >
                      <option value="RECORDED">
                        {t(
                          "Verified the actual transaction",
                          "প্রকৃত লেনদেন যাচাই করেছি",
                        )}
                      </option>
                      <option value="OTHER">
                        {t("Other — write a note", "অন্য কারণ — লিখুন")}
                      </option>
                    </select>
                  </label>
                  {reason === "OTHER" && (
                    <label>
                      {t("Note", "সংক্ষিপ্ত কারণ")}
                      <input
                        name="customReason"
                        required
                        minLength={5}
                        maxLength={1000}
                        className={inputClass}
                      />
                    </label>
                  )}
                </fieldset>
                <p className="text-sm text-muted-foreground">
                  {t(
                    "Student fee collections belong in Student fees & dues. Do not record salary twice as a running expense. Owner/opening funds are not profit.",
                    "শিক্ষার্থীর টাকা ফি ও বকেয়া পাতায় লিখুন। বেতনকে আবার দৈনন্দিন খরচ হিসেবে লিখবেন না। মালিকের দেওয়া টাকা লাভ নয়।",
                  )}
                </p>
                {uncertain ? (
                  <button
                    type="button"
                    disabled={pending}
                    className={buttonClass}
                    onClick={() => request && send(request)}
                  >
                    {pending
                      ? t("Confirming…", "নিশ্চিত হচ্ছে…")
                      : t(
                          "Confirm the previous request",
                          "আগের অনুরোধ নিশ্চিত করুন",
                        )}
                  </button>
                ) : (
                  <button disabled={pending} className={buttonClass}>
                    {pending
                      ? t("Saving…", "সংরক্ষণ হচ্ছে…")
                      : t("Save", "সংরক্ষণ")}
                  </button>
                )}
                <button
                  type="button"
                  disabled={pending || uncertain}
                  className={"ml-3 " + buttonClass}
                  onClick={() => setPanel(null)}
                >
                  {t("Cancel", "বাতিল")}
                </button>
              </fieldset>
            </form>
          )}
          <div className="overflow-x-auto rounded-xl border">
            <table className="w-full text-sm">
              <thead>
                <tr>
                  {[
                    "Date / type",
                    "Description",
                    "Amount",
                    "Unpaid",
                    "Action",
                  ].map((s, i) => (
                    <th className="p-3 text-left" key={s}>
                      {t(
                        s,
                        ["তারিখ / ধরন", "বিবরণ", "টাকা", "বকেয়া", "কাজ"][i],
                      )}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((r) => (
                  <tr className="border-t" key={r.id}>
                    <td className="p-3">
                      {r.day}
                      <p>{t(...(labels[r.kind] ?? [r.kind, r.kind]))}</p>
                    </td>
                    <td>
                      {r.description}
                      <p className="text-muted-foreground">{r.category}</p>
                    </td>
                    <td>{money(r.amount)}</td>
                    <td>{money(r.remaining)}</td>
                    <td>
                      {r.remaining > 0 && r.payable_id && data.canPay && (
                        <button
                          className={buttonClass}
                          disabled={pending || uncertain}
                          onClick={() => open("PAY_COST", r)}
                        >
                          {t("Pay now", "এখন পরিশোধ")}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {!data.rows.length && (
              <p className="p-5">
                {t(
                  "No matching income/expense entries this month. Salary and student fee records appear in their own registers.",
                  "এই মাসে মিল পাওয়া যায়নি। বেতন ও শিক্ষার্থীর ফি তাদের নিজস্ব তালিকায় দেখুন।",
                )}
              </p>
            )}
          </div>
          <nav className="flex items-center gap-3">
            <Link
              aria-disabled={data.page === 1}
              href={href(Math.max(1, data.page - 1))}
              className={buttonClass}
            >
              {t("Previous", "আগের")}
            </Link>
            <span>
              {data.page} · {data.total}
            </span>
            {data.page * 25 < data.total && (
              <Link href={href(data.page + 1)} className={buttonClass}>
                {t("Next", "পরের")}
              </Link>
            )}
          </nav>
        </>
      )}
    </section>
  );
}
