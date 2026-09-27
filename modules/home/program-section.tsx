import Link from "next/link";
import {
  BookOpenCheck,
  ClipboardCheck,
  GraduationCap,
  LineChart,
  ShieldCheck,
  UsersRound,
  type LucideIcon,
} from "lucide-react";
import { LocalizedText } from "@/components/shared/localized-text";
import { getPublicProgrammeOfferings } from "@/modules/offerings/queries";

function feeSummaryFromPlan(
  plan: {
    billing_cycle: string;
    currency_code: string;
    components: { name: string; amount: number; charge_type: string; recurrence: string }[];
  } | null | undefined,
): [string, string] | null {
  if (!plan?.components?.length) return null;
  const tuition = plan.components.find(
    (c) => c.charge_type === "TUITION" && c.recurrence === "PER_CYCLE",
  );
  const admission = plan.components.find((c) => c.charge_type === "ADMISSION");
  const currency = plan.currency_code || "BDT";
  const cycle = (plan.billing_cycle || "MONTHLY").replaceAll("_", " ").toLowerCase();
  const partsEn: string[] = [];
  const partsBn: string[] = [];
  if (tuition) {
    partsEn.push(`${currency} ${Number(tuition.amount).toLocaleString("en-BD")} / ${cycle}`);
    partsBn.push(`${currency} ${Number(tuition.amount).toLocaleString("en-BD")} / ${cycle}`);
  }
  if (admission) {
    partsEn.push(`Admission ${currency} ${Number(admission.amount).toLocaleString("en-BD")}`);
    partsBn.push(`ভর্তি ${currency} ${Number(admission.amount).toLocaleString("en-BD")}`);
  }
  if (!partsEn.length) {
    const first = plan.components[0];
    partsEn.push(`${currency} ${Number(first.amount).toLocaleString("en-BD")}`);
    partsBn.push(`${currency} ${Number(first.amount).toLocaleString("en-BD")}`);
  }
  return [partsEn.join(" · "), partsBn.join(" · ")];
}

function windowNoteFromOffering(row: {
  is_accepting_applications: boolean;
  application_state: "OPEN" | "UPCOMING" | "CLOSED";
  applications_open_on: string | null;
  applications_close_on: string | null;
}): [string, string] | null {
  if (row.application_state === "UPCOMING" && row.applications_open_on) {
    return [`Opens ${row.applications_open_on}`, `${row.applications_open_on} থেকে আবেদন`];
  }
  if (!row.is_accepting_applications) {
    return ["Applications closed", "আবেদন বন্ধ"];
  }
  const open = row.applications_open_on;
  const close = row.applications_close_on;
  if (!open && !close) return ["Applications open", "আবেদন চলছে"];
  const fmt = (d: string) => {
    try {
      return new Date(d).toLocaleDateString("en-GB", {
        day: "numeric",
        month: "short",
        year: "numeric",
      });
    } catch {
      return d;
    }
  };
  if (open && close) {
    return [`Apply ${fmt(open)} – ${fmt(close)}`, `আবেদন ${fmt(open)} – ${fmt(close)}`];
  }
  if (close) {
    return [`Apply by ${fmt(close)}`, `${fmt(close)} পর্যন্ত আবেদন`];
  }
  return [`Opens ${fmt(open!)}`, `${fmt(open!)} থেকে খোলা`];
}

const SHOWCASE_ICONS: Record<string, LucideIcon> = {
  "clipboard-check": ClipboardCheck,
  "graduation-cap": GraduationCap,
  "users-round": UsersRound,
  "book-open-check": BookOpenCheck,
  "line-chart": LineChart,
  "shield-check": ShieldCheck,
};

type ProgramCard = {
  key: string;
  eyebrow: [string, string];
  title: [string, string];
  description: [string, string];
  icon: LucideIcon;
  offeringId: string | null;
  acceptingApplications: boolean;
  feeSummary: [string, string] | null;
  windowNote: [string, string] | null;
  academicContext: string;
  subjects: string[];
  schedule: [string, string] | null;
  requirements: [string, string] | null;
  policy: [string, string] | null;
};

