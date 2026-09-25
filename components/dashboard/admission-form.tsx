"use client";

import Link from "next/link";
import { useMemo, useRef, useState, useTransition } from "react";
import { createAdmission } from "@/app/actions/admissions";
import { WorkflowHelp } from "@/components/shared/workflow-help";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type Option = { id: string; name: string };
type YearOption = Option & { is_active: boolean };
type BatchOption = Option & {
  class_id: string;
  program_id: string | null;
  academic_year_id: string;
  capacity: number;
  enrolled: number;
};
type Message = {
  ok: boolean;
  text: string;
  studentId?: string | null;
  studentNo?: string | null;
};

const selectClass =
  "h-10 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50";

function todayLocal() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

export function AdmissionForm({
  academicYears,
  classes,
  programs,
  batches,
  schoolSuggestions,
}: {
  academicYears: YearOption[];
  classes: Option[];
  programs: Option[];
  batches: BatchOption[];
  schoolSuggestions: string[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const defaultYearId =
    academicYears.find((year) => year.is_active)?.id ?? academicYears[0]?.id ?? "";

  const [isPending, startTransition] = useTransition();
  const [message, setMessage] = useState<Message | null>(null);
  const [yearId, setYearId] = useState(defaultYearId);
  const [classId, setClassId] = useState("");
  const [programId, setProgramId] = useState("");
  const [batchId, setBatchId] = useState("");
  const [monthlyFee, setMonthlyFee] = useState("0");
  const [discount, setDiscount] = useState("0");

  const availableBatches = useMemo(
    () =>
      batches.filter(
        (batch) =>
          (!yearId || batch.academic_year_id === yearId) &&
          (!classId || batch.class_id === classId) &&
          (!programId || !batch.program_id || batch.program_id === programId)
      ),
    [batches, yearId, classId, programId]
  );

  const netMonthlyFee = Math.max(0, Number(monthlyFee || 0) - Number(discount || 0));

  function resetAdmission() {
    formRef.current?.reset();
    setMessage(null);
    setYearId(defaultYearId);
    setClassId("");
    setProgramId("");
    setBatchId("");
    setMonthlyFee("0");
    setDiscount("0");
  }

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
          ? `Admission saved successfully. Permanent Student ID: ${result.studentNo ?? "created"}.`
          : result.error ?? "Admission could not be saved.",
        studentId: result.studentId,
        studentNo: result.studentNo,
      });
    });
  }

  return (
    <div className="space-y-6">
      <WorkflowHelp
        steps={[
          "Enter the student's identity and current school information.",
          "Add the primary guardian and reliable contact details.",
          "Choose Academic Year → Class → Program → Batch. Only matching batches are shown.",
          "Review the monthly fee, discount and calculated net monthly fee before saving.",
          "After saving, open the student profile or continue to the next operational step.",
        ]}
      />

      <div className="rounded-lg border bg-muted/20 p-3 text-sm text-muted-foreground">
        Fields marked <span className="font-semibold text-foreground">Required</span> must be completed.
        Optional fields can be added later from the student profile.
      </div>

      <form ref={formRef} action={submit} className="space-y-8" aria-describedby="admission-form-status">
        <section aria-labelledby="student-information-heading">
          <div className="mb-4">
            <h3 id="student-information-heading" className="font-semibold">
              Student Information
            </h3>
            <p className="text-sm text-muted-foreground">
              Use the student's official/current information. These details become part of the permanent student record.
            </p>
          </div>

          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            <Field id="student-name" label="Student Name (English)" required hint="Enter the full name used for academy records.">
              <Input id="student-name" name="name" className="h-10" autoComplete="name" required />
            </Field>

            <Field id="student-name-bn" label="Student Name (Bangla)" hint="Optional Bangla spelling for reports and print documents.">
              <Input id="student-name-bn" name="nameBn" className="h-10" />
            </Field>

            <Field id="student-gender" label="Gender" hint="Optional. Select the value used in the student's record.">
              <select id="student-gender" name="gender" className={selectClass}>
                <option value="">Select gender</option>
                <option value="Male">Male</option>
                <option value="Female">Female</option>
                <option value="Other">Other</option>
              </select>
            </Field>

            <Field id="student-dob" label="Date of Birth" hint="Use the documented date when available.">
              <Input id="student-dob" name="dateOfBirth" type="date" className="h-10" />
            </Field>

            <Field id="student-school" label="Current School" hint="Use the school's official name. Existing names are suggested as you type.">
              <Input id="student-school" name="schoolName" list="school-suggestions" className="h-10" autoComplete="off" />
              <datalist id="school-suggestions">
                {schoolSuggestions.map((school) => (
                  <option key={school} value={school} />
                ))}
              </datalist>
            </Field>

            <Field id="student-school-roll" label="School Roll" hint="The student's roll at the current school, if applicable.">
              <Input id="student-school-roll" name="schoolRoll" className="h-10" inputMode="numeric" />
            </Field>
          </div>
        </section>

        <section aria-labelledby="guardian-information-heading">
          <div className="mb-4">
            <h3 id="guardian-information-heading" className="font-semibold">
              Primary Guardian & Contact
            </h3>
            <p className="text-sm text-muted-foreground">
              Enter the person Sohoj Academy should contact first about attendance, progress, fees or emergencies.
            </p>
          </div>

          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            <Field id="guardian-name" label="Guardian Name" required>
              <Input id="guardian-name" name="guardianName" className="h-10" autoComplete="name" required />
            </Field>

            <Field id="guardian-relationship" label="Relationship to Student" required hint="Choose the relationship instead of typing different spellings.">
              <select id="guardian-relationship" name="relationship" required className={selectClass}>
                <option value="">Select relationship</option>
                <option value="Father">Father</option>
                <option value="Mother">Mother</option>
                <option value="Brother">Brother</option>
                <option value="Sister">Sister</option>
                <option value="Grandfather">Grandfather</option>
                <option value="Grandmother">Grandmother</option>
                <option value="Uncle">Uncle</option>
                <option value="Aunt">Aunt</option>
                <option value="Guardian">Other Guardian</option>
              </select>
            </Field>

            <Field id="guardian-mobile" label="Primary Mobile" required hint="Use the number the academy should call first.">
              <Input id="guardian-mobile" name="mobile" className="h-10" inputMode="tel" autoComplete="tel" required />
            </Field>

            <Field id="guardian-alt-mobile" label="Alternate / WhatsApp Mobile" hint="Optional backup contact number.">
              <Input id="guardian-alt-mobile" name="alternateMobile" className="h-10" inputMode="tel" autoComplete="tel" />
            </Field>

            <Field id="guardian-address" label="Address" wide hint="Current area/address useful for communication and future service analysis.">
              <Input id="guardian-address" name="address" className="h-10" autoComplete="street-address" />
            </Field>
          </div>
        </section>

        <section aria-labelledby="admission-fee-heading">
          <div className="mb-4">
            <h3 id="admission-fee-heading" className="font-semibold">
              Admission, Batch & Fee Terms
            </h3>
            <p className="text-sm text-muted-foreground">
              These are admission terms. Actual money received is recorded separately in Fee Collection and acknowledged by receipt.
            </p>
          </div>

          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            <Field id="academic-year" label="Academic Year" required hint="The active academic year is selected by default.">
              <select
                id="academic-year"
                name="academicYearId"
                required
                value={yearId}
                onChange={(event) => {
                  setYearId(event.target.value);
                  setBatchId("");
                }}
                className={selectClass}
              >
                <option value="">Select academic year</option>
                {academicYears.map((year) => (
                  <option key={year.id} value={year.id}>
                    {year.name}{year.is_active ? " — Active" : ""}
                  </option>
                ))}
              </select>
            </Field>

            <Field id="admission-class" label="Class" required>
              <select
                id="admission-class"
                name="classId"
                required
                value={classId}
                onChange={(event) => {
                  setClassId(event.target.value);
                  setBatchId("");
                }}
                className={selectClass}
              >
                <option value="">Select class</option>
                {classes.map((item) => (
                  <option key={item.id} value={item.id}>{item.name}</option>
                ))}
              </select>
            </Field>

            <Field id="admission-program" label="Program" hint="Optional when the student is not joining a special programme.">
              <select
                id="admission-program"
                name="programId"
                value={programId}
                onChange={(event) => {
                  setProgramId(event.target.value);
                  setBatchId("");
                }}
                className={selectClass}
              >
                <option value="">No specific program</option>
                {programs.map((item) => (
                  <option key={item.id} value={item.id}>{item.name}</option>
                ))}
              </select>
            </Field>

            <Field
              id="admission-batch"
              label="Batch"
              hint={
                classId
                  ? "Only batches matching the selected year/class/program are shown. Full batches cannot be selected."
                  : "Select a class first to narrow the available batches."
              }
            >
              <select
                id="admission-batch"
                name="batchId"
                value={batchId}
                onChange={(event) => setBatchId(event.target.value)}
                className={selectClass}
              >
                <option value="">Assign later / no batch yet</option>
                {availableBatches.map((batch) => {
                  const full = batch.enrolled >= batch.capacity;
                  return (
                    <option key={batch.id} value={batch.id} disabled={full}>
                      {batch.name} — {batch.enrolled}/{batch.capacity}{full ? " (Full)" : ""}
                    </option>
                  );
                })}
              </select>
            </Field>

            <Field id="admission-date" label="Admission Date" required hint="Date the student's admission is officially recorded.">
              <Input id="admission-date" name="admissionDate" type="date" defaultValue={todayLocal()} className="h-10" required />
            </Field>

            <Field id="monthly-fee" label="Standard Monthly Tuition (৳)" required hint="Monthly tuition before the approved discount.">
              <Input
                id="monthly-fee"
                name="monthlyFee"
                type="number"
                min="0"
                step="1"
                value={monthlyFee}
                onChange={(event) => setMonthlyFee(event.target.value)}
                className="h-10"
                required
              />
            </Field>

            <Field id="discount" label="Approved Monthly Discount (৳)" required hint="Enter 0 when there is no discount. Discount cannot exceed tuition.">
              <Input
                id="discount"
                name="discount"
                type="number"
                min="0"
                max={Number(monthlyFee || 0)}
                step="1"
                value={discount}
                onChange={(event) => setDiscount(event.target.value)}
                className="h-10"
                required
              />
            </Field>

            <div className="rounded-xl border bg-muted/20 p-4 md:col-span-2 lg:col-span-3" aria-live="polite">
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Calculated fee</p>
              <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <span className="text-xl font-bold">Net Monthly Fee: ৳{netMonthlyFee.toLocaleString()}</span>
                <span className="text-sm text-muted-foreground">
                  ৳{Number(monthlyFee || 0).toLocaleString()} tuition − ৳{Number(discount || 0).toLocaleString()} discount
                </span>
              </div>
              <p className="mt-1 text-xs text-muted-foreground">
                This records the fee term only. Use Fee Collection when money is actually received.
              </p>
            </div>
          </div>
        </section>

        <div id="admission-form-status" aria-live="polite" aria-atomic="true">
          {message && (
            <div
              role={message.ok ? "status" : "alert"}
              className={`rounded-xl border p-4 text-sm ${message.ok ? "border-green-600/40 bg-green-600/5" : "border-destructive/40 bg-destructive/5 text-destructive"}`}
            >
              <p className="font-medium">{message.text}</p>
              {message.ok && message.studentId && (
                <div className="mt-3 flex flex-wrap gap-2">
                  <Button asChild variant="outline" size="sm">
                    <Link href={`/dashboard/students/${message.studentId}`}>View student profile</Link>
                  </Button>
                  <Button type="button" variant="ghost" size="sm" onClick={resetAdmission}>
                    Create another admission
                  </Button>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
          <p className="text-xs text-muted-foreground sm:mr-auto">
            Review the student, guardian, batch and fee terms before creating the permanent record.
          </p>
          <Button type="submit" size="lg" className="min-h-11" disabled={isPending}>
            {isPending ? "Creating admission…" : "Review & Create Admission"}
          </Button>
        </div>
      </form>
    </div>
  );
}

function Field({
  id,
  label,
  children,
  hint,
  required = false,
  wide = false,
}: {
  id: string;
  label: string;
  children: React.ReactNode;
  hint?: string;
  required?: boolean;
  wide?: boolean;
}) {
  const hintId = hint ? `${id}-hint` : undefined;

  return (
    <div className={wide ? "md:col-span-2" : ""}>
      <div className="mb-2 flex items-center justify-between gap-2">
        <Label htmlFor={id}>{label}</Label>
        <span className="text-xs text-muted-foreground">{required ? "Required" : "Optional"}</span>
      </div>
      <div aria-describedby={hintId}>{children}</div>
      {hint && <p id={hintId} className="mt-1.5 text-xs leading-5 text-muted-foreground">{hint}</p>}
    </div>
  );
}
