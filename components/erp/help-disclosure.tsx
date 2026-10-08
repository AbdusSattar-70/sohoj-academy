"use client";
import { CircleHelp } from "lucide-react";
import { useLanguage } from "@/components/providers/language-provider";
export type HelpText = { en: string; bn: string };
export function HelpDisclosure({
  text,
  label,
}: {
  text: HelpText;
  label?: string;
}) {
  const { locale } = useLanguage();
  const name =
    label ?? (locale === "bn" ? "এটি কীভাবে কাজ করে?" : "How does this work?");
  return (
    <details className="group relative inline-block align-middle print:hidden">
      <summary
        aria-label={name}
        className="inline-flex min-h-9 min-w-9 cursor-pointer list-none items-center justify-center rounded-lg text-muted-foreground hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        <CircleHelp className="size-4" aria-hidden="true" />
      </summary>
      <div className="absolute right-0 z-40 hidden w-72 max-w-[80vw] rounded-xl border bg-popover p-4 text-sm leading-6 text-popover-foreground shadow-lg group-open:block group-hover:block group-focus-within:block">
        {locale === "bn" ? text.bn : text.en}
      </div>
    </details>
  );
}