export async function HomeProgramSection() {
  const rows = await getPublicProgrammeOfferings();
  const programs: ProgramCard[] =
    rows?.map((row) => ({
          key: row.id,
          eyebrow: [
            row.showcase_eyebrow || row.code,
            row.showcase_eyebrow_bn || row.showcase_eyebrow || row.code,
          ] as [string, string],
          title: [
            row.showcase_title || row.name,
            row.showcase_title_bn || row.showcase_title || row.name,
          ] as [string, string],
          description: [
            row.showcase_description || row.name,
            row.showcase_description_bn || row.showcase_description || row.name,
          ] as [string, string],
          icon: SHOWCASE_ICONS[row.showcase_icon ?? ""] ?? GraduationCap,
          offeringId: row.id,
          acceptingApplications: Boolean(row.is_accepting_applications),
          feeSummary: feeSummaryFromPlan(row.fee_plan),
          windowNote: windowNoteFromOffering(row),
          academicContext: [row.academic_year_name, row.branch_name, row.class_name, row.group_name]
            .filter(Boolean).join(" · "),
          subjects: row.subjects.map((subject) => subject.name),
          schedule: row.public_schedule ? [row.public_schedule, row.public_schedule_bn || row.public_schedule] : null,
          requirements: row.public_requirements ? [row.public_requirements, row.public_requirements_bn || row.public_requirements] : null,
          policy: row.admission_policy ? [row.admission_policy, row.admission_policy_bn || row.admission_policy] : null,
        })) ?? [];

  return (
    <section id="programs" className="scroll-mt-24 border-b border-border bg-muted/35">
      <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
        <div className="max-w-3xl">
          <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400">
            <LocalizedText en="Programs" bn="প্রোগ্রামসমূহ" />
          </p>
          <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
            <LocalizedText
              en="Focused academic support—not crowded coaching."
              bn="ভিড় নয়—মনোযোগী একাডেমিক সহায়তা।"
            />
          </h2>
          <p className="mt-4 max-w-2xl leading-7 text-muted-foreground">
            <LocalizedText
              en="Each program is designed around a clear academic purpose, manageable batch size and regular measurement of student progress."
              bn="প্রতিটি প্রোগ্রাম স্পষ্ট একাডেমিক লক্ষ্য, নিয়ন্ত্রিত ব্যাচ সাইজ এবং শিক্ষার্থীর নিয়মিত অগ্রগতি পরিমাপকে কেন্দ্র করে সাজানো।"
            />
          </p>
        </div>

        <div className="mt-10 grid gap-4 lg:grid-cols-3">
          {programs.length === 0 && (
            <p className="rounded-3xl border border-border bg-card p-6 text-sm text-muted-foreground lg:col-span-3" role={rows === null ? "alert" : "status"}>
              {rows === null ? (
                <LocalizedText en="Programme information is temporarily unavailable. Please try again shortly." bn="প্রোগ্রামের তথ্য সাময়িকভাবে পাওয়া যাচ্ছে না। কিছুক্ষণ পরে আবার চেষ্টা করুন।" />
              ) : (
                <LocalizedText en="No programmes are published at the moment. Please check back soon." bn="এখন কোনো প্রোগ্রাম প্রকাশিত নেই। পরে আবার দেখুন।" />
              )}
            </p>
          )}
          {programs.map((program) => {
            const interestHref = program.offeringId
              ? `/interest?offering=${program.offeringId}`
              : "/interest";
            const applyHref = program.offeringId
              ? `/interest?offering=${program.offeringId}&intent=admission`
              : "/interest?intent=admission";

            return (
              <article
                key={program.key}
                className="group flex flex-col rounded-3xl border border-border bg-card p-6 text-card-foreground shadow-[0_12px_40px_-28px_rgba(15,23,42,0.35)] transition hover:-translate-y-1 hover:border-blue-300 dark:hover:border-blue-800"
              >
                <div className="flex size-11 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300">
                  <program.icon className="size-5" aria-hidden="true" />
                </div>
                <p className="mt-6 text-xs font-bold uppercase tracking-[0.16em] text-blue-700 dark:text-blue-400">
                  <LocalizedText en={program.eyebrow[0]} bn={program.eyebrow[1]} />
                </p>
                <h3 className="mt-2 text-xl font-semibold tracking-tight">
                  <LocalizedText en={program.title[0]} bn={program.title[1]} />
                </h3>
                <p className="mt-3 flex-1 text-sm leading-7 text-muted-foreground">
                  <LocalizedText en={program.description[0]} bn={program.description[1]} />
                </p>
                <div className="mt-3 space-y-1 text-xs leading-5 text-muted-foreground">
                  <p>{program.academicContext}</p>
                  {program.subjects.length > 0 && (
                    <p><LocalizedText en="Subjects" bn="বিষয়সমূহ" />: {program.subjects.join(", ")}</p>
                  )}
                  {program.schedule ? <p><LocalizedText en="Schedule" bn="সময়সূচি" />: <LocalizedText en={program.schedule[0]} bn={program.schedule[1]} /></p> : null}
                  {program.requirements ? <p><LocalizedText en="Requirements" bn="শর্ত" />: <LocalizedText en={program.requirements[0]} bn={program.requirements[1]} /></p> : null}
                  {program.policy ? <p><LocalizedText en="Admission policy" bn="ভর্তি নীতি" />: <LocalizedText en={program.policy[0]} bn={program.policy[1]} /></p> : null}
                </div>
                {(program.feeSummary || program.windowNote) && (
                  <div className="mt-4 space-y-1 text-xs leading-5 text-muted-foreground">
                    {program.windowNote ? (
                      <p className="font-medium text-foreground/80">
                        <LocalizedText en={program.windowNote[0]} bn={program.windowNote[1]} />
                      </p>
                    ) : null}
                    {program.feeSummary ? (
                      <p>
                        <LocalizedText en={program.feeSummary[0]} bn={program.feeSummary[1]} />
                      </p>
                    ) : null}
                  </div>
                )}
                <div className="mt-6 flex flex-col gap-2 sm:flex-row">
                  <Link
                    href={interestHref}
                    className="inline-flex min-h-11 flex-1 items-center justify-center rounded-xl border border-border bg-background px-3 text-sm font-semibold hover:bg-muted"
                  >
                    <LocalizedText en="Register Interest" bn="আগ্রহ নিবন্ধন" />
                  </Link>
                  {program.acceptingApplications ? (
                    <Link
                      href={applyHref}
                      className="inline-flex min-h-11 flex-1 items-center justify-center rounded-xl bg-blue-700 px-3 text-sm font-semibold text-white hover:bg-blue-800"
                    >
                      <LocalizedText en="Apply for Admission" bn="ভর্তির আবেদন" />
                    </Link>
                  ) : (
                    <span className="inline-flex min-h-11 flex-1 items-center justify-center rounded-xl border border-dashed px-3 text-xs font-medium text-muted-foreground">
                      <LocalizedText en="Applications closed" bn="আবেদন বন্ধ" />
                    </span>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
