"use client";
import { savedFeedbackMessage } from "@/modules/platform/navigation/feedback-message";
import { useEffect, useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
export function MutationFeedback() {
  const { locale } = useLanguage();
  const [notice, setNotice] = useState<{
    text: string;
    warning: boolean;
  } | null>(null);
  useEffect(() => {
    const saved = (e: Event) =>
      setNotice({
        text: (e as CustomEvent<string>).detail || savedFeedbackMessage(locale),
        warning: false,
      });
    const warning = (e: Event) =>
      setNotice({ text: (e as CustomEvent<string>).detail, warning: true });
    window.addEventListener("erp:saved", saved);
    window.addEventListener("erp:notice", warning);
    return () => {
      window.removeEventListener("erp:saved", saved);
      window.removeEventListener("erp:notice", warning);
    };
  }, [locale]);
  return notice ? (
    <div
      role="status"
      aria-live="polite"
      className={
        "mb-4 flex items-center justify-between gap-3 rounded-xl border p-3 text-sm print:hidden " +
        (notice.warning
          ? "border-amber-500/40 bg-amber-500/10"
          : "border-emerald-500/40 bg-emerald-500/10")
      }
    >
      <span>{notice.text}</span>
      <Button
        type="button"
        size="icon"
        variant="ghost"
        onClick={() => setNotice(null)}
        aria-label={locale === "bn" ? "বার্তা বন্ধ করুন" : "Dismiss message"}
      >
        ×
      </Button>
    </div>
  ) : null;
}
