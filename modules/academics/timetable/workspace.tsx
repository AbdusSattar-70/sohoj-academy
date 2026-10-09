"use client";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { PlanningForm, weekdays, weekdaysBn } from "../planning/form";
import type { PlanningData } from "../planning/schema";
import { saveAcademicPlan } from "../planning/actions";
import { TimetableEditor } from "./editor";
import { nextClassDates } from "./dates";
export function TimetableWorkspace({
  data,
  today,
}: {
  data: PlanningData;
  today: string;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter();
  const [panel, setPanel] = useState<Record<string, unknown> | null>(null),
    [notice, setNotice] = useState(""),
    [busy, setBusy] = useState(false),
    [retry, setRetry] = useState<Record<string, unknown> | null>(null);
  async function extend(payload: Record<string, unknown>) {
    setBusy(true);
    try {
      const r = await saveAcademicPlan(payload);
      setNotice(r.message);
      if (r.ok) {
        setRetry(null);
        router.refresh();
      } else setRetry(r.uncertain ? payload : null);
    } catch {
      setRetry(payload);
      setNotice(
        t(
          "Result unconfirmed. Retry the same request.",
          "ফল নিশ্চিত নয়। একই অনুরোধ আবার নিশ্চিত করুন।",
        ),
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="space-y-5" data-editor data-busy={busy || !!retry}>
      <header>
        <h1 className="text-2xl font-semibold">
          {t("Weekly timetable", "সাপ্তাহিক রুটিন")}
        </h1>
        <p className="mt-2 text-muted-foreground">
          {t(
            "Choose a batch, add class rows and preview. One save creates the routine and its next four weeks of dated classes.",
            "ব্যাচ নির্বাচন করুন, ক্লাসের সারি যোগ করে preview দেখুন। একবার সংরক্ষণে রুটিন ও আগামী চার সপ্তাহের তারিখভিত্তিক ক্লাস তৈরি হবে।",
          )}
        </p>
      </header>
      <TimetableEditor data={data} today={today} />
      {notice && <p role="status">{notice}</p>}
      {busy && (
        <p role="status">{t("Creating classes…", "ক্লাস তৈরি হচ্ছে…")}</p>
      )}
      {retry && (
        <Button disabled={busy} onClick={() => extend(retry)}>
          {t("Confirm same request", "একই অনুরোধ নিশ্চিত করুন")}
        </Button>
      )}
      {panel && (
        <PlanningForm
          action="RETIRE"
          initial={panel}
          data={data}
          onDone={(message) => {
            setPanel(null);
            if (message) setNotice(message);
          }}
        />
      )}
      <h2 className="font-semibold">
        {t("Saved class rows", "সংরক্ষিত ক্লাসের সারি")}
      </h2>
      <p className="text-sm text-muted-foreground">
        {t(
          "Extend when more classes are needed. For a one-day change, open the class calendar. Retiring stops further generation; already created classes stay unchanged.",
          "আরও ক্লাস প্রয়োজন হলে সময় বাড়ান। একদিনের পরিবর্তনের জন্য ক্লাস ক্যালেন্ডার খুলুন। রুটিন বন্ধ করলে নতুন ক্লাস তৈরি বন্ধ হবে; আগের তৈরি ক্লাস বদলাবে না।",
        )}
      </p>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full min-w-[650px] text-left text-sm">
          <thead>
            <tr>
              {[
                t("Class / teacher / room", "ক্লাস / শিক্ষক / কক্ষ"),
                t("Day / time / dates", "দিন / সময় / তারিখ"),
                t("Actions", "কাজ"),
              ].map((x) => (
                <th key={x} className="p-3">
                  {x}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => {
              const d = nextClassDates(r, today);
              return (
                <tr key={String(r.id)} className="border-t">
                  <td className="p-3">
                    {String(r.label)}
                    <p>
                      {String(r.teacher)} · {String(r.room)}
                    </p>
                  </td>
                  <td className="p-3">
                    {t(
                      weekdays[Number(r.weekday)],
                      weekdaysBn[Number(r.weekday)],
                    )}{" "}
                    · {String(r.start_time).slice(0, 5)}–
                    {String(r.end_time).slice(0, 5)}
                    <p>
                      {String(r.starts_on)} — {String(r.ends_on)}
                    </p>
                    <p>
                      {t("Classes through", "ক্লাস তৈরি আছে")}{" "}
                      {String(r.last_generated_on ?? "—")}
                    </p>
                  </td>
                  <td className="space-y-2 p-3">
                    {r.retired_at ? (
                      t("Retired", "বন্ধ")
                    ) : (
                      <>
                        <Button
                          variant="outline"
                          disabled={busy || !!retry || d.from > d.through}
                          onClick={() => {
                            if (
                              window.confirm(
                                t(
                                  `Create classes ${d.from}–${d.through}?`,
                                  `ক্লাস তৈরি করুন ${d.from}–${d.through}?`,
                                ),
                              )
                            )
                              extend({
                                action: "GENERATE",
                                routine_id: r.id,
                                starts_on: d.from,
                                ends_on: d.through,
                                skip_past: true,
                                planned_scope: "Scheduled subject teaching",
                                request_id: crypto.randomUUID(),
                                reason: "Extend agreed weekly timetable",
                                locale,
                              });
                          }}
                        >
                          {t(
                            "Create next four weeks",
                            "পরবর্তী চার সপ্তাহ তৈরি",
                          )}
                        </Button>
                        <Button
                          variant="outline"
                          disabled={busy || !!retry}
                          onClick={() => setPanel({ routine_id: r.id })}
                        >
                          {t("Stop future generation", "নতুন ক্লাস তৈরি বন্ধ")}
                        </Button>
                      </>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {!data.rows.length && (
          <p className="p-4">
            {t(
              "No routine yet. Use Create weekly timetable above.",
              "রুটিন নেই। উপরের সাপ্তাহিক রুটিন তৈরি করুন বোতাম চাপুন।",
            )}
          </p>
        )}
      </div>
      <nav className="flex gap-4">
        {data.page > 1 && (
          <Link href={"?page=" + (data.page - 1)}>{t("Previous", "আগের")}</Link>
        )}
        <span>
          {data.page} · {data.total}
        </span>
        {data.page * 25 < data.total && (
          <Link href={"?page=" + (data.page + 1)}>{t("Next", "পরের")}</Link>
        )}
      </nav>
      <Link
        onNavigate={(e) => guardWorkspaceNavigation(e, locale)}
        href="/dashboard/help/academics"
        className="inline-flex cursor-pointer rounded-lg border px-4 py-2 hover:bg-muted"
      >
        {t("Academic workflow help", "শিক্ষা কার্যক্রমের নির্দেশিকা")}
      </Link>
    </section>
  );
}
