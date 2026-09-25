"use client";

import { useRef, useState, useTransition, type FormEvent, type ReactNode } from "react";
import {
  createAssessment,
  createNotice,
  recordPayment,
} from "@/app/actions/transactions";
import { createFeeStructure } from "@/app/actions/operations";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FormField, FormStatus } from "@/components/shared/form-field";
import { WorkflowHelp } from "@/components/shared/workflow-help";
import { useLanguage } from "@/components/providers/language-provider";

type Option = { id: string; name: string };
type Feedback = { ok: boolean; text: string } | null;

const selectClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none transition focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/30";

function useCopy() {
  const { locale } = useLanguage();
  const bn = locale === "bn";
  const tr = (en: string, bnText: string) => (bn ? bnText : en);
  return { bn, tr };
}

export function FeeManager({
  years,
  classes,
  programs,
  fees,
}: {
  years: Option[];
  classes: Option[];
  programs: Option[];
  fees: { id: string; title: string; amount: number; frequency: string }[];
}) {
  const { tr } = useCopy();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createFeeStructure(formData);
      if (result.ok) {
        form.reset();
        setMessage({
          ok: true,
          text: tr(
            "Fee structure added successfully.",
            "ফি কাঠামো সফলভাবে যোগ করা হয়েছে।"
          ),
        });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Fee structure could not be saved.", "ফি কাঠামো সংরক্ষণ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Box title={tr("Fee Structure", "ফি কাঠামো")}>
      <WorkflowHelp
        title={tr("How to use this page", "এই পেজ কীভাবে ব্যবহার করবেন")}
        steps={[
          tr(
            "Create the standard tuition rule before assigning student-specific discounts.",
            "শিক্ষার্থীভিত্তিক discount দেওয়ার আগে standard tuition rule তৈরি করুন।"
          ),
          tr(
            "Choose the Academic Year first, then narrow the rule by Class or Program only when needed.",
            "প্রথমে Academic Year নির্বাচন করুন; প্রয়োজন হলে Class বা Program অনুযায়ী rule সীমিত করুন।"
          ),
          tr(
            "Actual money received is recorded separately in Fee Collection.",
            "বাস্তবে পাওয়া অর্থ আলাদাভাবে Fee Collection-এ রেকর্ড হবে।"
          ),
        ]}
      />

      <form onSubmit={submit} className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <FormField
          id="fee-title"
          label={tr("Fee Rule Name", "ফি রুলের নাম")}
          required
          hint={tr(
            'Example: "Monthly Tuition — Class 8".',
            'উদাহরণ: "Monthly Tuition — Class 8"।'
          )}
        >
          <Input id="fee-title" name="title" className="min-h-11" required />
        </FormField>

        <SelectField
          id="fee-year"
          name="academic_year_id"
          label={tr("Academic Year", "শিক্ষাবর্ষ")}
          items={years}
          placeholder={tr("Select academic year", "শিক্ষাবর্ষ নির্বাচন করুন")}
          required
        />

        <SelectField
          id="fee-class"
          name="class_id"
          label={tr("Class", "ক্লাস")}
          items={classes}
          placeholder={tr("All classes / not restricted", "সকল ক্লাস / সীমাবদ্ধ নয়")}
          hint={tr(
            "Leave empty when the rule is not class-specific.",
            "ফি রুলটি কোনো নির্দিষ্ট ক্লাসের জন্য না হলে ফাঁকা রাখুন।"
          )}
        />

        <SelectField
          id="fee-program"
          name="program_id"
          label={tr("Program", "প্রোগ্রাম")}
          items={programs}
          placeholder={tr("All programs / not restricted", "সকল প্রোগ্রাম / সীমাবদ্ধ নয়")}
          hint={tr(
            "Leave empty when the rule applies regardless of program.",
            "Program অনুযায়ী সীমাবদ্ধ না হলে ফাঁকা রাখুন।"
          )}
        />

        <FormField
          id="fee-amount"
          label={tr("Standard Amount (৳)", "স্ট্যান্ডার্ড পরিমাণ (৳)")}
          required
          hint={tr(
            "This is the standard fee before student-specific discount.",
            "এটি শিক্ষার্থীভিত্তিক discount দেওয়ার আগের standard fee।"
          )}
        >
          <Input
            id="fee-amount"
            name="amount"
            type="number"
            min="0"
            step="1"
            className="min-h-11"
            required
          />
        </FormField>

        <FormField
          id="fee-effective-from"
          label={tr("Effective From", "কার্যকর হওয়ার তারিখ")}
          required
          hint={tr(
            "The date from which this fee rule is valid.",
            "যে তারিখ থেকে এই ফি রুল কার্যকর হবে।"
          )}
        >
          <Input
            id="fee-effective-from"
            name="effective_from"
            type="date"
            className="min-h-11"
            required
          />
        </FormField>

        <div className="md:col-span-2 xl:col-span-3">
          <FormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Saving…", "সংরক্ষণ হচ্ছে…")
              : tr("Add Fee Structure", "ফি কাঠামো যোগ করুন")}
          </Button>
        </div>
      </form>

      <RecordRows
        emptyText={tr("No fee rules recorded yet.", "এখনও কোনো ফি রুল যোগ করা হয়নি।")}
        rows={fees.map((fee) => [
          fee.title,
          `৳${Number(fee.amount).toLocaleString()} • ${fee.frequency}`,
        ])}
      />
    </Box>
  );
}

