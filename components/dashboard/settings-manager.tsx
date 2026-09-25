"use client";

import { useState, useTransition, type FormEvent, type ReactNode } from "react";
import {
  createAcademicYear,
  createBatch,
  createClass,
  createProgram,
  createSubject,
} from "@/app/actions/operations";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FormField, FormStatus } from "@/components/shared/form-field";
import { WorkflowHelp } from "@/components/shared/workflow-help";
import { useLanguage } from "@/components/providers/language-provider";

type Opt = { id: string; name: string };
type Feedback = { ok: boolean; text: string } | null;

const selectClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/30";

export function SettingsManager({
  years,
  classes,
  programs,
  subjects,
  batches,
}: {
  years: (Opt & {
    starts_on: string;
    ends_on: string;
    is_active: boolean;
  })[];
  classes: (Opt & { sort_order: number })[];
  programs: (Opt & { code: string | null })[];
  subjects: (Opt & { code: string | null })[];
  batches: (Opt & { capacity: number })[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);

  return (
    <div className="space-y-6">
      <WorkflowHelp
        title={tr("How to use Settings safely", "Settings নিরাপদভাবে কীভাবে ব্যবহার করবেন")}
        steps={[
          tr(
            "Create reusable master data here instead of typing the same business value differently in operational forms.",
            "Operational form-এ একই business value বারবার ভিন্নভাবে টাইপ না করে এখানে reusable master data তৈরি করুন।"
          ),
          tr(
            "Use clear names and stable codes. Do not create near-duplicates such as Math, Maths and Mathematics for the same subject.",
            "স্পষ্ট নাম ও স্থায়ী code ব্যবহার করুন। একই বিষয়ের জন্য Math, Maths, Mathematics-এর মতো duplicate তৈরি করবেন না।"
          ),
          tr(
            "Batch capacity is protected by the active academy policy and by the database.",
            "Batch capacity active academy policy ও database—দুই স্তরেই সুরক্ষিত।"
          ),
        ]}
      />

      <div className="grid gap-6 xl:grid-cols-2">
        <AcademicYearPanel years={years} />
        <ClassPanel classes={classes} />
        <ProgramPanel programs={programs} />
        <SubjectPanel subjects={subjects} />
        <BatchPanel
          batches={batches}
          years={years}
          classes={classes}
          programs={programs}
        />
      </div>
    </div>
  );
}

function AcademicYearPanel({
  years,
}: {
  years: (Opt & {
    starts_on: string;
    ends_on: string;
    is_active: boolean;
  })[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createAcademicYear(data);
      if (result.ok) {
        form.reset();
        setMessage({
          ok: true,
          text: tr("Academic Year added.", "শিক্ষাবর্ষ যোগ করা হয়েছে।"),
        });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Academic Year could not be added.", "শিক্ষাবর্ষ যোগ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Panel title={tr("Academic Years", "শিক্ষাবর্ষ")}>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <FormField
          id="year-name"
          label={tr("Academic Year Name", "শিক্ষাবর্ষের নাম")}
          required
          hint={tr('Example: "2026".', 'উদাহরণ: "2026"।')}
        >
          <Input id="year-name" name="name" className="min-h-11" required />
        </FormField>

        <div className="hidden sm:block" />

        <FormField
          id="year-start"
          label={tr("Start Date", "শুরুর তারিখ")}
          required
        >
          <Input
            id="year-start"
            name="starts_on"
            type="date"
            className="min-h-11"
            required
          />
        </FormField>

        <FormField
          id="year-end"
          label={tr("End Date", "শেষ তারিখ")}
          required
        >
          <Input
            id="year-end"
            name="ends_on"
            type="date"
            className="min-h-11"
            required
          />
        </FormField>

        <label className="flex min-h-11 items-center gap-3 rounded-xl border px-3 text-sm sm:col-span-2">
          <input name="is_active" type="checkbox" className="size-4" />
          <span>
            {tr(
              "Make this the active Academic Year",
              "এটিকে active শিক্ষাবর্ষ হিসেবে নির্ধারণ করুন"
            )}
          </span>
        </label>

        <div className="sm:col-span-2">
          <FormStatus message={message} />
        </div>

        <div className="sm:col-span-2 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Adding…", "যোগ হচ্ছে…")
              : tr("Add Academic Year", "শিক্ষাবর্ষ যোগ করুন")}
          </Button>
        </div>
      </form>

      <Rows
        rows={years.map((year) => [
          year.name,
          `${year.starts_on} → ${year.ends_on}${year.is_active ? " • Active" : ""}`,
        ])}
        empty={tr("No Academic Years yet.", "এখনও কোনো শিক্ষাবর্ষ নেই।")}
      />
    </Panel>
  );
}

function ClassPanel({
  classes,
}: {
  classes: (Opt & { sort_order: number })[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createClass(data);
      if (result.ok) {
        form.reset();
        setMessage({ ok: true, text: tr("Class added.", "ক্লাস যোগ করা হয়েছে।") });
      } else {
        setMessage({
          ok: false,
          text: result.error ?? tr("Class could not be added.", "ক্লাস যোগ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Panel title={tr("Classes", "ক্লাস")}>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <FormField
          id="class-name"
          label={tr("Class Name", "ক্লাসের নাম")}
          required
          hint={tr('Example: "Class 8".', 'উদাহরণ: "Class 8"।')}
        >
          <Input id="class-name" name="name" className="min-h-11" required />
        </FormField>

        <FormField
          id="class-order"
          label={tr("Display Order", "দেখানোর ক্রম")}
          hint={tr(
            "Lower numbers appear first in class lists.",
            "কম সংখ্যা class list-এ আগে দেখাবে।"
          )}
        >
          <Input
            id="class-order"
            name="sort_order"
            type="number"
            className="min-h-11"
          />
        </FormField>

        <div className="sm:col-span-2">
          <FormStatus message={message} />
        </div>

        <div className="sm:col-span-2 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending ? tr("Adding…", "যোগ হচ্ছে…") : tr("Add Class", "ক্লাস যোগ করুন")}
          </Button>
        </div>
      </form>

      <Rows
        rows={classes.map((item) => [item.name, `Order ${item.sort_order}`])}
        empty={tr("No classes yet.", "এখনও কোনো ক্লাস নেই।")}
      />
    </Panel>
  );
}

function ProgramPanel({
  programs,
}: {
  programs: (Opt & { code: string | null })[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createProgram(data);
      if (result.ok) {
        form.reset();
        setMessage({ ok: true, text: tr("Program added.", "প্রোগ্রাম যোগ করা হয়েছে।") });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Program could not be added.", "প্রোগ্রাম যোগ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Panel title={tr("Programs", "প্রোগ্রাম")}>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <FormField
          id="program-name"
          label={tr("Program Name", "প্রোগ্রামের নাম")}
          required
          hint={tr(
            'Example: "SSC A+ Preparation".',
            'উদাহরণ: "SSC A+ Preparation"।'
          )}
        >
          <Input id="program-name" name="name" className="min-h-11" required />
        </FormField>

        <FormField
          id="program-code"
          label={tr("Program Code", "প্রোগ্রাম কোড")}
          hint={tr(
            "Use a short stable code for reports and future integrations.",
            "Report ও future integration-এর জন্য ছোট ও স্থায়ী code ব্যবহার করুন।"
          )}
        >
          <Input id="program-code" name="code" className="min-h-11" />
        </FormField>

        <div className="sm:col-span-2">
          <FormStatus message={message} />
        </div>

        <div className="sm:col-span-2 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Adding…", "যোগ হচ্ছে…")
              : tr("Add Program", "প্রোগ্রাম যোগ করুন")}
          </Button>
        </div>
      </form>

      <Rows
        rows={programs.map((item) => [item.name, item.code ?? "—"])}
        empty={tr("No programs yet.", "এখনও কোনো প্রোগ্রাম নেই।")}
      />
    </Panel>
  );
}

function SubjectPanel({
  subjects,
}: {
  subjects: (Opt & { code: string | null })[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createSubject(data);
      if (result.ok) {
        form.reset();
        setMessage({ ok: true, text: tr("Subject added.", "বিষয় যোগ করা হয়েছে।") });
      } else {
        setMessage({
          ok: false,
          text:
            result.error ??
            tr("Subject could not be added.", "বিষয় যোগ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Panel title={tr("Subjects", "বিষয়")}>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <FormField
          id="subject-name"
          label={tr("Subject Name", "বিষয়ের নাম")}
          required
          hint={tr('Example: "Mathematics".', 'উদাহরণ: "Mathematics"।')}
        >
          <Input id="subject-name" name="name" className="min-h-11" required />
        </FormField>

        <FormField
          id="subject-code"
          label={tr("Subject Code", "বিষয় কোড")}
          hint={tr(
            "Use a stable code such as MATH.",
            "MATH-এর মতো স্থায়ী code ব্যবহার করুন।"
          )}
        >
          <Input id="subject-code" name="code" className="min-h-11" />
        </FormField>

        <div className="sm:col-span-2">
          <FormStatus message={message} />
        </div>

        <div className="sm:col-span-2 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending
              ? tr("Adding…", "যোগ হচ্ছে…")
              : tr("Add Subject", "বিষয় যোগ করুন")}
          </Button>
        </div>
      </form>

      <Rows
        rows={subjects.map((item) => [item.name, item.code ?? "—"])}
        empty={tr("No subjects yet.", "এখনও কোনো বিষয় নেই।")}
      />
    </Panel>
  );
}

function BatchPanel({
  batches,
  years,
  classes,
  programs,
}: {
  batches: (Opt & { capacity: number })[];
  years: Opt[];
  classes: Opt[];
  programs: Opt[];
}) {
  const { locale } = useLanguage();
  const tr = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setMessage(null);

    startTransition(async () => {
      const result = await createBatch(data);
      if (result.ok) {
        form.reset();
        setMessage({ ok: true, text: tr("Batch added.", "ব্যাচ যোগ করা হয়েছে।") });
      } else {
        setMessage({
          ok: false,
          text: result.error ?? tr("Batch could not be added.", "ব্যাচ যোগ করা যায়নি।"),
        });
      }
    });
  }

  return (
    <Panel title={tr("Batches", "ব্যাচ")} className="xl:col-span-2">
      <form onSubmit={submit} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <FormField
          id="batch-name"
          label={tr("Batch Name", "ব্যাচের নাম")}
          required
          hint={tr('Example: "Class 8 — A".', 'উদাহরণ: "Class 8 — A"।')}
        >
          <Input id="batch-name" name="name" className="min-h-11" required />
        </FormField>

        <SelectField
          id="batch-year"
          name="academic_year_id"
          label={tr("Academic Year", "শিক্ষাবর্ষ")}
          items={years}
          placeholder={tr("Select Academic Year", "শিক্ষাবর্ষ নির্বাচন করুন")}
          required
        />

        <SelectField
          id="batch-class"
          name="class_id"
          label={tr("Class", "ক্লাস")}
          items={classes}
          placeholder={tr("Select Class", "ক্লাস নির্বাচন করুন")}
          required
        />

        <SelectField
          id="batch-program"
          name="program_id"
          label={tr("Program", "প্রোগ্রাম")}
          items={programs}
          placeholder={tr("No specific Program", "নির্দিষ্ট প্রোগ্রাম নেই")}
        />

        <FormField
          id="batch-capacity"
          label={tr("Maximum Students", "সর্বোচ্চ শিক্ষার্থী")}
          required
          hint={tr(
            "The active academy policy currently limits batch size. The database will reject a value above policy.",
            "Active academy policy অনুযায়ী batch size সীমাবদ্ধ। Policy-এর বেশি হলে database গ্রহণ করবে না।"
          )}
        >
          <Input
            id="batch-capacity"
            name="capacity"
            type="number"
            min="1"
            defaultValue="12"
            className="min-h-11"
            required
          />
        </FormField>

        <div className="md:col-span-2 xl:col-span-3">
          <FormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            {pending ? tr("Adding…", "যোগ হচ্ছে…") : tr("Add Batch", "ব্যাচ যোগ করুন")}
          </Button>
        </div>
      </form>

      <Rows
        rows={batches.map((item) => [
          item.name,
          `${tr("Capacity", "ধারণক্ষমতা")} ${item.capacity}`,
        ])}
        empty={tr("No batches yet.", "এখনও কোনো ব্যাচ নেই।")}
      />
    </Panel>
  );
}

function SelectField({
  id,
  name,
  label,
  items,
  placeholder,
  required = false,
}: {
  id: string;
  name: string;
  label: string;
  items: Opt[];
  placeholder: string;
  required?: boolean;
}) {
  return (
    <FormField id={id} label={label} required={required}>
      <select id={id} name={name} className={selectClass} required={required}>
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

function Panel({
  title,
  children,
  className = "",
}: {
  title: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-2xl border bg-card p-5 sm:p-6 ${className}`}>
      <h2 className="mb-5 text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}

function Rows({
  rows,
  empty,
}: {
  rows: string[][];
  empty: string;
}) {
  return (
    <div className="mt-6 divide-y rounded-xl border">
      {rows.length ? (
        rows.map((row, index) => (
          <div
            key={`${row[0]}-${index}`}
            className="flex flex-col gap-1 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between"
          >
            <span className="font-medium">{row[0]}</span>
            <span className="text-muted-foreground">{row[1]}</span>
          </div>
        ))
      ) : (
        <p className="p-4 text-sm text-muted-foreground">{empty}</p>
      )}
    </div>
  );
}
