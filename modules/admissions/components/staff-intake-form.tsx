"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition, type FormEvent } from "react";
import { Button } from "@/components/ui/button";
import type { AdmissionWorkspace } from "../schema";
import { createStaffAdmissionIntake } from "../intake-actions";

const input = "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm";
const phonePattern = "01[3-9][0-9]{8}";

function TextField({
  label, name, required = false, type = "text", pattern, maxLength,
  hint, className = "",
}: {
  label: string; name: string; required?: boolean; type?: string;
  pattern?: string; maxLength?: number; hint?: string; className?: string;
}) {
  return <label className={`block space-y-1.5 text-sm ${className}`}>
    <span className="font-medium">{label}{required ? " *" : ""}</span>
    <input className={input} name={name} type={type} required={required} pattern={pattern} maxLength={maxLength} />
    {hint && <span className="block text-xs text-muted-foreground">{hint}</span>}
  </label>;
}

export function StaffAdmissionIntakeForm({ data }: { data: AdmissionWorkspace }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState("");
  const [created, setCreated] = useState<{ admissionId: string; prospectNo: string } | null>(null);
  const [offeringId, setOfferingId] = useState("");
  const requestId = useRef("");
  const offering = data.offerings.find((row) => row.id === offeringId);
  const batches = data.batches.filter((batch) =>
    batch.isActive && batch.offeringId === offeringId &&
    batch.occupied < Math.min(batch.capacity, data.capacityLimit ?? batch.capacity),
  );

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (!requestId.current) requestId.current = crypto.randomUUID();
    const values = new FormData(form);
    const value = (key: string) => String(values.get(key) ?? "");
    startTransition(async () => {
      setError("");
      setCreated(null);
      const result = await createStaffAdmissionIntake({
        requestId: requestId.current,
        offeringId: value("offeringId"),
        batchId: value("batchId"),
        studentName: value("studentName"),
        studentNameBn: value("studentNameBn"),
        dateOfBirth: value("dateOfBirth"),
        gender: value("gender") as "" | "Female" | "Male" | "Other" | "Prefer not to say",
        schoolName: value("schoolName"),
        schoolRoll: value("schoolRoll"),
        guardianName: value("guardianName"),
        guardianRelationship: value("guardianRelationship"),
        mobile: value("mobile"),
        alternateMobile: value("alternateMobile"),
        guardianAddress: value("guardianAddress"),
        referralNote: value("referralNote"),
        reason: value("reason"),
        consentToContact: values.get("consentToContact") === "on",
      });
      if (!result.ok) {
        setError(result.message);
        return;
      }
      requestId.current = "";
      setCreated({ admissionId: result.admissionId, prospectNo: result.prospectNo });
      form.reset();
      setOfferingId("");
      router.refresh();
    });
  }

  return <form onSubmit={submit} className="space-y-6 rounded-2xl border bg-card p-5 sm:p-6">
    <header>
      <p className="text-sm font-semibold">Enter applicant details with the student or guardian</p>
      <p className="mt-1 text-sm text-muted-foreground">This creates a CRM Prospect and an admission draft together. Staff can complete this on the family’s behalf; it does not accept admission, post fees, or activate enrollment.</p>
    </header>

    <section className="space-y-3">
      <h3 className="text-sm font-semibold">Programme and placement</h3>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Programme offering *</span>
          <select name="offeringId" required value={offeringId} onChange={(e) => setOfferingId(e.target.value)} className={input}>
            <option value="">Choose an active programme</option>
            {data.offerings.map((row) => <option key={row.id} value={row.id}>{row.code} · {row.name} · {row.yearName} · {row.branchName ?? "No branch"} · {row.className}</option>)}
          </select>
          <span className="block text-xs text-muted-foreground">Only active offerings are available. The class is assigned from the chosen offering.</span>
        </label>
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Batch *</span>
          <select name="batchId" required disabled={!offeringId} className={input}>
            <option value="">{!offeringId ? "Choose an offering first" : batches.length ? "Choose a batch" : "No available batch for this offering"}</option>
            {batches.map((row) => <option key={row.id} value={row.id}>{row.name} · {row.occupied}/{row.capacity} seats</option>)}
          </select>
        </label>
      </div>
      {offering && <p className="rounded-xl bg-muted/40 p-3 text-xs text-muted-foreground">Placement: {offering.className} · {offering.yearName} · {offering.branchName ?? "No branch"}. Fee terms are inherited from the current published Fee Plan and shown on the draft for review.</p>}
    </section>

    <section className="space-y-3">
      <h3 className="text-sm font-semibold">Student details</h3>
      <div className="grid gap-4 md:grid-cols-2">
        <TextField label="Student full name" name="studentName" required maxLength={160} />
        <TextField label="Student name in Bangla" name="studentNameBn" maxLength={160} />
        <TextField label="Date of birth" name="dateOfBirth" type="date" />
        <label className="block space-y-1.5 text-sm"><span className="font-medium">Gender</span><select name="gender" className={input}><option value="">Not provided</option><option>Female</option><option>Male</option><option>Other</option><option>Prefer not to say</option></select></label>
        <TextField label="Current school" name="schoolName" maxLength={200} />
        <TextField label="School roll" name="schoolRoll" maxLength={40} />
      </div>
    </section>

    <section className="space-y-3">
      <h3 className="text-sm font-semibold">Guardian and contact</h3>
      <div className="grid gap-4 md:grid-cols-2">
        <TextField label="Guardian full name" name="guardianName" required maxLength={160} />
        <TextField label="Relationship to student" name="guardianRelationship" maxLength={80} hint="For example: Mother, Father, or Legal guardian." />
        <TextField label="Primary mobile" name="mobile" required pattern={phonePattern} hint="11-digit Bangladesh mobile, e.g. 01712345678." />
        <TextField label="Alternate mobile" name="alternateMobile" pattern={`^$|${phonePattern}`} />
        <TextField label="Guardian address" name="guardianAddress" required maxLength={300} className="md:col-span-2" />
        <TextField label="Referrer or referral note" name="referralNote" maxLength={500} hint="Record the name/contact if shared. Confirm and assign the referral on the case before acceptance." className="md:col-span-2" />
      </div>
    </section>

    <section className="space-y-3">
      <h3 className="text-sm font-semibold">Verification and record</h3>
      <TextField label="Why is this admission draft being created?" name="reason" required maxLength={500} hint="This reason is kept in the audit trail." />
      <label className="flex items-start gap-3 rounded-xl border p-3 text-sm leading-6">
        <input className="mt-1 size-4" type="checkbox" name="consentToContact" required />
        <span>The guardian gave permission for Sohoj Academy to contact them about this student. Signed admission consent is collected separately before acceptance.</span>
      </label>
    </section>

    {error && <p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{error}</p>}
    {created && <div role="status" className="rounded-xl border border-emerald-300 bg-emerald-50 p-4 text-sm text-emerald-950 dark:border-emerald-900 dark:bg-emerald-950/30 dark:text-emerald-100">
      <p className="font-semibold">Admission draft created</p>
      <p className="mt-1">{created.prospectNo ? `Prospect ${created.prospectNo} · ` : ""}The case is ready for identity and consent review.</p>
      <Link className="mt-2 inline-block font-medium underline" href={`/dashboard/admissions#${created.admissionId}`}>Open the admission case</Link>
    </div>}
    <div className="flex flex-wrap items-center gap-3">
      <Button type="submit" disabled={pending || data.offerings.length === 0}>{pending ? "Creating draft…" : "Create Prospect and admission draft"}</Button>
      <span className="text-xs text-muted-foreground">No fee is charged and no enrollment is activated at this step.</span>
    </div>
  </form>;
}
