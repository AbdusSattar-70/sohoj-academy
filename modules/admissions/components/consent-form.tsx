"use client";

import { useRef, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { receiveSignedConsent } from "../consent-actions";

export function ConsentForm({ admissionId }: { admissionId: string }) {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setMessage(null);
    startTransition(async () => {
      const result = await receiveSignedConsent(data);
      setMessage({ ok: result.ok, text: result.message });
      if (result.ok) {
        formRef.current?.reset();
        router.refresh();
      }
    });
  };
  return <form ref={formRef} onSubmit={submit} className="space-y-3 rounded-xl border p-4 print:hidden">
    <h3 className="font-semibold">Receive signed consent</h3>
    <p className="text-sm text-muted-foreground">Verify the guardian signed the printed form, then attach its scan or photograph. Submitting records it to this case; it does not change the admission stage.</p>
    <input type="hidden" name="admissionId" value={admissionId} />
    <div className="flex flex-wrap gap-3">
      <label className="space-y-1 text-sm">Guardian signed on<input type="date" name="guardianSignedOn" required className="block min-h-11 rounded-lg border bg-background px-3" /></label>
      <label className="space-y-1 text-sm">Signed file (PDF, JPEG, PNG; up to 5 MB)<input type="file" name="signedFile" required accept="application/pdf,image/jpeg,image/png" className="block max-w-full rounded-lg border bg-background p-2" /></label>
    </div>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="studentSigned" />Student also signed, if able</label>
    <button disabled={pending} className="min-h-11 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground disabled:opacity-50">{pending ? "Receiving…" : "Record signed form"}</button>
    {message && <p role={message.ok ? "status" : "alert"} className={`text-sm ${message.ok ? "text-emerald-700" : "text-destructive"}`}>{message.text}</p>}
  </form>;
}
