"use client";
import Link from "next/link";
import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useLanguage } from "@/components/providers/language-provider";
import { submitAccountingCommand } from "@/modules/finance/accounting/actions";
import type { TeachingEarnings } from "./teaching-queries";
const cls = "mt-1 w-full rounded-lg border bg-background p-3",
  button = "cursor-pointer rounded-lg border px-4 py-2 disabled:opacity-50";
export function TeachingPay({ data }: { data: TeachingEarnings }) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter(),
    [panel, setPanel] = useState<
      | { run: string; teacher: string; name: string; amount: number }
      | "prepare"
      | null
    >(null),
    [uncertain, setUncertain] = useState(false),
    [message, setMessage] = useState(""),
    [pending, start] = useTransition(),
    attempt = useRef({ signature: "", id: "" });
  return (
    <section className="space-y-5">
      <h1 className="text-2xl font-semibold">
        {t("Teaching earnings & payments", "পাঠদানের পাওনা ও পরিশোধ")}
      </h1>
      <p>
        {t(
          "Salary is managed under Staff salary. This page prepares earned teaching-share/retention payments from the existing academy rules. Referral rewards are shown separately in Referrers.",
          "বেতন স্টাফের বেতন পাতায়। এখানে একাডেমির নিয়ম অনুযায়ী পাঠদান / retention পাওনা প্রস্তুত হয়। রেফারেল বোনাস রেফারার পাতায় আলাদা।",
        )}
      </p>
      <div className="flex flex-wrap gap-3">
        <Link className={button} href="/dashboard/finance">
          {t("← Finance", "← হিসাব")}
        </Link>
        <Link className={button} href="/dashboard/finance/payroll">
          {t("Staff salary", "স্টাফের বেতন")}
        </Link>
        <Link className={button} href="/dashboard/referrals">
          {t("Referral rewards", "রেফারেল বোনাস")}
        </Link>
        <button
          className={button}
          disabled={pending || uncertain}
          onClick={() => {
            setPanel("prepare");
            setMessage("");
            attempt.current = { signature: "", id: "" };
          }}
        >
          {t("Prepare a teaching month", "মাসের পাঠদানের পাওনা প্রস্তুত")}
        </button>
      </div>
      {message && (
        <p role="status" className="rounded-xl border p-4">
          {message}
        </p>
      )}
      {panel && (
        <form
          className="space-y-4 rounded-xl border p-5"
          onSubmit={(e) => {
            e.preventDefault();
            const f = new FormData(e.currentTarget);
            let values: Record<string, string>, action: string;
            if (panel === "prepare") {
              const month = String(f.get("month")),
                first = month + "-01",
                last = new Date(
                  Date.UTC(
                    Number(month.slice(0, 4)),
                    Number(month.slice(5, 7)),
                    0,
                  ),
                )
                  .toISOString()
                  .slice(0, 10);
              values = { period_start: first, period_end: last };
              action = "RUN_COMPENSATION";
            } else {
              values = {
                run_id: panel.run,
                teacher_id: panel.teacher,
                payment_account_id: String(f.get("account")),
                advance_offset: "0",
                external_reference: String(f.get("reference") ?? ""),
              };
              action = "SETTLE_COMPENSATION";
            }
            const payload = {
                action,
                values,
                reason: t(
                  "Verified earned teaching work and agreed payment",
                  "অর্জিত পাঠদানের কাজ ও সম্মত পরিশোধ যাচাই করেছি",
                ),
              },
              signature = JSON.stringify(payload);
            if (attempt.current.signature !== signature)
              attempt.current = { signature, id: crypto.randomUUID() };
            start(async () => {
              try {
                const r = await submitAccountingCommand({
                  ...payload,
                  request_id: attempt.current.id,
                });
                setMessage(r.message);
                setUncertain(!!r.uncertain);
                if (r.ok) {
                  setPanel(null);
                  attempt.current = { signature: "", id: "" };
                  router.refresh();
                }
              } catch {
                setUncertain(true);
                setMessage(
                  t(
                    "Result unconfirmed. Inspect the record or retry unchanged input.",
                    "ফল নিশ্চিত নয়। রেকর্ড দেখুন অথবা একই তথ্য আবার পাঠান।",
                  ),
                );
              }
            });
          }}
        >
          <fieldset disabled={pending} className="grid gap-4 sm:grid-cols-2">
            {panel === "prepare" ? (
              <label>
                {t("Teaching month", "পাঠদানের মাস")}
                <input
                  readOnly={uncertain}
                  name="month"
                  type="month"
                  required
                  className={cls}
                />
              </label>
            ) : (
              <>
                <p>
                  {panel.name} · BDT {panel.amount.toFixed(2)}
                  <br />
                  {t(
                    "This action pays the remaining earned amount; it does not create another expense.",
                    "এতে অর্জিত বকেয়া পরিশোধ হবে; নতুন খরচ তৈরি হবে না।",
                  )}
                </p>
                <label>
                  {t("Pay from", "টাকা দেবেন")}
                  <select
                    onChange={(e) => {
                      if (uncertain)
                        e.target.value = String(
                          attempt.current.signature
                            ? JSON.parse(attempt.current.signature).values
                                .payment_account_id
                            : "",
                        );
                    }}
                    name="account"
                    required
                    className={cls}
                  >
                    <option value="">{t("Select…", "নির্বাচন…")}</option>
                    {data.accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  {t("Payment reference", "পরিশোধের নম্বর")}
                  <input
                    readOnly={uncertain}
                    name="reference"
                    maxLength={160}
                    className={cls}
                  />
                </label>
              </>
            )}
          </fieldset>
          <button disabled={pending} className={button}>
            {pending
              ? t("Saving…", "সংরক্ষণ হচ্ছে…")
              : t("Confirm and save", "নিশ্চিত করে সংরক্ষণ")}
          </button>
          <button
            type="button"
            disabled={pending || uncertain}
            className={"ml-3 " + button}
            onClick={() => setPanel(null)}
          >
            {t("Cancel", "বাতিল")}
          </button>
        </form>
      )}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr>
              {["Period", "Teacher", "Earned", "Unpaid", "Action"].map(
                (s, i) => (
                  <th className="p-3 text-left" key={s}>
                    {t(s, ["সময়", "শিক্ষক", "অর্জিত", "বকেয়া", "কাজ"][i])}
                  </th>
                ),
              )}
            </tr>
          </thead>
          <tbody>
            {data.rows.flatMap((r) =>
              r.people.map((p) => (
                <tr key={r.id + p.teacherId} className="border-t">
                  <td className="p-3">
                    {r.period_start} — {r.period_end}
                    <p>{r.run_no}</p>
                  </td>
                  <td>{p.teacher}</td>
                  <td>BDT {p.earned.toFixed(2)}</td>
                  <td>BDT {p.remaining.toFixed(2)}</td>
                  <td>
                    {p.remaining > 0 && r.status === "APPROVED" && (
                      <button
                        className={button}
                        disabled={pending || uncertain}
                        onClick={() => {
                          setPanel({
                            run: r.id,
                            teacher: p.teacherId,
                            name: p.teacher,
                            amount: p.remaining,
                          });
                          setMessage("");
                          attempt.current = { signature: "", id: "" };
                        }}
                      >
                        {t("Pay", "পরিশোধ")}
                      </button>
                    )}
                  </td>
                </tr>
              )),
            )}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-4">
            {t(
              "No teaching month prepared yet.",
              "পাঠদানের মাস এখনো প্রস্তুত হয়নি।",
            )}
          </p>
        )}
      </div>
      <nav className="flex gap-3">
        {data.page > 1 && (
          <Link className={button} href={"?page=" + (data.page - 1)}>
            {t("Previous", "আগের")}
          </Link>
        )}
        {data.page * 25 < data.total && (
          <Link className={button} href={"?page=" + (data.page + 1)}>
            {t("Next", "পরের")}
          </Link>
        )}
      </nav>
    </section>
  );
}
