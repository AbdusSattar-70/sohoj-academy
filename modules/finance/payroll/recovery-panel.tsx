"use client";
import { useRef, useState, useTransition } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { recoverPayroll } from "./recovery-actions";
import type { PayrollData } from "./queries";
export function PayrollRecovery({ data }: { data: PayrollData }) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [mode, setMode] = useState<"RECOVER_TERMS" | "ADJUST" | null>(null),
    [message, setMessage] = useState("");
  const [pending, start] = useTransition();
  const key = useRef({ signature: "", id: "" });
  const cls = "mt-1 w-full rounded-lg border bg-background p-3";
  if (!data.manager) return null;
  return (
    <section className="space-y-4 rounded-xl border p-4">
      <div className="flex flex-wrap gap-3">
        <button
          disabled={pending}
          className="rounded-lg border p-3"
          onClick={() =>
            setMode(mode === "RECOVER_TERMS" ? null : "RECOVER_TERMS")
          }
        >
          {t(
            "Record historical monthly agreement",
            "পুরোনো মাসের সম্মত শর্ত রেকর্ড",
          )}
        </button>
        <button
          disabled={pending}
          className="rounded-lg border p-3"
          onClick={() => setMode(mode === "ADJUST" ? null : "ADJUST")}
        >
          {t("Correct posted salary", "পোস্ট করা বেতন সংশোধন")}
        </button>
      </div>
      {message && <p role="status">{message}</p>}
      {mode && (
        <form
          data-editor
          data-busy={pending ? "true" : "false"}
          key={mode}
          className="grid gap-4 sm:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            const f = new FormData(e.currentTarget);
            const values =
              mode === "ADJUST"
                ? {
                    action: mode,
                    id: f.get("id"),
                    amount: Number(f.get("amount")),
                    reason: f.get("reason"),
                  }
                : {
                    action: mode,
                    staff_id: f.get("staff_id"),
                    month: `${f.get("month")}-01`,
                    effective_from: f.get("effective_from"),
                    model: f.get("model"),
                    monthly_base: Number(f.get("monthly_base")),
                    hourly_rate: Number(f.get("hourly_rate")),
                    pay_day: Number(f.get("pay_day")),
                    reason: f.get("reason"),
                  };
            const signature = JSON.stringify(values);
            if (key.current.signature !== signature)
              key.current = { signature, id: crypto.randomUUID() };
            start(async () => {
              const r = await recoverPayroll({
                ...values,
                request_id: key.current.id,
              });
              setMessage(r.message);
              if (r.ok) {
                setMode(null);
                key.current = { signature: "", id: "" };
              }
            });
          }}
        >
          <fieldset disabled={pending} className="contents">
            <p className="text-sm sm:col-span-2">
              {mode === "ADJUST"
                ? t(
                    "Positive adds agreed earnings; negative reduces unspent salary payable. Original payslip remains. Corrections post today, never rewrite a closed month. This is not a tax or loan deduction.",
                    "ধনাত্মক অঙ্ক সম্মত আয় বাড়াবে; ঋণাত্মক অঙ্ক অপরিশোধিত বেতন কমাবে। মূল স্লিপ থাকবে। আজকের খোলা মাসে সংশোধন পোস্ট হয়; কর বা ঋণের কর্তন এখানে নয়।",
                  )
                : t(
                    "Record evidence for one completed, unposted month. Current terms do not change. Confirm actual agreed terms before previewing payroll.",
                    "একটি শেষ হওয়া, এখনো পোস্ট না করা মাসের প্রমাণ রেকর্ড করুন। বর্তমান শর্ত বদলাবে না। সম্মত শর্ত যাচাই করে এরপর বেতন প্রস্তুত করুন।",
                  )}
            </p>
            {mode === "ADJUST" ? (
              <>
                <label>
                  {t("Posted payslip", "পোস্ট করা স্লিপ")}
                  <select className={cls} name="id" required disabled={pending}>
                    <option value="">{t("Choose…", "নির্বাচন…")}</option>
                    {data.records.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.payroll_no} · {r.snapshot.name} ·{" "}
                        {r.month.slice(0, 7)} · BDT {r.net}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  {t(
                    "Signed correction (BDT)",
                    "ধনাত্মক / ঋণাত্মক সংশোধন (টাকা)",
                  )}
                  <input
                    className={cls}
                    name="amount"
                    type="number"
                    step="0.01"
                    required
                    disabled={pending}
                  />
                </label>
              </>
            ) : (
              <>
                <label>
                  {t("Staff", "কর্মী")}
                  <select
                    name="staff_id"
                    className={cls}
                    required
                    disabled={pending}
                  >
                    <option value="">{t("Choose…", "নির্বাচন…")}</option>
                    {data.people.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  {t("Completed month", "শেষ হওয়া মাস")}
                  <input
                    className={cls}
                    name="month"
                    type="month"
                    required
                    disabled={pending}
                  />
                </label>
                <label>
                  {t("Model", "বেতনের ভিত্তি")}
                  <select className={cls} name="model" disabled={pending}>
                    <option value="FIXED">{t("Fixed", "স্থির")}</option>
                    <option value="HOURLY">{t("Hourly", "ঘণ্টা")}</option>
                    <option value="HYBRID">
                      {t("Hybrid", "স্থির ও অন্যান্য")}
                    </option>
                  </select>
                </label>
                <label>
                  {t("Agreement effective from", "শর্ত কার্যকরের তারিখ")}
                  <input
                    className={cls}
                    name="effective_from"
                    type="date"
                    required
                    disabled={pending}
                  />
                </label>
                <label>
                  {t("Monthly base", "মাসিক মূল বেতন")}
                  <input
                    className={cls}
                    name="monthly_base"
                    type="number"
                    min="0"
                    step="0.01"
                    defaultValue="0"
                    required
                    disabled={pending}
                  />
                </label>
                <label>
                  {t("Hourly rate", "ঘণ্টার হার")}
                  <input
                    className={cls}
                    name="hourly_rate"
                    type="number"
                    min="0"
                    step="0.01"
                    defaultValue="0"
                    required
                    disabled={pending}
                  />
                </label>
                <label>
                  {t("Pay day (1–28)", "পরিশোধের দিন (১–২৮)")}
                  <input
                    className={cls}
                    name="pay_day"
                    type="number"
                    min="1"
                    max="28"
                    defaultValue="10"
                    required
                    disabled={pending}
                  />
                </label>
              </>
            )}
            <label className="sm:col-span-2">
              {t("Evidence / explanation", "প্রমাণ ও ব্যাখ্যা")}
              <textarea
                name="reason"
                className={cls}
                minLength={5}
                maxLength={1000}
                required
                disabled={pending}
              />
            </label>
            <div className="flex gap-3 sm:col-span-2">
              <button
                disabled={pending}
                className="rounded-lg bg-primary p-3 text-primary-foreground"
              >
                {pending
                  ? t("Saving…", "সংরক্ষণ হচ্ছে…")
                  : t("Save verified evidence", "যাচাই করা প্রমাণ সংরক্ষণ")}
              </button>
              <button
                type="button"
                disabled={pending}
                onClick={() => setMode(null)}
              >
                {t("Cancel", "বাতিল")}
              </button>
            </div>
          </fieldset>
        </form>
      )}
    </section>
  );
}
