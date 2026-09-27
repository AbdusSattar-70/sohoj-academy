"use client";

import { useState, useTransition } from "react";
import { receiveSignedConsent } from "../consent-actions";

export function ConsentForm({ admissionId }: { admissionId: string }) {
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState("");
  return <form className="space-y-3 rounded-xl border p-4 print:hidden" action={(data) => {
    setMessage("");
    startTransition(async () => { const result = await receiveSignedConsent(data); setMessage(result.message); });
  }}>
    <h3 className="font-semibold">Receive signed consent</h3>
    <p className="text-sm text-muted-foreground">Verify the guardian signed the printed form, then attach its scan or photograph. The original stays in a private document register.</p>
    <input type="hidden" name="admissionId" value={admissionId} />
    <div className="flex flex-wrap gap-3">
      <label className="space-y-1 text-sm">Guardian signed on<input type="date" name="guardianSignedOn" required className="block min-h-11 rounded-lg border bg-background px-3" /></label>
      <label className="space-y-1 text-sm">Signed file (PDF, JPEG, PNG; up to 5 MB)<input type="file" name="signedFile" required accept="application/pdf,image/jpeg,image/png" className="block max-w-full rounded-lg border bg-background p-2" /></label>
    </div>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="studentSigned" />Student also signed, if able</label>
    <button disabled={pending} className="min-h-11 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground disabled:opacity-50">{pending ? "Receiving…" : "Record signed form"}</button>
    {message && <p role="status" className="text-sm">{message}</p>}
  </form>;
}