export function PaymentManager({
  students,
  payments,
}: {
  students: {
    id: string;
    student_no: string;
    name: string;
    enrollments: { id: string }[] | null;
  }[];
  payments: {
    id: string;
    receipt_no: string;
    amount: number;
    payment_date: string;
    students: { name: string; student_no: string } | null;
  }[];
}) {
  const { tr } = useCopy();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);
  const operationKey = useRef<string | null>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);
    if (!operationKey.current) operationKey.current = crypto.randomUUID();
    formData.set("idempotency_key", operationKey.current);
    setMessage(null);

    startTransition(async () => {
      const result = await recordPayment(formData);
      if (result.ok) {
        operationKey.current = null;
        form.reset();
        setMessage({
          ok: true,
          text: tr(
            `Payment posted successfully. Receipt: ${result.receipt ?? "created"}.`,
            `পেমেন্ট সফলভাবে পোস্ট হয়েছে। রসিদ: ${result.receipt ?? "তৈরি হয়েছে"}।`
          ),
        });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Payment could not be posted.", "পেমেন্ট পোস্ট করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Box title={tr("Fee Collection", "ফি সংগ্রহ")}>
      <div className="mb-5 rounded-xl border border-amber-500/30 bg-amber-500/5 p-4 text-sm leading-6">
        <strong>{tr("Financial record:", "আর্থিক রেকর্ড:")}</strong>{" "}
        {tr(
          "Posting a payment creates an official academy receipt. Verify the student, amount, date and payment method before submitting.",
          "পেমেন্ট পোস্ট করলে অফিসিয়াল একাডেমি রসিদ তৈরি হবে। জমা দেওয়ার আগে শিক্ষার্থী, পরিমাণ, তারিখ ও payment method যাচাই করুন।"
        )}
      </div>

      <form onSubmit={submit} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <SelectField
          id="payment-student"
          name="student_id"
          label={tr("Student", "শিক্ষার্থী")}
          items={students.map((student) => ({
            id: student.id,
            name: `${student.student_no} — ${student.name}`,
          }))}
          placeholder={tr("Select student", "শিক্ষার্থী নির্বাচন করুন")}
          required
          hint={tr(
            "Choose the permanent Student ID/name receiving this payment.",
            "যে শিক্ষার্থীর জন্য টাকা গ্রহণ করা হচ্ছে তার স্থায়ী Student ID/নাম নির্বাচন করুন।"
          )}
        />

        <FormField
          id="payment-amount"
          label={tr("Amount Received (৳)", "প্রাপ্ত পরিমাণ (৳)")}
          required
          hint={tr(
            "Enter the amount actually received now.",
            "এখন বাস্তবে যে পরিমাণ টাকা পাওয়া হয়েছে সেটি লিখুন।"
          )}
        >
          <Input
            id="payment-amount"
            name="amount"
            type="number"
            min="1"
            step="1"
            className="min-h-11"
            required
          />
        </FormField>

        <FormField
          id="payment-date"
          label={tr("Payment Date", "পেমেন্টের তারিখ")}
          required
          hint={tr(
            "Use the date the academy actually received the money.",
            "একাডেমি যে তারিখে বাস্তবে টাকা পেয়েছে সেটি দিন।"
          )}
        >
          <Input
            id="payment-date"
            name="payment_date"
            type="date"
            className="min-h-11"
            required
          />
        </FormField>

        <FormField
          id="payment-method"
          label={tr("Payment Method", "পেমেন্ট পদ্ধতি")}
          required
        >
          <select
            id="payment-method"
            name="method"
            className={selectClass}
            required
            defaultValue="CASH"
          >
            <option value="CASH">{tr("Cash", "ক্যাশ")}</option>
            <option value="BANK">{tr("Bank", "ব্যাংক")}</option>
            <option value="MOBILE BANKING">
              {tr("Mobile Banking", "মোবাইল ব্যাংকিং")}
            </option>
          </select>
        </FormField>

        <FormField
          id="payment-notes"
          label={tr("Payment Note", "পেমেন্ট নোট")}
          hint={tr(
            "Optional context such as month/purpose. Do not use notes as a substitute for future billing allocation.",
            "মাস/উদ্দেশ্যের মতো অতিরিক্ত তথ্য লিখতে পারেন। ভবিষ্যৎ billing allocation-এর বিকল্প হিসেবে notes ব্যবহার করবেন না।"
          )}
          className="md:col-span-2"
        >
          <Input id="payment-notes" name="notes" className="min-h-11" />
        </FormField>

        <div className="md:col-span-2 xl:col-span-3">
          <FormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Posting payment…", "পেমেন্ট পোস্ট হচ্ছে…")
              : tr("Post Payment & Issue Receipt", "পেমেন্ট পোস্ট ও রসিদ তৈরি করুন")}
          </Button>
        </div>
      </form>

      <RecordRows
        emptyText={tr("No payments recorded yet.", "এখনও কোনো পেমেন্ট রেকর্ড হয়নি।")}
        rows={payments.map((payment) => [
          payment.receipt_no,
          `${payment.students?.student_no ?? ""} ${payment.students?.name ?? ""} • ৳${Number(payment.amount).toLocaleString()} • ${payment.payment_date}`,
        ])}
      />
    </Box>
  );
}

