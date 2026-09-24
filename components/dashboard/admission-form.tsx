"use client";

import { useMemo, useState, useTransition } from "react";
import { createAdmission } from "@/app/actions/admissions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type Option = { id: string; name: string };
type BatchOption = Option & { class_id: string; program_id: string | null; academic_year_id: string };

export function AdmissionForm({
  academicYears,
  classes,
  programs,
  batches,
}: {
  academicYears: Option[];
  classes: Option[];
  programs: Option[];
  batches: BatchOption[];
}) {
  const [isPending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [yearId, setYearId] = useState(academicYears[0]?.id ?? "");
  const [classId, setClassId] = useState("");
  const [programId, setProgramId] = useState("");

  const availableBatches = useMemo(
    () => batches.filter((b) =>
      (!yearId || b.academic_year_id === yearId) &&
      (!classId || b.class_id === classId) &&
      (!programId || !b.program_id || b.program_id === programId)
    ),
    [batches, yearId, classId, programId]
  );

  function submit(formData: FormData) {
    setMessage(null);
    const input = {
      name: String(formData.get("name") ?? ""),
      nameBn: String(formData.get("nameBn") ?? ""),
      gender: String(formData.get("gender") ?? ""),
      dateOfBirth: String(formData.get("dateOfBirth") ?? ""),
      schoolName: String(formData.get("schoolName") ?? ""),
      schoolRoll: String(formData.get("schoolRoll") ?? ""),
      guardianName: String(formData.get("guardianName") ?? ""),
      relationship: String(formData.get("relationship") ?? ""),
      mobile: String(formData.get("mobile") ?? ""),
      alternateMobile: String(formData.get("alternateMobile") ?? ""),
      address: String(formData.get("address") ?? ""),
      academicYearId: String(formData.get("academicYearId") ?? ""),
      classId: String(formData.get("classId") ?? ""),
      batchId: String(formData.get("batchId") ?? "") || undefined,
      programId: String(formData.get("programId") ?? "") || undefined,
      admissionDate: String(formData.get("admissionDate") ?? ""),
      monthlyFee: Number(formData.get("monthlyFee") ?? 0),
      discount: Number(formData.get("discount") ?? 0),
    };

    startTransition(async () => {
      const result = await createAdmission(input);
      setMessage({
        ok: result.ok,
        text: result.ok
          ? `Admission saved successfully. Student ID: ${result.studentNo ?? "created"}`
          : result.error ?? "Admission could not be saved.",
      });
    });
  }

  return (
    <form action={submit} className="space-y-8">
      <section>
        <h3 className="mb-4 font-semibold">Student Information</h3>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Field label="Student Name"><Input name="name" required /></Field>
          <Field label="নাম (বাংলা)"><Input name="nameBn" /></Field>
          <Field label="Gender">
            <select name="gender" className="h-8 w-full rounded-lg border bg-background px-2.5 text-sm">
              <option value="">Select</option><option>Male</option><option>Female</option><option>Other</option>
            </select>
          </Field>
          <Field label="Date of Birth"><Input name="dateOfBirth" type="date" /></Field>
          <Field label="School"><Input name="schoolName" /></Field>
          <Field label="School Roll"><Input name="schoolRoll" /></Field>
        </div>
      </section>

      <section>
        <h3 className="mb-4 font-semibold">Guardian Information</h3>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Field label="Guardian Name"><Input name="guardianName" required /></Field>
          <Field label="Relationship"><Input name="relationship" placeholder="Father / Mother / Guardian" required /></Field>
          <Field label="Mobile"><Input name="mobile" inputMode="tel" required /></Field>
          <Field label="Alternate Mobile"><Input name="alternateMobile" inputMode="tel" /></Field>
          <Field label="Address" wide><Input name="address" /></Field>
        </div>
      </section>

      <section>
        <h3 className="mb-4 font-semibold">Admission & Fee</h3>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Field label="Academic Year">
            <select name="academicYearId" required value={yearId} onChange={(e)=>setYearId(e.target.value)} className="h-8 w-full rounded-lg border bg-background px-2.5 text-sm">
              <option value="">Select</option>{academicYears.map((x)=><option key={x.id} value={x.id}>{x.name}</option>)}
            </select>
          </Field>
          <Field label="Class">
            <select name="classId" required value={classId} onChange={(e)=>setClassId(e.target.value)} className="h-8 w-full rounded-lg border bg-background px-2.5 text-sm">
              <option value="">Select</option>{classes.map((x)=><option key={x.id} value={x.id}>{x.name}</option>)}
            </select>
          </Field>
          <Field label="Program">
            <select name="programId" value={programId} onChange={(e)=>setProgramId(e.target.value)} className="h-8 w-full rounded-lg border bg-background px-2.5 text-sm">
              <option value="">Optional</option>{programs.map((x)=><option key={x.id} value={x.id}>{x.name}</option>)}
            </select>
          </Field>
          <Field label="Batch">
            <select name="batchId" className="h-8 w-full rounded-lg border bg-background px-2.5 text-sm">
              <option value="">Optional</option>{availableBatches.map((x)=><option key={x.id} value={x.id}>{x.name}</option>)}
            </select>
          </Field>
          <Field label="Admission Date"><Input name="admissionDate" type="date" required /></Field>
          <Field label="Monthly Fee (৳)"><Input name="monthlyFee" type="number" min="0" defaultValue="0" required /></Field>
          <Field label="Discount (৳)"><Input name="discount" type="number" min="0" defaultValue="0" required /></Field>
        </div>
      </section>

      {message && <div className={`rounded-lg border p-3 text-sm ${message.ok ? "border-green-600/40" : "border-destructive/40 text-destructive"}`}>{message.text}</div>}
      <div className="flex justify-end"><Button type="submit" size="lg" disabled={isPending}>{isPending ? "Saving..." : "Create Admission"}</Button></div>
    </form>
  );
}

function Field({ label, children, wide = false }: { label: string; children: React.ReactNode; wide?: boolean }) {
  return <div className={wide ? "md:col-span-2" : ""}><Label className="mb-2">{label}</Label>{children}</div>;
}
