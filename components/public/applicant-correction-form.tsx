"use client";

import { useRef, useState, useTransition } from "react";
import Link from "next/link";
import { CheckCircle2, Send } from "lucide-react";
import { submitApplicantCorrection } from "@/app/actions/applicant-correction";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useLanguage } from "@/components/providers/language-provider";

export function ApplicantCorrectionForm() {
  const { locale } = useLanguage();
  const bn = locale === "bn";
  const formRef = useRef<HTMLFormElement>(null);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    ok: boolean;
    text: string;
    reference?: string;
  } | null>(null);

  function submit(formData: FormData) {
    setMessage(null);
    const input = {
      prospectNo: String(formData.get("prospectNo") ?? ""),
      mobile: String(formData.get("mobile") ?? ""),
      requestedChanges: String(formData.get("requestedChanges") ?? ""),
      website: String(formData.get("website") ?? ""),
    };
    startTransition(async () => {
      const result = await submitApplicantCorrection(input);
      if (result.ok) {
        setMessage({
          ok: true,
          reference: result.reference,
          text: bn
            ? "আপনার সংশোধনের অনুরোধ জমা হয়েছে। স্টাফ যাচাই করে যোগাযোগ করবে।"
            : "Your correction request was submitted. Staff will review it and contact you.",
        });
        formRef.current?.reset();
      } else {
        setMessage({ ok: false, text: result.error });
      }
    });
  }

  return (
    <div className="space-y-6">
      <div aria-live="polite" aria-atomic="true">
        {message ? (
          <div
            role={message.ok ? "status" : "alert"}
            className={
              message.ok
                ? "rounded-2xl border-emerald-300 bg-emerald-50 p-5 text-emerald-950"
                : "rounded-2xl border-destructive/30 bg-destructive/10 p-5 text-destructive"
            }
          >
            {message.ok ? (
              <CheckCircle2 className="mb-3 size-6" aria-hidden="true" />
            ) : null}
            <p className="font-semibold">
              {message.ok
                ? bn
                  ? "অনুরোধ জমা হয়েছে"
                  : "Correction submitted"
                : bn
                  ? "ফর্মটি যাচাই করুন"
                  : "Please check the form"}
            </p>
            <p className="mt-1 text-sm leading-6">{message.text}</p>
            {message.reference ? (
              <p className="mt-3 text-sm font-semibold">
                {bn ? "রেফারেন্স" : "Reference"}: {message.reference}
              </p>
            ) : null}
          </div>
        ) : null}
      </div>

      <form ref={formRef} action={submit} className="space-y-5">
        <div>
          <Label htmlFor="correction-reference">
            {bn ? "আবেদন রেফারেন্স" : "Application reference"} *
          </Label>
          <Input
            id="correction-reference"
            name="prospectNo"
            required
            minLength={5}
            className="mt-1 h-11"
            placeholder="e.g. PR-000001"
          />
        </div>
        <div>
          <Label htmlFor="correction-mobile">
            {bn ? "আবেদনে ব্যবহৃত মোবাইল" : "Mobile used in the application"} *
          </Label>
          <Input
            id="correction-mobile"
            name="mobile"
            required
            minLength={8}
            className="mt-1 h-11"
            inputMode="tel"
          />
        </div>
        <div>
          <Label htmlFor="correction-request">
            {bn ? "কী সংশোধন করতে হবে" : "What should be corrected?"} *
          </Label>
          <textarea
            id="correction-request"
            name="requestedChanges"
            required
            minLength={10}
            maxLength={2000}
            rows={6}
            className="mt-1 w-full rounded-xl border-input bg-background p-3 text-sm outline-none focus:ring-3 focus:ring-ring/20"
            placeholder={
              bn
                ? "যে তথ্যটি ভুল এবং সঠিক তথ্যটি লিখুন।"
                : "Tell us what is incorrect and what the correct information should be."
            }
          />
        </div>
        <div className="hidden" aria-hidden="true">
          <label htmlFor="correction-website">Website</label>
          <input
            id="correction-website"
            name="website"
            tabIndex={-1}
            autoComplete="off"
          />
        </div>
        <button
          type="submit"
          disabled={pending}
          className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 text-sm font-semibold text-white disabled:opacity-60"
        >
          <Send className="size-4" aria-hidden="true" />
          {pending
            ? bn
              ? "জমা হচ্ছে…"
              : "Submitting…"
            : bn
              ? "সংশোধনের অনুরোধ জমা দিন"
              : "Submit correction request"}
        </button>
      </form>
      <p className="text-sm text-muted-foreground">
        <Link href="/" className="font-semibold underline-offset-4">
          {bn ? "হোমে ফিরুন" : "Return home"}
        </Link>
      </p>
    </div>
  );
}