export function AssessmentManager({
  years,
  batches,
  subjects,
  assessments,
}: {
  years: Option[];
  batches: Option[];
  subjects: Option[];
  assessments: {
    id: string;
    title: string;
    held_on: string;
    total_marks: number;
  }[];
}) {
  const { tr } = useCopy();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createAssessment(formData);
      if (result.ok) {
        form.reset();
        setMessage({
          ok: true,
          text: tr("Assessment created.", "মূল্যায়ন তৈরি হয়েছে।"),
        });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Assessment could not be created.", "মূল্যায়ন তৈরি করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Box title={tr("Assessments", "মূল্যায়ন")}>
      <form onSubmit={submit} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <FormField
          id="assessment-title"
          label={tr("Assessment Name", "মূল্যায়নের নাম")}
          required
          hint={tr(
            'Example: "Weekly Test 01 — Mathematics".',
            'উদাহরণ: "Weekly Test 01 — Mathematics"।'
          )}
        >
          <Input id="assessment-title" name="title" className="min-h-11" required />
        </FormField>

        <SelectField
          id="assessment-year"
          name="academic_year_id"
          label={tr("Academic Year", "শিক্ষাবর্ষ")}
          items={years}
          placeholder={tr("Select academic year", "শিক্ষাবর্ষ নির্বাচন করুন")}
          required
        />

        <SelectField
          id="assessment-batch"
          name="batch_id"
          label={tr("Batch", "ব্যাচ")}
          items={batches}
          placeholder={tr("Select batch", "ব্যাচ নির্বাচন করুন")}
          required
        />

        <SelectField
          id="assessment-subject"
          name="subject_id"
          label={tr("Subject", "বিষয়")}
          items={subjects}
          placeholder={tr("Select subject", "বিষয় নির্বাচন করুন")}
          hint={tr(
            "Select the subject when this assessment is subject-specific.",
            "এই assessment নির্দিষ্ট বিষয়ের হলে বিষয় নির্বাচন করুন।"
          )}
        />

        <FormField
          id="assessment-type"
          label={tr("Assessment Type", "মূল্যায়নের ধরন")}
          required
          hint={tr(
            "Choose a controlled type instead of typing different spellings.",
            "ভিন্ন বানান টাইপ না করে নির্ধারিত ধরন নির্বাচন করুন।"
          )}
        >
          <select
            id="assessment-type"
            name="assessment_type"
            className={selectClass}
            defaultValue="WEEKLY"
            required
          >
            <option value="CLASS_TEST">{tr("Class Test", "ক্লাস টেস্ট")}</option>
            <option value="WEEKLY">{tr("Weekly Test", "সাপ্তাহিক টেস্ট")}</option>
            <option value="MONTHLY">{tr("Monthly Test", "মাসিক টেস্ট")}</option>
            <option value="MODEL">{tr("Model Test", "মডেল টেস্ট")}</option>
            <option value="OTHER">{tr("Other", "অন্যান্য")}</option>
          </select>
        </FormField>

        <FormField
          id="assessment-date"
          label={tr("Assessment Date", "মূল্যায়নের তারিখ")}
          required
        >
          <Input
            id="assessment-date"
            name="held_on"
            type="date"
            className="min-h-11"
            required
          />
        </FormField>

        <FormField
          id="assessment-total"
          label={tr("Total Marks", "মোট নম্বর")}
          required
          hint={tr(
            "Student marks cannot exceed this value.",
            "শিক্ষার্থীর প্রাপ্ত নম্বর এই মানের বেশি হতে পারবে না।"
          )}
        >
          <Input
            id="assessment-total"
            name="total_marks"
            type="number"
            min="1"
            step="0.01"
            defaultValue="100"
            className="min-h-11"
            required
          />
        </FormField>

        <div className="md:col-span-2 xl:col-span-3">
          <FormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Creating…", "তৈরি হচ্ছে…")
              : tr("Create Assessment", "মূল্যায়ন তৈরি করুন")}
          </Button>
        </div>
      </form>

      <RecordRows
        emptyText={tr("No assessments yet.", "এখনও কোনো মূল্যায়ন তৈরি হয়নি।")}
        rows={assessments.map((assessment) => [
          assessment.title,
          `${assessment.held_on} • ${assessment.total_marks} marks`,
        ])}
      />
    </Box>
  );
}

