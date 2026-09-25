"use client";

import { Languages, Monitor, Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { cn } from "@/lib/utils";

export function PreferenceControls({
  compact = false,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  const { locale, setLocale, t } = useLanguage();
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const selectedTheme = mounted ? theme ?? "system" : "system";

  return (
    <div
      className={cn(
        "flex items-center gap-1 rounded-xl border border-border bg-background/90 p-1 shadow-sm backdrop-blur",
        className
      )}
      aria-label="Language and appearance preferences"
    >
      <div className="flex items-center" aria-label={t("language")}>
        {!compact && (
          <span className="px-2 text-muted-foreground" aria-hidden="true">
            <Languages className="size-4" />
          </span>
        )}
        <button
          type="button"
          onClick={() => setLocale("en")}
          aria-pressed={locale === "en"}
          className={cn(
            "min-h-9 rounded-lg px-2.5 text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
            locale === "en"
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:bg-muted hover:text-foreground"
          )}
        >
          EN
        </button>
        <button
          type="button"
          onClick={() => setLocale("bn")}
          aria-pressed={locale === "bn"}
          className={cn(
            "min-h-9 rounded-lg px-2.5 text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
            locale === "bn"
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:bg-muted hover:text-foreground"
          )}
        >
          বাংলা
        </button>
      </div>

      <span className="mx-0.5 h-6 w-px bg-border" aria-hidden="true" />

      <div className="flex items-center" aria-label={t("theme")}>
        {[
          ["light", Sun, t("light")],
          ["dark", Moon, t("dark")],
          ["system", Monitor, t("system")],
        ].map(([value, Icon, label]) => (
          <button
            key={value as string}
            type="button"
            onClick={() => setTheme(value as string)}
            aria-pressed={selectedTheme === value}
            aria-label={label as string}
            title={label as string}
            className={cn(
              "flex size-9 items-center justify-center rounded-lg transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
              selectedTheme === value
                ? "bg-primary text-primary-foreground"
                : "text-muted-foreground hover:bg-muted hover:text-foreground"
            )}
          >
            <Icon className="size-4" aria-hidden="true" />
          </button>
        ))}
      </div>
    </div>
  );
}
