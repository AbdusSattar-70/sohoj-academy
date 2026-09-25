"use client";

import { useRef, useState, useTransition, type ReactNode } from "react";
import Link from "next/link";
import { CheckCircle2, Send } from "lucide-react";
import { submitPublicInterest } from "@/app/actions/public-interest";
import { SmartSelect, type SmartSelectOption } from "@/components/shared/smart-select";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type Option = { id: string; name: string };

const relationships = [
  "Father",
  "Mother",
  "Brother",
  "Sister",
  "Grandfather",
  "Grandmother",
  "Uncle",
  "Aunt",
  "Other Guardian",
] as const;

const sourceOptions = [
  ["WALK_IN", "Walk-in / visited the academy"],
  ["SOCIAL", "Facebook / social media"],
  ["TEACHER_REFERRAL", "Teacher referral"],
  ["STUDENT_REFERRAL", "Student referral"],
  ["GUARDIAN_REFERRAL", "Guardian referral"],
  ["SCHOOL_VISIT", "School visit"],
  ["OFFLINE_CAMPAIGN", "Miking / leaflet"],
  ["OTHER", "Other"],
] as const;

const dayOptions = [
  ["SAT", "Sat"],
  ["SUN", "Sun"],
  ["MON", "Mon"],
  ["TUE", "Tue"],
  ["WED", "Wed"],
  ["THU", "Thu"],
  ["FRI", "Fri"],
] as const;

const selectClass =
  "h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-sm text-slate-950 outline-none transition focus:border-blue-600 focus:ring-3 focus:ring-blue-600/15";

