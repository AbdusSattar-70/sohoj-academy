"use client";
import { useState, useTransition, useRef, useId } from "react";
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
  const instructionId = useId();
  const formRef = useRef<HTMLFormElement>(null);
  const instructions =
    kind === "questions"
      ? ({
          SAVE: [
            "Save your Google Docs draft; it is not sent for review yet.",
            "Google Docs খসড়া সংরক্ষণ হবে; এখনই review-এ যাবে না।",
          ],
          SUBMIT: [
            "Send the saved draft to admin. Editing stops until it is returned.",
            "সংরক্ষিত খসড়া admin-এর কাছে যাবে। ফেরত না আসা পর্যন্ত edit বন্ধ থাকবে।",
          ],
          RETURN: [
            "Return to the teacher with correction instructions; this is not final approval.",
            "সংশোধনের নির্দেশনা দিয়ে শিক্ষকের কাছে ফেরত যাবে; এটি চূড়ান্ত অনুমোদন নয়।",
          ],
          FINALIZE: [
            "Record academy-owned final questions and a separate answer key. The final record cannot be edited.",
            "Academy-owned চূড়ান্ত প্রশ্ন ও আলাদা answer key রেকর্ড হবে। Final record edit করা যাবে না।",
          ],
        } as Record<string, [string, string]>)
      : ({
          GENERATE: [
            "Generate a draft preview from approved records. No final report is issued yet.",
            "অনুমোদিত record থেকে খসড়া preview হবে। এখনই final report তৈরি হবে না।",
          ],
          SAVE: [
            "Save comments and refresh approved evidence; the report remains a draft.",
            "মন্তব্য সংরক্ষণ ও অনুমোদিত তথ্য হালনাগাদ হবে; report খসড়া থাকবে।",
          ],
          SUBMIT: [
            "Send your report for admin review; submitted drafts cannot be edited until returned.",
            "Admin review-এর জন্য report যাবে; ফেরত না আসা পর্যন্ত edit বন্ধ থাকবে।",
          ],
          RETURN: [
            "Return the report for correction with your note.",
            "আপনার নির্দেশনাসহ report সংশোধনের জন্য ফেরত যাবে।",
          ],
          FINALIZE: [
            "Refresh the approved evidence and issue an immutable final report ready to print.",
            "অনুমোদিত তথ্য হালনাগাদ হয়ে অপরিবর্তনীয় final report তৈরি হবে; print করা যাবে।",
          ],
        } as Record<string, [string, string]>);
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
          if (formRef.current) formRef.current.dataset.dirty = "false";
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
      ref={formRef}
      data-editor
      data-dirty="false"
      data-busy={pending ? "true" : "false"}
      onChange={(e) => {
        e.currentTarget.dataset.dirty = "true";
      }}
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
      {instructions[String(values.action)] && (
        <p
          id={instructionId}
          className="text-sm leading-6 text-muted-foreground"
        >
          {instructions[String(values.action)][locale === "bn" ? 1 : 0]}
        </p>
      )}
      <fieldset disabled={pending || uncertain} className="space-y-3">
        {children}
      </fieldset>
      <Button
        loading={pending}
        disabled={pending || uncertain}
        aria-describedby={instructionId}
      >
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
