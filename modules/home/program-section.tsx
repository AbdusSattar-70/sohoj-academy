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
};

const FALLBACK_PROGRAMS: ProgramCard[] = [
  {
    key: "fallback-annual",
    eyebrow: ["Class 8–9", "ক্লাস ৮–৯"],
    title: ["Annual Exam Readiness", "বার্ষিক পরীক্ষা প্রস্তুতি"],
    description: [
      "Identify syllabus gaps, practise weak areas and prepare systematically for annual examinations with focused assessment.",
      "সিলেবাসের ঘাটতি শনাক্ত করে দুর্বল অংশে অনুশীলন এবং নিয়মিত মূল্যায়নের মাধ্যমে বার্ষিক পরীক্ষার জন্য পরিকল্পিত প্রস্তুতি।",
    ],
    icon: ClipboardCheck,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-ssc",
    eyebrow: ["Class 10 • Science", "ক্লাস ১০ • বিজ্ঞান"],
    title: ["SSC A+ Preparation", "SSC A+ প্রস্তুতি"],
    description: [
      "Structured subject support, regular testing and progress review designed around disciplined SSC preparation.",
      "বিষয়ভিত্তিক সহায়তা, নিয়মিত পরীক্ষা ও অগ্রগতি পর্যালোচনার মাধ্যমে শৃঙ্খলাবদ্ধ SSC প্রস্তুতি।",
    ],
    icon: GraduationCap,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-batch",
    eyebrow: ["Academic Support", "একাডেমিক সহায়তা"],
    title: ["Focused Small-Batch Learning", "ছোট ব্যাচে মনোযোগী শেখা"],
    description: [
      "A maximum of 12 students per batch helps teachers notice individual learning gaps instead of teaching to a crowded room.",
      "প্রতি ব্যাচে সর্বোচ্চ ১২ জন শিক্ষার্থী থাকায় ভিড়ের মধ্যে পড়ানোর বদলে প্রত্যেক শিক্ষার্থীর শেখার ঘাটতি শনাক্ত করা সহজ হয়।",
    ],
    icon: UsersRound,
    offeringId: null,
    acceptingApplications: true,
  },
];

export async function HomeProgramSection() {
  const publicOfferings = await getPublicProgrammeOfferings();
  const programs: ProgramCard[] =
    publicOfferings.length > 0
      ? publicOfferings.map((row) => ({
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
        }))
      : FALLBACK_PROGRAMS;

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