export function PublicInterestForm({
  classes,
  programs,
  subjects,
  schools,
}: {
  classes: Option[];
  programs: Option[];
  subjects: Option[];
  schools: SmartSelectOption[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [isPending, startTransition] = useTransition();
  const [formVersion, setFormVersion] = useState(0);
  const [message, setMessage] = useState<
    { ok: boolean; text: string; prospectNo?: string | null } | null
  >(null);

  function submit(formData: FormData) {
    setMessage(null);

    const input = {
      studentName: String(formData.get("studentName") ?? ""),
      studentNameBn: String(formData.get("studentNameBn") ?? ""),
      guardianName: String(formData.get("guardianName") ?? ""),
      guardianRelationship: String(formData.get("guardianRelationship") ?? ""),
      mobile: String(formData.get("mobile") ?? ""),
      alternateMobile: String(formData.get("alternateMobile") ?? ""),
      classId: String(formData.get("classId") ?? ""),
      schoolId: String(formData.get("schoolId") ?? "") || undefined,
      schoolNameSnapshot: String(formData.get("schoolNameSnapshot") ?? ""),
      area: String(formData.get("area") ?? ""),
      preferredSchedule:
        (String(formData.get("preferredSchedule") ?? "") || undefined) as
          | "MORNING"
          | "AFTERNOON"
          | "EVENING"
          | "FLEXIBLE"
          | undefined,
      preferredDays: formData.getAll("preferredDays").map(String) as (
        | "SAT"
        | "SUN"
        | "MON"
        | "TUE"
        | "WED"
        | "THU"
        | "FRI"
      )[],
      trialInterest: formData.get("trialInterest") === "on",
      programIds: formData.getAll("programIds").map(String),
      subjectIds: formData.getAll("subjectIds").map(String),
      sourceCode:
        (String(formData.get("sourceCode") ?? "") || undefined) as
          | "WALK_IN"
          | "SOCIAL"
          | "TEACHER_REFERRAL"
          | "STUDENT_REFERRAL"
          | "GUARDIAN_REFERRAL"
          | "SCHOOL_VISIT"
          | "OFFLINE_CAMPAIGN"
          | "OTHER"
          | undefined,
      referralNote: String(formData.get("referralNote") ?? ""),
      notes: String(formData.get("notes") ?? ""),
      consentToContact: formData.get("consentToContact") === "on",
      website: String(formData.get("website") ?? ""),
    };

    startTransition(async () => {
      const result = await submitPublicInterest(input);

      if (result.ok) {
        setMessage({
          ok: true,
          prospectNo: result.prospectNo,
          text:
            "Thank you. Your interest has been recorded. Sohoj Academy can now follow up using the contact information you provided.",
        });
        formRef.current?.reset();
        setFormVersion((value) => value + 1);
        window.scrollTo({ top: 0, behavior: "smooth" });
      } else {
        setMessage({ ok: false, text: result.error });
      }
    });
  }

  return (
    <div className="space-y-6">
      <div aria-live="polite" aria-atomic="true">
        {message && (
          <div
            role={message.ok ? "status" : "alert"}
            className={
              message.ok
                ? "rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-950"
                : "rounded-2xl border border-red-200 bg-red-50 p-5 text-red-800"
            }
          >
            {message.ok && (
              <CheckCircle2 className="mb-3 size-6 text-emerald-700" aria-hidden="true" />
            )}
            <p className="font-semibold">{message.ok ? "Interest recorded" : "Please check the form"}</p>
            <p className="mt-1 text-sm leading-6">{message.text}</p>
            {message.ok && message.prospectNo && (
              <p className="mt-3 text-sm">
                Reference: <span className="font-bold">{message.prospectNo}</span>
              </p>
            )}
            {message.ok && (
              <Link
                href="/"
                className="mt-4 inline-flex text-sm font-semibold underline underline-offset-4"
              >
                Return to Sohoj Academy
              </Link>
            )}
          </div>
        )}
      </div>

      <form ref={formRef} action={submit} className="space-y-8">
        <div className="sr-only" aria-hidden="true">
          <label htmlFor="website">Website</label>
          <input id="website" name="website" tabIndex={-1} autoComplete="off" />
        </div>

        <section aria-labelledby="interest-student-heading">
          <SectionHeading
            id="interest-student-heading"
            title="Student information"
            description="Tell us who the student is and what they are currently studying."
          />
          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-student-name" label="Student Name (English)" required>
              <Input
                id="interest-student-name"
                name="studentName"
                className="h-11"
                autoComplete="name"
                required
              />
            </Field>

            <Field id="interest-student-name-bn" label="Student Name (Bangla)">
              <Input id="interest-student-name-bn" name="studentNameBn" className="h-11" />
            </Field>

            <Field
              id="interest-class"
              label="Current Class"
              required
              hint="Choose the class the student is studying in now."
            >
              <select id="interest-class" name="classId" className={selectClass} required>
                <option value="">Select current class</option>
                {classes.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.name}
                  </option>
                ))}
              </select>
            </Field>

            <div key={formVersion}>
              <SmartSelect
                name="schoolId"
                snapshotName="schoolNameSnapshot"
                label="Current School"
                options={schools}
                placeholder="Start typing the school name"
                hint="Choose an existing school when suggested. If it is not listed, type the official school name once; staff can verify it later."
              />
            </div>

            <Field
              id="interest-area"
              label="Area / Locality"
              hint="Your area helps us understand where students are coming from."
            >
              <Input
                id="interest-area"
                name="area"
                className="h-11"
                placeholder="e.g. Gopalpur Bazar"
                autoComplete="address-level3"
              />
            </Field>
          </div>
        </section>

        <section aria-labelledby="interest-guardian-heading">
          <SectionHeading
            id="interest-guardian-heading"
            title="Guardian & contact"
            description="Use a mobile number that Sohoj Academy can reliably contact."
          />
          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-guardian-name" label="Guardian Name" required>
              <Input
                id="interest-guardian-name"
                name="guardianName"
                className="h-11"
                autoComplete="name"
                required
              />
            </Field>

            <Field id="interest-relationship" label="Relationship to Student">
              <select id="interest-relationship" name="guardianRelationship" className={selectClass}>
                <option value="">Select relationship</option>
                {relationships.map((relationship) => (
                  <option key={relationship} value={relationship}>
                    {relationship}
                  </option>
                ))}
              </select>
            </Field>

            <Field id="interest-mobile" label="Primary Mobile" required>
              <Input
                id="interest-mobile"
                name="mobile"
                className="h-11"
                inputMode="tel"
                autoComplete="tel"
                required
              />
            </Field>

            <Field id="interest-alt-mobile" label="Alternate / WhatsApp Mobile">
              <Input
                id="interest-alt-mobile"
                name="alternateMobile"
                className="h-11"
                inputMode="tel"
                autoComplete="tel"
              />
            </Field>
          </div>
        </section>

        <section aria-labelledby="interest-program-heading">
          <SectionHeading
            id="interest-program-heading"
            title="What are you interested in?"
            description="You can select more than one programme or subject. This does not confirm admission."
          />

          <fieldset>
            <legend className="text-sm font-semibold text-slate-900">Programs</legend>
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              {programs.length ? (
                programs.map((program) => (
                  <CheckOption
                    key={program.id}
                    name="programIds"
                    value={program.id}
                    label={program.name}
                  />
                ))
              ) : (
                <p className="text-sm text-slate-500">Programme choices will be discussed during follow-up.</p>
              )}
            </div>
          </fieldset>

          <fieldset className="mt-6">
            <legend className="text-sm font-semibold text-slate-900">Subjects</legend>
            <p className="mt-1 text-xs leading-5 text-slate-500">
              Select the subjects where the student may need support.
            </p>
            <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {subjects.length ? (
                subjects.map((subject) => (
                  <CheckOption
                    key={subject.id}
                    name="subjectIds"
                    value={subject.id}
                    label={subject.name}
                  />
                ))
              ) : (
                <p className="text-sm text-slate-500">Subject choices will be discussed during follow-up.</p>
              )}
            </div>
          </fieldset>
        </section>

        <section aria-labelledby="interest-preference-heading">
          <SectionHeading
            id="interest-preference-heading"
            title="Schedule & follow-up preferences"
            description="These preferences help us plan suitable batches and future demand."
          />

          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-schedule" label="Preferred Class Time">
              <select id="interest-schedule" name="preferredSchedule" className={selectClass}>
                <option value="">No preference</option>
                <option value="MORNING">Morning</option>
                <option value="AFTERNOON">Afternoon</option>
                <option value="EVENING">Evening</option>
                <option value="FLEXIBLE">Flexible</option>
              </select>
            </Field>

            <Field id="interest-source" label="How did you hear about Sohoj Academy?">
              <select id="interest-source" name="sourceCode" className={selectClass}>
                <option value="">Select if known</option>
                {sourceOptions.map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
            </Field>
          </div>

          <fieldset className="mt-6">
            <legend className="text-sm font-semibold text-slate-900">Preferred days</legend>
            <p className="mt-1 text-xs text-slate-500">Optional. Select any days that are usually convenient.</p>
            <div className="mt-3 flex flex-wrap gap-2">
              {dayOptions.map(([value, label]) => (
                <label
                  key={value}
                  className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm hover:bg-slate-50"
                >
                  <input
                    type="checkbox"
                    name="preferredDays"
                    value={value}
                    className="size-4 accent-blue-700"
                  />
                  <span>{label}</span>
                </label>
              ))}
            </div>
          </fieldset>

          <div className="mt-6 grid gap-5">
            <label className="flex cursor-pointer items-start gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <input
                type="checkbox"
                name="trialInterest"
                className="mt-0.5 size-4 accent-blue-700"
              />
              <span>
                <span className="block text-sm font-semibold text-slate-900">
                  Interested in a trial / orientation class
                </span>
                <span className="mt-1 block text-xs leading-5 text-slate-500">
                  This is only an interest request; availability will be confirmed separately.
                </span>
              </span>
            </label>

            <Field
              id="interest-referral"
              label="Referral details"
              hint="If a teacher, student or guardian referred you, write their name here."
            >
              <Input
                id="interest-referral"
                name="referralNote"
                className="h-11"
                placeholder="Referrer name, if applicable"
              />
            </Field>

            <Field
              id="interest-notes"
              label="Anything you want us to know?"
              hint="Optional. Mention a learning concern, preferred programme or other useful context."
            >
              <textarea
                id="interest-notes"
                name="notes"
                rows={4}
                className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-blue-600 focus:ring-3 focus:ring-blue-600/15"
                placeholder="Optional note"
              />
            </Field>
          </div>
        </section>

        <section className="rounded-2xl border border-blue-100 bg-blue-50 p-5">
          <label className="flex cursor-pointer items-start gap-3">
            <input
              type="checkbox"
              name="consentToContact"
              required
              className="mt-1 size-4 accent-blue-700"
            />
            <span className="text-sm leading-6 text-blue-950">
              I allow Sohoj Academy to contact me about this interest request and related academic programmes.
              <span className="ml-1 font-semibold">Required</span>
            </span>
          </label>
          <p className="mt-3 text-xs leading-5 text-blue-900/70">
            Submitting this form records an expression of interest. It is not an admission confirmation and does not create a student account or payment obligation.
          </p>
        </section>

        <div className="flex flex-col gap-3 border-t border-slate-200 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="max-w-xl text-xs leading-5 text-slate-500">
            Please review the mobile number and current class before submitting so our follow-up is useful.
          </p>
          <button
            type="submit"
            disabled={isPending}
            className="inline-flex min-h-12 shrink-0 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Send className="size-4" aria-hidden="true" />
            {isPending ? "Submitting…" : "Submit Interest"}
          </button>
        </div>
      </form>
    </div>
  );
}

