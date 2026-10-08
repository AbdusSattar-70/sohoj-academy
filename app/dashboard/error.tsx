"use client";

import { useLanguage } from "@/components/providers/language-provider";
import { useEffect } from "react";
import { AlertTriangle, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const { locale } = useLanguage();
  const t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  useEffect(() => {
    console.error("ERP route error", {
      message: error.message,
      digest: error.digest,
    });
  }, [error]);

  return (
    <section
      role="alert"
      className="rounded-2xl border border-destructive/30 bg-card p-6 shadow-sm"
    >
      <div className="flex items-start gap-4">
        <div className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-destructive/10 text-destructive">
          <AlertTriangle className="size-5" aria-hidden="true" />
        </div>

        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-destructive">
            {t("This section could not be loaded", "এই অংশের তথ্য পাওয়া যায়নি")}
          </p>
          <h2 className="mt-1 text-lg font-semibold">
            {t(
              "You can retry or use the navigation",
              "আবার চেষ্টা করুন অথবা মেনু ব্যবহার করুন",
            )}
          </h2>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
            {t(
              "No action is assumed to have succeeded. Retry this section; if you were saving, check the existing record before repeating the action. Share the reference with support if the issue continues.",
              "কাজ সফল হয়েছে ধরে নেওয়া হয়নি। আবার চেষ্টা করুন; সংরক্ষণের সময় সমস্যা হলে একই কাজ পুনরায় করার আগে বিদ্যমান record যাচাই করুন। সমস্যা থাকলে reference দিয়ে সহায়তা নিন।",
            )}
          </p>

          {error.digest && (
            <div className="mt-4 rounded-xl bg-muted px-3 py-2 text-xs">
              {t("Reference", "রেফারেন্স")}: <code>{error.digest}</code>
            </div>
          )}

          <Button type="button" onClick={reset} className="mt-5 min-h-11">
            <RotateCcw className="mr-2 size-4" aria-hidden="true" />
            {t("Retry this section", "আবার চেষ্টা করুন")}
          </Button>
        </div>
      </div>
    </section>
  );
}
