"use client";

import { useRef, useState, useSyncExternalStore, useTransition, type FormEvent, type ReactNode } from "react";

const subscribe = () => () => {};

type ActionResult = { ok: boolean; error?: string; receipt?: string };

export function ActionForm({
  action,
  successMessage,
  className,
  children,
}: {
  action: (formData: FormData) => Promise<ActionResult>;
  successMessage: string;
  className?: string;
  children: ReactNode;
}) {
  const [result, setResult] = useState<ActionResult | null>(null);
  const [pending, startTransition] = useTransition();
  const submitting = useRef(false);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);

  function submit(event: FormEvent<HTMLFormElement>) {
    // Manage reset explicitly: a failed action must preserve the entered values.
    event.preventDefault();
    if (submitting.current) return;
    const form = event.currentTarget;
    const data = new FormData(form);
    submitting.current = true;
    setResult(null);

    startTransition(async () => {
      try {
        const response = await action(data);
        setResult(response);
        if (response.ok) form.reset();
      } catch {
        // The request may have saved before the response was lost. Never retry automatically.
        setResult({
          ok: false,
          error: "Could not confirm whether this was saved. Check the records before trying again.",
        });
      } finally {
        submitting.current = false;
      }
    });
  }

  return (
    <form onSubmit={submit} aria-busy={pending}>
      <fieldset disabled={!ready || pending} className={className}>
        {children}
      </fieldset>
      <p role="status" aria-live="polite" aria-atomic="true" className="mt-2 text-sm">
        {pending ? "Saving…" : result?.ok ? (
          <span className="text-green-700 dark:text-green-400">
            {successMessage}{result.receipt ? ` Receipt: ${result.receipt}` : ""}
          </span>
        ) : null}
      </p>
      {!pending && result && !result.ok && (
        <p role="alert" className="mt-2 text-sm text-destructive">
          {result.error || "Unable to save. Please check the information and try again."}
        </p>
      )}
      <noscript>Enable JavaScript to submit this form.</noscript>
    </form>
  );
}
