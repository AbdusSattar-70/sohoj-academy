"use client";

import { useRef, useState, useTransition, type ReactNode } from "react";
import Link from "next/link";
import { CheckCircle2, Send } from "lucide-react";
import { submitPublicInterest } from "@/app/actions/public-interest";
import { SmartSelect, type SmartSelectOption } from "@/components/shared/smart-select";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useLanguage } from "@/components/providers/language-provider";

type Option = { id: string; name: string };

const relationships = [
  ["Father", "পিতা"],
  ["Mother", "মাতা"],
  ["Brother", "ভাই"],
  ["Sister", "বোন"],
  ["Grandfather", "দাদা/নানা"],
  ["Grandmother", "দাদি/নানি"],
  ["Uncle", "চাচা/মামা"],
  ["Aunt", "ফুফু/খালা"],
  ["Other Guardian", "অন্যান্য অভিভাবক"],
] as const;

const sourceOptions = [
  ["WALK_IN", "Walk-in / visited the academy", "সরাসরি একাডেমিতে এসেছেন"],
  ["SOCIAL", "Facebook / social media", "ফেসবুক / সামাজিক মাধ্যম"],
  ["TEACHER_REFERRAL", "Teacher referral", "শিক্ষকের রেফারেল"],
  ["STUDENT_REFERRAL", "Student referral", "শিক্ষার্থীর রেফারেল"],
  ["GUARDIAN_REFERRAL", "Guardian referral", "অভিভাবকের রেফারেল"],
  ["SCHOOL_VISIT", "School visit", "স্কুল ভিজিট"],
  ["OFFLINE_CAMPAIGN", "Miking / leaflet", "মাইকিং / লিফলেট"],
  ["OTHER", "Other", "অন্যান্য"],
] as const;

const dayOptions = [
  ["SAT", "Sat", "শনি"],
  ["SUN", "Sun", "রবি"],
  ["MON", "Mon", "সোম"],
  ["TUE", "Tue", "মঙ্গল"],
  ["WED", "Wed", "বুধ"],
  ["THU", "Thu", "বৃহঃ"],
  ["FRI", "Fri", "শুক্র"],
] as const;

const selectClass =
  "h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none transition focus:border-ring focus:ring-3 focus:ring-ring/20";

