"use client";
import { useLanguage } from "@/components/providers/language-provider";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { useState, type ReactNode } from "react";
type Step = { id: string; title: string; complete: boolean; active: boolean };
export function CaseStepNavigation({
  steps,
  panels,
}: {
  steps: Step[];
  panels: Record<string, ReactNode>;
}) {
  const { locale } = useLanguage();
  const t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const names: Record<string, string> = {
    verify: "আবেদন ও placement যাচাই",
    source: "Organic বা referrer নির্বাচন",
    consent: "স্বাক্ষরিত কাগজ গ্রহণ",
    submit: "ফি যাচাই ও ভর্তি নিশ্চিত",
    enroll: "টাকা গ্রহণ ও enrollment",
  };
  const current =
    steps.find((s) => s.active)?.id ??
    steps.find((s) => !s.complete)?.id ??
    steps[steps.length - 1]?.id;
  const [selection, setSelection] = useState<{
    current: string;
    id: string;
  } | null>(null);
  const selected = selection?.current === current ? selection.id : current;
  return (
    <section className="space-y-4">
      <ol
        aria-label="Admission progress"
        className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3"
      >
        {steps.map((s, i) => (
          <li key={s.id}>
            <button
              type="button"
              aria-current={selected === s.id ? "step" : undefined}
              disabled={!s.complete && !s.active}
              onClick={(event) => {
                if (selected === s.id) return;
                guardWorkspaceNavigation(event, locale);
                if (!event.defaultPrevented)
                  setSelection({ current, id: s.id });
              }}
              className={`w-full rounded-xl border p-4 text-left text-sm disabled:opacity-45 ${selected === s.id ? "border-primary bg-primary/10" : "bg-card"}`}
            >
              <span className="mr-2 font-bold">{s.complete ? "✓" : i + 1}</span>
              {locale === "bn" ? (names[s.id] ?? s.title) : s.title}
              <span className="mt-1 block text-xs text-muted-foreground">
                {s.complete
                  ? t("Completed · view", "সম্পন্ন · দেখুন")
                  : s.active
                    ? t("Current · open", "বর্তমান ধাপ · খুলুন")
                    : t(
                        "Complete earlier steps first",
                        "আগের ধাপ সম্পন্ন করুন",
                      )}
              </span>
            </button>
          </li>
        ))}
      </ol>
      <div id="work-panel" className="rounded-2xl border bg-card p-5">
        {selected && panels[selected]}
      </div>
    </section>
  );
}
