"use client";
import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/erp/status-badge";
import { useLanguage } from "@/components/providers/language-provider";
import { runAcademicCommand } from "@/modules/academics/operations/actions";
import type {
  AcademicCommand,
  SessionWorkspace,
} from "@/modules/academics/operations/schema";
export function ClassStudentAttendance({
  data,
  onSaved,
}: {
  data: SessionWorkspace;
  onSaved: () => void;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter();
  const latest = data.submissions[0];
  const [rows, setRows] = useState(
      data.roster.map((r) => ({ ...r, status: r.status ?? "" })),
    ),
    [message, setMessage] = useState(""),
    [pending, start] = useTransition(),
    [uncertain, setUncertain] = useState(false),
    [dirty, setDirty] = useState(false);
  const request = useRef<AcademicCommand | null>(null);
  const labels = {
    PRESENT: t("Present", "উপস্থিত"),
    ABSENT: t("Absent", "অনুপস্থিত"),
    LATE: t("Late", "দেরিতে"),
    EXCUSED: t("Excused", "অনুমোদিত ছুটি"),
  };
  function send(payload: AcademicCommand) {
    start(async () => {
      try {
        const r = await runAcademicCommand(payload);
        setMessage(
          r.ok
            ? t("Student attendance saved.", "শিক্ষার্থীর উপস্থিতি সংরক্ষিত।")
            : r.message,
        );
        if (r.ok) {
          request.current = null;
          setDirty(false);
          setUncertain(false);
          onSaved();
          router.refresh();
        } else
          setUncertain(/network|fetch|timeout|unconfirmed/i.test(r.message));
      } catch {
        setUncertain(true);
        setMessage(
          t(
            "Result unconfirmed. Confirm the same request before changing data.",
            "ফল নিশ্চিত নয়। তথ্য বদলানোর আগে একই অনুরোধ নিশ্চিত করুন।",
          ),
        );
      }
    });
  }
  const editable =
    !latest || ["DRAFT", "REJECTED", "APPROVED"].includes(latest.status);
  return (
    <form
      className="space-y-3"
      data-editor
      data-dirty={dirty ? "true" : "false"}
      data-busy={pending || uncertain ? "true" : "false"}
      onSubmit={(e) => {
        e.preventDefault();
        const payload: AcademicCommand = {
          action: "SAVE_ATTENDANCE",
          request_id: crypto.randomUUID(),
          session_id: data.session.id,
          base_id: latest?.id,
          reason: t(
            "Recorded each student attendance in the assigned class",
            "নির্ধারিত ক্লাসে প্রত্যেক শিক্ষার্থীর উপস্থিতি নিয়েছি",
          ),
          entries: rows.map((r) => ({
            enrollment_id: r.enrollment_id,
            status: r.status as "PRESENT" | "ABSENT" | "LATE" | "EXCUSED",
            note: r.note ?? "",
          })),
        };
        request.current = payload;
        send(payload);
      }}
    >
      <p className="text-sm">
        {t(
          "Select every student. No one is marked present automatically. Save now; final submission happens with the class report.",
          "প্রত্যেক শিক্ষার্থী নির্বাচন করুন। কাউকে স্বয়ংক্রিয়ভাবে উপস্থিত ধরা হবে না। এখন সংরক্ষণ করুন; ক্লাস রিপোর্টের সঙ্গে জমা হবে।",
        )}
      </p>
      <fieldset
        disabled={pending || uncertain || !editable}
        className="space-y-2"
      >
        {rows.map((r, i) => (
          <div
            key={r.enrollment_id}
            className="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-3"
          >
            <div>
              <p className="font-medium">{r.name}</p>
              <p className="text-xs text-muted-foreground">{r.number}</p>
            </div>
            <label className="flex items-center gap-2">
              <span className="sr-only">
                {r.name} {t("attendance", "উপস্থিতি")}
              </span>
              <select
                required
                value={r.status}
                className="min-h-11 rounded-lg border bg-background p-2"
                onChange={(e) => {
                  setDirty(true);
                  setRows((old) =>
                    old.map((x, n) =>
                      n === i ? { ...x, status: e.target.value } : x,
                    ),
                  );
                }}
              >
                <option value="">{t("Choose status", "নির্বাচন করুন")}</option>
                {Object.entries(labels).map(([id, label]) => (
                  <option key={id} value={id}>
                    {label}
                  </option>
                ))}
              </select>
              {r.status && (
                <StatusBadge
                  value={r.status}
                  label={labels[r.status as keyof typeof labels]}
                />
              )}
            </label>
          </div>
        ))}
      </fieldset>
      {!rows.length && (
        <p role="status">
          {t(
            "No enrolled students. Ask admin to check batch placement before reporting this class.",
            "কোনো ভর্তি শিক্ষার্থী নেই। এই ক্লাসের রিপোর্টের আগে admin-কে ব্যাচে enrollment যাচাই করতে বলুন।",
          )}
        </p>
      )}
      {message && (
        <p role="status" className="rounded-lg border p-3">
          {message}
        </p>
      )}
      {uncertain ? (
        <Button
          type="button"
          loading={pending}
          onClick={() => request.current && send(request.current)}
        >
          {t("Confirm previous save", "আগের সংরক্ষণ নিশ্চিত করুন")}
        </Button>
      ) : (
        editable &&
        rows.length > 0 && (
          <Button type="submit" loading={pending}>
            {t("Save attendance & continue", "উপস্থিতি সংরক্ষণ করে এগিয়ে যান")}
          </Button>
        )
      )}
    </form>
  );
}