const bnErrorMap: Record<string, string> = {
  "Enter the student's name.": "শিক্ষার্থীর নাম লিখুন।",
  "Enter the guardian's name.": "অভিভাবকের নাম লিখুন।",
  "Enter a valid mobile number.": "সঠিক মোবাইল নম্বর লিখুন।",
  "Select the student's current class.": "শিক্ষার্থীর বর্তমান ক্লাস নির্বাচন করুন।",
  "Please allow Sohoj Academy to contact you about this interest request.":
    "এই আগ্রহ নিবন্ধন সম্পর্কে সহজ একাডেমিকে যোগাযোগের অনুমতি দিন।",
  "A similar interest request was submitted recently. Please wait before submitting again.":
    "একই ধরনের আগ্রহ নিবন্ধন অল্প কিছুক্ষণ আগে জমা হয়েছে। আবার জমা দেওয়ার আগে কিছুক্ষণ অপেক্ষা করুন।",
};

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
  const { locale } = useLanguage();
  const bn = locale === "bn";
  const formRef = useRef<HTMLFormElement>(null);
  const [isPending, startTransition] = useTransition();
  const [formVersion, setFormVersion] = useState(0);
  const [message, setMessage] = useState<
    { ok: boolean; text: string; prospectNo?: string | null } | null
  >(null);

  const copy = {
    required: bn ? "আবশ্যক" : "Required",
    optional: bn ? "ঐচ্ছিক" : "Optional",
    successTitle: bn ? "আগ্রহ নিবন্ধিত হয়েছে" : "Interest recorded",
    errorTitle: bn ? "ফর্মটি যাচাই করুন" : "Please check the form",
    successText: bn
      ? "ধন্যবাদ। আপনার আগ্রহ নিবন্ধিত হয়েছে। দেওয়া যোগাযোগের তথ্য ব্যবহার করে সহজ একাডেমি ফলো-আপ করতে পারবে।"
      : "Thank you. Your interest has been recorded. Sohoj Academy can now follow up using the contact information you provided.",
    reference: bn ? "রেফারেন্স" : "Reference",
    returnHome: bn ? "সহজ একাডেমিতে ফিরুন" : "Return to Sohoj Academy",
    studentHeading: bn ? "শিক্ষার্থীর তথ্য" : "Student information",
    studentDesc: bn
      ? "শিক্ষার্থী কে এবং বর্তমানে কী পড়ছে তা জানান।"
      : "Tell us who the student is and what they are currently studying.",
    studentNameEn: bn ? "শিক্ষার্থীর নাম (ইংরেজি)" : "Student Name (English)",
    studentNameBn: bn ? "শিক্ষার্থীর নাম (বাংলা)" : "Student Name (Bangla)",
    currentClass: bn ? "বর্তমান ক্লাস" : "Current Class",
    currentClassHint: bn
      ? "শিক্ষার্থী বর্তমানে যে ক্লাসে পড়ছে সেটি নির্বাচন করুন।"
      : "Choose the class the student is studying in now.",
    selectClass: bn ? "বর্তমান ক্লাস নির্বাচন করুন" : "Select current class",
    currentSchool: bn ? "বর্তমান স্কুল" : "Current School",
    schoolPlaceholder: bn ? "স্কুলের নাম লিখতে শুরু করুন" : "Start typing the school name",
    schoolHint: bn
      ? "তালিকায় থাকলে বিদ্যমান স্কুলটি নির্বাচন করুন। না থাকলে অফিসিয়াল নাম লিখুন; পরে স্টাফ যাচাই করতে পারবেন।"
      : "Choose an existing school when suggested. If it is not listed, type the official school name once; staff can verify it later.",
    area: bn ? "এলাকা / লোকেশন" : "Area / Locality",
    areaHint: bn
      ? "এলাকার তথ্য ভবিষ্যৎ শিক্ষার্থী চাহিদা বুঝতে সাহায্য করে।"
      : "Your area helps us understand where students are coming from.",
    guardianHeading: bn ? "অভিভাবক ও যোগাযোগ" : "Guardian & contact",
    guardianDesc: bn
      ? "এমন মোবাইল নম্বর দিন যেখানে সহজ একাডেমি নির্ভরযোগ্যভাবে যোগাযোগ করতে পারবে।"
      : "Use a mobile number that Sohoj Academy can reliably contact.",
    guardianName: bn ? "অভিভাবকের নাম" : "Guardian Name",
    relationship: bn ? "শিক্ষার্থীর সঙ্গে সম্পর্ক" : "Relationship to Student",
    selectRelationship: bn ? "সম্পর্ক নির্বাচন করুন" : "Select relationship",
    primaryMobile: bn ? "প্রধান মোবাইল" : "Primary Mobile",
    altMobile: bn ? "বিকল্প / WhatsApp মোবাইল" : "Alternate / WhatsApp Mobile",
    interestHeading: bn ? "কোন বিষয়ে আগ্রহী?" : "What are you interested in?",
    interestDesc: bn
      ? "একাধিক প্রোগ্রাম বা বিষয় নির্বাচন করা যাবে। এটি ভর্তি নিশ্চিত করে না।"
      : "You can select more than one programme or subject. This does not confirm admission.",
    programs: bn ? "প্রোগ্রামসমূহ" : "Programs",
    programsEmpty: bn
      ? "ফলো-আপের সময় প্রোগ্রাম নির্বাচন নিয়ে আলোচনা করা হবে।"
      : "Programme choices will be discussed during follow-up.",
    subjects: bn ? "বিষয়সমূহ" : "Subjects",
    subjectsHint: bn
      ? "যেসব বিষয়ে শিক্ষার্থীর সহায়তা প্রয়োজন হতে পারে সেগুলো নির্বাচন করুন।"
      : "Select the subjects where the student may need support.",
    subjectsEmpty: bn
      ? "ফলো-আপের সময় বিষয় নির্বাচন নিয়ে আলোচনা করা হবে।"
      : "Subject choices will be discussed during follow-up.",
    preferenceHeading: bn ? "সময় ও ফলো-আপ পছন্দ" : "Schedule & follow-up preferences",
    preferenceDesc: bn
      ? "এই তথ্য উপযুক্ত ব্যাচ পরিকল্পনা এবং ভবিষ্যৎ চাহিদা বুঝতে সাহায্য করে।"
      : "These preferences help us plan suitable batches and future demand.",
    classTime: bn ? "পছন্দের ক্লাস সময়" : "Preferred Class Time",
    noPreference: bn ? "কোনো নির্দিষ্ট পছন্দ নেই" : "No preference",
    morning: bn ? "সকাল" : "Morning",
    afternoon: bn ? "দুপুর" : "Afternoon",
    evening: bn ? "সন্ধ্যা" : "Evening",
    flexible: bn ? "যেকোনো সময়" : "Flexible",
    source: bn ? "সহজ একাডেমি সম্পর্কে কীভাবে জেনেছেন?" : "How did you hear about Sohoj Academy?",
    selectKnown: bn ? "জানা থাকলে নির্বাচন করুন" : "Select if known",
    preferredDays: bn ? "পছন্দের দিন" : "Preferred days",
    preferredDaysHint: bn
      ? "ঐচ্ছিক। সাধারণত সুবিধাজনক দিনগুলো নির্বাচন করুন।"
      : "Optional. Select any days that are usually convenient.",
    trialTitle: bn ? "ট্রায়াল / ওরিয়েন্টেশন ক্লাসে আগ্রহী" : "Interested in a trial / orientation class",
    trialDesc: bn
      ? "এটি শুধু আগ্রহ নিবন্ধন; সময় ও আসন আলাদাভাবে নিশ্চিত করা হবে।"
      : "This is only an interest request; availability will be confirmed separately.",
    referral: bn ? "রেফারেল তথ্য" : "Referral details",
    referralHint: bn
      ? "কোনো শিক্ষক, শিক্ষার্থী বা অভিভাবক রেফার করলে তার নাম লিখুন।"
      : "If a teacher, student or guardian referred you, write their name here.",
    referralPlaceholder: bn ? "রেফারকারীর নাম, প্রযোজ্য হলে" : "Referrer name, if applicable",
    notes: bn ? "আর কিছু জানাতে চান?" : "Anything you want us to know?",
    notesHint: bn
      ? "ঐচ্ছিক। শেখার সমস্যা, পছন্দের প্রোগ্রাম বা প্রয়োজনীয় অন্য তথ্য লিখুন।"
      : "Optional. Mention a learning concern, preferred programme or other useful context.",
    notesPlaceholder: bn ? "ঐচ্ছিক নোট" : "Optional note",
    consent: bn
      ? "এই আগ্রহ নিবন্ধন এবং সংশ্লিষ্ট একাডেমিক প্রোগ্রাম সম্পর্কে সহজ একাডেমিকে আমার সঙ্গে যোগাযোগের অনুমতি দিচ্ছি।"
      : "I allow Sohoj Academy to contact me about this interest request and related academic programmes.",
    consentNote: bn
      ? "এই ফর্ম জমা দিলে শুধু আগ্রহের রেকর্ড তৈরি হবে। এটি ভর্তি নিশ্চিত করে না, Student ID তৈরি করে না এবং কোনো অর্থ প্রদানের দায় সৃষ্টি করে না।"
      : "Submitting this form records an expression of interest. It is not an admission confirmation and does not create a student account or payment obligation.",
    review: bn
      ? "জমা দেওয়ার আগে মোবাইল নম্বর ও বর্তমান ক্লাস যাচাই করুন, যাতে ফলো-আপ সঠিকভাবে করা যায়।"
      : "Please review the mobile number and current class before submitting so our follow-up is useful.",
    submit: bn ? "আগ্রহ জমা দিন" : "Submit Interest",
    submitting: bn ? "জমা হচ্ছে…" : "Submitting…",
  };

  function translateError(error: string) {
    if (!bn) return error;
    const exact = bnErrorMap[error];
    if (exact) return exact;
    const partial = Object.entries(bnErrorMap).find(([english]) => error.includes(english));
    return partial?.[1] ?? "তথ্য সংরক্ষণ করা যায়নি। অনুগ্রহ করে আবার চেষ্টা করুন।";
  }

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
          text: copy.successText,
        });
        formRef.current?.reset();
        setFormVersion((value) => value + 1);
        window.scrollTo({ top: 0, behavior: "smooth" });
      } else {
        setMessage({ ok: false, text: translateError(result.error) });
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
                ? "rounded-2xl border border-emerald-300 bg-emerald-50 p-5 text-emerald-950 dark:border-emerald-900 dark:bg-emerald-950/30 dark:text-emerald-100"
                : "rounded-2xl border border-destructive/30 bg-destructive/10 p-5 text-destructive"
            }
          >
            {message.ok && (
              <CheckCircle2 className="mb-3 size-6 text-emerald-700 dark:text-emerald-300" aria-hidden="true" />
            )}
            <p className="font-semibold">{message.ok ? copy.successTitle : copy.errorTitle}</p>
            <p className="mt-1 text-sm leading-6">{message.text}</p>
            {message.ok && message.prospectNo && (
              <p className="mt-3 text-sm">
                {copy.reference}: <span className="font-bold">{message.prospectNo}</span>
              </p>
            )}
            {message.ok && (
              <Link href="/" className="mt-4 inline-flex text-sm font-semibold underline underline-offset-4">
                {copy.returnHome}
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
            title={copy.studentHeading}
            description={copy.studentDesc}
          />
          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-student-name" label={copy.studentNameEn} required requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-student-name" name="studentName" className="h-11" autoComplete="name" required />
            </Field>

            <Field id="interest-student-name-bn" label={copy.studentNameBn} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-student-name-bn" name="studentNameBn" className="h-11" />
            </Field>

            <Field
              id="interest-class"
              label={copy.currentClass}
              required
              hint={copy.currentClassHint}
              requiredLabel={copy.required}
              optionalLabel={copy.optional}
            >
              <select id="interest-class" name="classId" className={selectClass} required>
                <option value="">{copy.selectClass}</option>
                {classes.map((item) => (
                  <option key={item.id} value={item.id}>{item.name}</option>
                ))}
              </select>
            </Field>

            <div key={formVersion}>
              <SmartSelect
                name="schoolId"
                snapshotName="schoolNameSnapshot"
                label={copy.currentSchool}
                options={schools}
                placeholder={copy.schoolPlaceholder}
                hint={copy.schoolHint}
              />
            </div>

            <Field
              id="interest-area"
              label={copy.area}
              hint={copy.areaHint}
              requiredLabel={copy.required}
              optionalLabel={copy.optional}
            >
              <Input
                id="interest-area"
                name="area"
                className="h-11"
                placeholder={bn ? "যেমন: গোপালপুর বাজার" : "e.g. Gopalpur Bazar"}
                autoComplete="address-level3"
              />
            </Field>
          </div>
        </section>

        <section aria-labelledby="interest-guardian-heading">
          <SectionHeading
            id="interest-guardian-heading"
            title={copy.guardianHeading}
            description={copy.guardianDesc}
          />
          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-guardian-name" label={copy.guardianName} required requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-guardian-name" name="guardianName" className="h-11" autoComplete="name" required />
            </Field>

            <Field id="interest-relationship" label={copy.relationship} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <select id="interest-relationship" name="guardianRelationship" className={selectClass}>
                <option value="">{copy.selectRelationship}</option>
                {relationships.map(([value, bnLabel]) => (
                  <option key={value} value={value}>{bn ? bnLabel : value}</option>
                ))}
              </select>
            </Field>

            <Field id="interest-mobile" label={copy.primaryMobile} required requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-mobile" name="mobile" className="h-11" inputMode="tel" autoComplete="tel" required />
            </Field>

            <Field id="interest-alt-mobile" label={copy.altMobile} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-alt-mobile" name="alternateMobile" className="h-11" inputMode="tel" autoComplete="tel" />
            </Field>
          </div>
        </section>

        <section aria-labelledby="interest-program-heading">
          <SectionHeading
            id="interest-program-heading"
            title={copy.interestHeading}
            description={copy.interestDesc}
          />

          <fieldset>
            <legend className="text-sm font-semibold">{copy.programs}</legend>
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              {programs.length ? (
                programs.map((program) => (
                  <CheckOption key={program.id} name="programIds" value={program.id} label={program.name} />
                ))
              ) : (
                <p className="text-sm text-muted-foreground">{copy.programsEmpty}</p>
              )}
            </div>
          </fieldset>

          <fieldset className="mt-6">
            <legend className="text-sm font-semibold">{copy.subjects}</legend>
            <p className="mt-1 text-xs leading-5 text-muted-foreground">{copy.subjectsHint}</p>
            <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {subjects.length ? (
                subjects.map((subject) => (
                  <CheckOption key={subject.id} name="subjectIds" value={subject.id} label={subject.name} />
                ))
              ) : (
                <p className="text-sm text-muted-foreground">{copy.subjectsEmpty}</p>
              )}
            </div>
          </fieldset>
        </section>

        <section aria-labelledby="interest-preference-heading">
          <SectionHeading
            id="interest-preference-heading"
            title={copy.preferenceHeading}
            description={copy.preferenceDesc}
          />

          <div className="grid gap-5 md:grid-cols-2">
            <Field id="interest-schedule" label={copy.classTime} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <select id="interest-schedule" name="preferredSchedule" className={selectClass}>
                <option value="">{copy.noPreference}</option>
                <option value="MORNING">{copy.morning}</option>
                <option value="AFTERNOON">{copy.afternoon}</option>
                <option value="EVENING">{copy.evening}</option>
                <option value="FLEXIBLE">{copy.flexible}</option>
              </select>
            </Field>

            <Field id="interest-source" label={copy.source} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <select id="interest-source" name="sourceCode" className={selectClass}>
                <option value="">{copy.selectKnown}</option>
                {sourceOptions.map(([value, enLabel, bnLabel]) => (
                  <option key={value} value={value}>{bn ? bnLabel : enLabel}</option>
                ))}
              </select>
            </Field>
          </div>

          <fieldset className="mt-6">
            <legend className="text-sm font-semibold">{copy.preferredDays}</legend>
            <p className="mt-1 text-xs text-muted-foreground">{copy.preferredDaysHint}</p>
            <div className="mt-3 flex flex-wrap gap-2">
              {dayOptions.map(([value, enLabel, bnLabel]) => (
                <label
                  key={value}
                  className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border border-border bg-background px-3 py-2 text-sm hover:bg-muted"
                >
                  <input type="checkbox" name="preferredDays" value={value} className="size-4 accent-blue-700" />
                  <span>{bn ? bnLabel : enLabel}</span>
                </label>
              ))}
            </div>
          </fieldset>

          <div className="mt-6 grid gap-5">
            <label className="flex cursor-pointer items-start gap-3 rounded-2xl border border-border bg-muted/50 p-4">
              <input type="checkbox" name="trialInterest" className="mt-0.5 size-4 accent-blue-700" />
              <span>
                <span className="block text-sm font-semibold">{copy.trialTitle}</span>
                <span className="mt-1 block text-xs leading-5 text-muted-foreground">{copy.trialDesc}</span>
              </span>
            </label>

            <Field id="interest-referral" label={copy.referral} hint={copy.referralHint} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <Input id="interest-referral" name="referralNote" className="h-11" placeholder={copy.referralPlaceholder} />
            </Field>

            <Field id="interest-notes" label={copy.notes} hint={copy.notesHint} requiredLabel={copy.required} optionalLabel={copy.optional}>
              <textarea
                id="interest-notes"
                name="notes"
                rows={4}
                className="w-full rounded-xl border border-input bg-background px-3 py-2.5 text-sm text-foreground outline-none transition focus:border-ring focus:ring-3 focus:ring-ring/20"
                placeholder={copy.notesPlaceholder}
              />
            </Field>
          </div>
        </section>

        <section className="rounded-2xl border border-blue-200 bg-blue-50 p-5 text-blue-950 dark:border-blue-900 dark:bg-blue-950/30 dark:text-blue-100">
          <label className="flex cursor-pointer items-start gap-3">
            <input type="checkbox" name="consentToContact" required className="mt-1 size-4 accent-blue-700" />
            <span className="text-sm leading-6">
              {copy.consent}
              <span className="ml-1 font-semibold">{copy.required}</span>
            </span>
          </label>
          <p className="mt-3 text-xs leading-5 opacity-75">{copy.consentNote}</p>
        </section>

        <div className="flex flex-col gap-3 border-t border-border pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="max-w-xl text-xs leading-5 text-muted-foreground">{copy.review}</p>
          <button
            type="submit"
            disabled={isPending}
            className="inline-flex min-h-12 shrink-0 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Send className="size-4" aria-hidden="true" />
            {isPending ? copy.submitting : copy.submit}
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
      <h2 id={id} className="text-lg font-semibold tracking-tight">{title}</h2>
      <p className="mt-1 text-sm leading-6 text-muted-foreground">{description}</p>
    </div>
  );
}

function Field({
  id,
  label,
  hint,
  required = false,
  requiredLabel,
  optionalLabel,
  children,
}: {
  id: string;
  label: string;
  hint?: string;
  required?: boolean;
  requiredLabel: string;
  optionalLabel: string;
  children: ReactNode;
}) {
  const hintId = hint ? `${id}-hint` : undefined;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-3">
        <Label htmlFor={id}>{label}</Label>
        <span className="text-xs text-muted-foreground">
          {required ? requiredLabel : optionalLabel}
        </span>
      </div>
      <div aria-describedby={hintId}>{children}</div>
      {hint && (
        <p id={hintId} className="mt-1.5 text-xs leading-5 text-muted-foreground">{hint}</p>
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
    <label className="flex min-h-11 cursor-pointer items-center gap-3 rounded-xl border border-border bg-background px-3 py-2.5 text-sm hover:bg-muted">
      <input type="checkbox" name={name} value={value} className="size-4 accent-blue-700" />
      <span>{label}</span>
    </label>
  );
}
