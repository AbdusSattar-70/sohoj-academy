"use client";

import { useLanguage } from "@/components/providers/language-provider";

export function LocalizedText({
  en,
  bn,
}: {
  en: string;
  bn: string;
}) {
  const { locale } = useLanguage();
  return <>{locale === "bn" ? bn : en}</>;
}
