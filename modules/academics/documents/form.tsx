"use client";
import { useState, useTransition, useRef } from "react";
import { useRouter } from "next/navigation";
import { useLanguage } from "@/components/providers/language-provider";
import { Button } from "@/components/ui/button";
import { saveAcademicDocument } from "./actions";
export const inputClass =
  "mt-1 min-h-11 w-full rounded-lg border bg-background px-3 py-2";
export function DocumentAction({
  kind,
  values,
  label,
  children,
  onSaved,
}: {
  kind: "questions" | "progress";
  values: Record<string, unknown>;
  label: string;
  children?: React.ReactNode;
  onSaved?: () => void;
}) {
  const [pending, start] = useTransition(),
    [message, setMessage] = useState(""),
    [uncertain, setUncertain] = useState(false),
    attempt = useRef<Record<string, unknown> | null>(null),
    router = useRouter(),
    { locale } = useLanguage();
  function send(payload: Record<string, unknown>) {
    start(async () => {
      try {
        const r = await saveAcademicDocument(kind, payload);
        setMessage(
          r.ok
            ? locale === "bn"
              ? "সফলভাবে সংরক্ষিত হয়েছে।"
              : r.message
            : r.message,
        );
        setUncertain(!!r.uncertain);
        if (!r.uncertain) attempt.current = null;
        if (r.ok) {
          window.dispatchEvent(
            new CustomEvent("erp:saved", {
              detail: locale === "bn" ? "সফলভাবে সংরক্ষিত হয়েছে।" : r.message,
            }),
          );
          onSaved?.();
          router.refresh();
        }
      } catch {
        setUncertain(true);
        setMessage(
          locale === "bn"
            ? "ফল নিশ্চিত নয়। একই তথ্য রেখে আবার নিশ্চিত করুন।"
            : "Result unconfirmed. Retry unchanged input.",
        );
      }
    });
  }
  return (
    <form
      className="space-y-3 rounded-xl border p-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (pending || uncertain) return;
        const f = new FormData(e.currentTarget),
          payload = {
            ...values,
            ...Object.fromEntries(f),
            ...(kind === "progress" && values.action === "SAVE"
              ? { home_support: f.getAll("home_support") }
              : {}),
            ...(values.action === "FINALIZE" && kind === "questions"
              ? { academy_copy_confirmed: f.has("academy_copy_confirmed") }
              : {}),
            request_id: crypto.randomUUID(),
          };
        attempt.current = payload;
        send(payload);
      }}
    >
      <fieldset disabled={pending || uncertain} className="space-y-3">
        {children}
      </fieldset>
      <Button loading={pending} disabled={pending || uncertain}>
        {label}
      </Button>
      {uncertain && (
        <Button
          type="button"
          variant="outline"
          loading={pending}
          disabled={pending}
          onClick={() => attempt.current && send(attempt.current)}
        >
          {locale === "bn"
            ? "একই কাজের ফল নিশ্চিত করুন"
            : "Confirm same request"}
        </Button>
      )}
      {message && <p role="status">{message}</p>}
    </form>
  );
}