export function NoticeManager({
  notices,
}: {
  notices: {
    id: string;
    title: string;
    audience: string;
    published_at: string | null;
  }[];
}) {
  const { tr } = useCopy();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createNotice(formData);
      if (result.ok) {
        form.reset();
        setMessage({
          ok: true,
          text: tr("Notice saved.", "নোটিশ সংরক্ষণ হয়েছে।"),
        });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ?? tr("Notice could not be saved.", "নোটিশ সংরক্ষণ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Box title={tr("Notices", "নোটিশ")}>
      <form onSubmit={submit} className="grid gap-4">
        <FormField
          id="notice-title"
          label={tr("Notice Title", "নোটিশের শিরোনাম")}
          required
        >
          <Input id="notice-title" name="title" className="min-h-11" required />
        </FormField>

        <FormField
          id="notice-body"
          label={tr("Notice Message", "নোটিশের বার্তা")}
          required
          hint={tr(
            "Write the complete message recipients should receive.",
            "প্রাপকরা যে সম্পূর্ণ বার্তাটি দেখবেন সেটি লিখুন।"
          )}
        >
          <textarea
            id="notice-body"
            name="body"
            required
            className="min-h-32 rounded-xl border border-input bg-background p-3 text-sm"
          />
        </FormField>

        <div className="grid gap-4 md:grid-cols-2">
          <FormField
            id="notice-audience"
            label={tr("Audience", "প্রাপক")}
            required
          >
            <select
              id="notice-audience"
              name="audience"
              className={selectClass}
              required
              defaultValue="ALL"
            >
              <option value="ALL">{tr("Everyone", "সকলেই")}</option>
              <option value="STUDENT">{tr("Students", "শিক্ষার্থী")}</option>
              <option value="GUARDIAN">{tr("Guardians", "অভিভাবক")}</option>
              <option value="TEACHER">{tr("Teachers", "শিক্ষক")}</option>
            </select>
          </FormField>

          <div className="grid content-end gap-2">
            <label className="flex min-h-11 items-center gap-3 rounded-xl border border-border px-3 text-sm">
              <input type="checkbox" name="publish" className="size-4" />
              <span>
                {tr(
                  "Publish immediately after saving",
                  "সংরক্ষণের সঙ্গে সঙ্গে প্রকাশ করুন"
                )}
              </span>
            </label>
            <p className="text-xs text-muted-foreground">
              {tr(
                "Leave unchecked to keep the notice as a draft.",
                "Draft হিসেবে রাখতে checkbox ফাঁকা রাখুন।"
              )}
            </p>
          </div>
        </div>

        <FormStatus message={message} />

        <div className="flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Saving…", "সংরক্ষণ হচ্ছে…")
              : tr("Save Notice", "নোটিশ সংরক্ষণ করুন")}
          </Button>
        </div>
      </form>

      <RecordRows
        emptyText={tr("No notices yet.", "এখনও কোনো নোটিশ নেই।")}
        rows={notices.map((notice) => [
          notice.title,
          `${notice.audience} • ${notice.published_at ? "Published" : "Draft"}`,
        ])}
      />
    </Box>
  );
}