function SectionHeading({
  id,
  title,
  description,
}: {
  id: string;
  title: string;
  description: string;
}) {
  return (
    <div className="mb-5">
      <h2 id={id} className="text-lg font-semibold tracking-tight text-slate-950">
        {title}
      </h2>
      <p className="mt-1 text-sm leading-6 text-slate-500">{description}</p>
    </div>
  );
}

function Field({
  id,
  label,
  hint,
  required = false,
  children,
}: {
  id: string;
  label: string;
  hint?: string;
  required?: boolean;
  children: ReactNode;
}) {
  const hintId = hint ? `${id}-hint` : undefined;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-3">
        <Label htmlFor={id}>{label}</Label>
        <span className="text-xs text-slate-500">{required ? "Required" : "Optional"}</span>
      </div>
      <div aria-describedby={hintId}>{children}</div>
      {hint && (
        <p id={hintId} className="mt-1.5 text-xs leading-5 text-slate-500">
          {hint}
        </p>
      )}
    </div>
  );
}

function CheckOption({
  name,
  value,
  label,
}: {
  name: string;
  value: string;
  label: string;
}) {
  return (
    <label className="flex min-h-11 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-800 hover:bg-slate-50">
      <input type="checkbox" name={name} value={value} className="size-4 accent-blue-700" />
      <span>{label}</span>
    </label>
  );
}
