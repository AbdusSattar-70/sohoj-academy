"use client";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { workflowReturnPath } from "@/modules/platform/navigation/workflow-return";
import { useLanguage } from "@/components/providers/language-provider";
export function WorkflowReturn() {
  const params = useSearchParams();
  const { locale } = useLanguage();
  const value = workflowReturnPath(params.get("returnTo"));
  const safe = Boolean(value);
  return safe ? (
    <div className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-xl border bg-card p-4 text-sm">
      <span>
        {locale === "bn"
          ? "এই কাজ শেষ করে আগের কাজের পেজে ফিরে যান।"
          : "Finish this task, then return to your original working page."}
      </span>
      <Link
        className="rounded-lg bg-primary px-4 py-2 font-semibold text-primary-foreground"
        href={value!}
      >
        {locale === "bn" ? "আগের কাজে ফিরে যান" : "Return to original workflow"}
      </Link>
    </div>
  ) : null;
}
