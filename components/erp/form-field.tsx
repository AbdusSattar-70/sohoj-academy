"use client";
import { localizedFieldLabel } from "@/modules/platform/navigation/field-labels";
import { fieldGuide } from "@/modules/platform/navigation/field-guides";
import { useLanguage } from "@/components/providers/language-provider";
import { HelpDisclosure, type HelpText } from "./help-disclosure";
import { useEffect, useRef, type ReactNode } from "react";
import { LocalizedText } from "@/components/shared/localized-text";
import { cn } from "@/lib/utils";

export function ErpFormField({
  id,
  label,
  hint,
  help,
  required = false,
  error,
  className,
  children,
}: {
  id: string;
  label: string;
  hint?: string;
  help?: HelpText;
  required?: boolean;
  error?: string | null;
  className?: string;
  children: (props: {
    id: string;
    describedBy?: string;
    invalid: boolean;
  }) => ReactNode;
}) {
  const { locale } = useLanguage();
  const guidance = help ?? fieldGuide(label);
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  const describedBy = [hintId, errorId].filter(Boolean).join(" ") || undefined;

  return (
    <div className={cn("grid gap-2", className)}>
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-1">
          <label htmlFor={id} className="text-sm font-medium leading-5">
            <LocalizedText en={label} bn={localizedFieldLabel(label, "bn")} />
          </label>
          {guidance && <HelpDisclosure text={guidance} />}
        </div>
        <span className="text-xs text-muted-foreground">
          {required
            ? locale === "bn"
              ? "আবশ্যক"
              : "Required"
            : locale === "bn"
              ? "ঐচ্ছিক"
              : "Optional"}
        </span>
      </div>

      {children({ id, describedBy, invalid: Boolean(error) })}

      {hint && (
        <p id={hintId} className="text-xs leading-5 text-muted-foreground">
          {hint}
        </p>
      )}

      {error && (
        <p
          id={errorId}
          role="alert"
          className="text-xs font-medium leading-5 text-destructive"
        >
          {error}
        </p>
      )}
    </div>
  );
}

export function ErpFormStatus({
  message,
}: {
  message: { ok: boolean; text: string } | null;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (message?.ok) {
      const form = ref.current?.closest("form");
      if (form) form.dataset.dirty = "false";
    }
  }, [message]);
  if (!message) return null;

  return (
    <div
      ref={ref}
      role={message.ok ? "status" : "alert"}
      aria-live="polite"
      aria-atomic="true"
      className={cn(
        "rounded-xl border p-4 text-sm leading-6",
        message.ok
          ? "border-emerald-300 bg-emerald-50 text-emerald-950 dark:border-emerald-900 dark:bg-emerald-950/30 dark:text-emerald-100"
          : "border-destructive/40 bg-destructive/10 text-destructive",
      )}
    >
      {message.text}
    </div>
  );
}
