"use client";
import Link from "next/link";
import { useLanguage } from "@/components/providers/language-provider";
import { usePathname } from "next/navigation";
export function OverviewReturnLink() {
  const path = usePathname();
  const { locale } = useLanguage();
  if (path === "/dashboard") return null;
  return (
    <Link
      className="mb-3 inline-block text-xs text-muted-foreground underline print:hidden"
      href={path === "/dashboard" ? "/" : "/dashboard"}
    >
      {locale === "bn"
        ? "← আমার কর্মক্ষেত্রে ফিরে যান"
        : "← Back to my workspace"}
    </Link>
  );
}
