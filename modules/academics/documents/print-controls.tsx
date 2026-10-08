"use client";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
export function ProgressPrintControls() {
  const { locale } = useLanguage();
  return (
    <div className="mb-4 flex gap-4 print:hidden">
      <Button asChild variant="outline">
        <Link href="/dashboard/academics/progress">
          {locale === "bn" ? "← প্রতিবেদনে ফিরে যান" : "← Back to reports"}
        </Link>
      </Button>
      <Button onClick={() => window.print()}>
        {locale === "bn" ? "প্রিন্ট / PDF সংরক্ষণ" : "Print / Save PDF"}
      </Button>
    </div>
  );
}
