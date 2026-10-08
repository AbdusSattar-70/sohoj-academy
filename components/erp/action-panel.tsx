"use client";
import { savedFeedbackMessage } from "@/modules/platform/navigation/feedback-message";
import { useEffect, useRef, type ReactNode } from "react";
/** Forms remain mounted while closed so validation failures never erase input. */
export function ActionPanel({
  title,
  children,
  initialOpen = false,
}: {
  title: string;
  children: ReactNode;
  initialOpen?: boolean;
}) {
  const ref = useRef<HTMLDetailsElement>(null);
  useEffect(() => {
    const close = () => {
      if (
        ref.current &&
        !ref.current.querySelector(
          '[data-editor][data-dirty="true"], [data-editor][data-busy="true"]',
        )
      )
        ref.current.open = false;
    };
    window.addEventListener("erp:saved", close);
    return () => window.removeEventListener("erp:saved", close);
  }, []);
  return (
    <details
      ref={ref}
      open={initialOpen}
      data-action-panel
      className="rounded-2xl border bg-card p-4"
    >
      <summary className="cursor-pointer font-semibold">{title}</summary>
      <div className="mt-4">{children}</div>
    </details>
  );
}
export function announceSaved(message?: string) {
  document
    .querySelectorAll<HTMLDetailsElement>("details[data-action-panel]")
    .forEach((el) => {
      if (
        !el.querySelector(
          '[data-editor][data-dirty="true"], [data-editor][data-busy="true"]',
        )
      )
        el.open = false;
    });
  window.dispatchEvent(
    new CustomEvent("erp:saved", {
      detail: message ?? savedFeedbackMessage(document.documentElement.lang),
    }),
  );
}