function SelectField({
  id,
  name,
  label,
  items,
  placeholder,
  hint,
  required = false,
}: {
  id: string;
  name: string;
  label: string;
  items: Option[];
  placeholder: string;
  hint?: string;
  required?: boolean;
}) {
  return (
    <FormField id={id} label={label} hint={hint} required={required}>
      <select id={id} name={name} required={required} className={selectClass}>
        <option value="">{placeholder}</option>
        {items.map((item) => (
          <option key={item.id} value={item.id}>
            {item.name}
          </option>
        ))}
      </select>
    </FormField>
  );
}

function Box({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl border bg-card p-5 sm:p-6">
      <h2 className="text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}

function RecordRows({
  rows,
  emptyText,
}: {
  rows: string[][];
  emptyText: string;
}) {
  return (
    <div className="mt-6 divide-y rounded-xl border">
      {rows.length ? (
        rows.map((row, index) => (
          <div
            key={`${row[0]}-${index}`}
            className="flex flex-col gap-1 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between sm:gap-4"
          >
            <span className="font-medium">{row[0]}</span>
            <span className="text-muted-foreground sm:text-right">{row[1]}</span>
          </div>
        ))
      ) : (
        <p className="p-4 text-sm text-muted-foreground">{emptyText}</p>
      )}
    </div>
  );
}
