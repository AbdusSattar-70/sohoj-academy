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
    eyebrow: ["Class 8\u20139", "\u0995\u09cd\u09b2\u09be\u09b8 \u09ee\u2013\u09ef"],
    title: ["Annual Exam Readiness", "\u09ac\u09be\u09b0\u09cd\u09b7\u09bf\u0995 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf"],
    description: [
      "Identify syllabus gaps, practise weak areas and prepare systematically for annual examinations with focused assessment.",
      "\u09b8\u09bf\u09b2\u09c7\u09ac\u09be\u09b8\u09c7\u09b0 \u0998\u09be\u099f\u09a4\u09bf \u09b6\u09a8\u09be\u0995\u09cd\u09a4 \u0995\u09b0\u09c7 \u09a6\u09c1\u09b0\u09cd\u09ac\u09b2 \u0985\u0982\u09b6\u09c7 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u098f\u09ac\u0982 \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u09ae\u09c2\u09b2\u09cd\u09af\u09be\u09df\u09a8\u09c7\u09b0 \u09ae\u09be\u09a7\u09cd\u09af\u09ae\u09c7 \u09ac\u09be\u09b0\u09cd\u09b7\u09bf\u0995 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be\u09b0 \u099c\u09a8\u09cd\u09af \u09aa\u09b0\u09bf\u0995\u09b2\u09cd\u09aa\u09bf\u09a4 \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf\u0964",
    ],
    icon: ClipboardCheck,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-ssc",
    eyebrow: ["Class 10 \u2022 Science", "\u0995\u09cd\u09b2\u09be\u09b8 \u09e7\u09e6 \u2022 \u09ac\u09bf\u099c\u09cd\u099e\u09be\u09a8"],
    title: ["SSC A+ Preparation", "SSC A+ \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf"],
    description: [
      "Structured subject support, regular testing and progress review designed around disciplined SSC preparation.",
      "\u09ac\u09bf\u09b7\u09df\u09ad\u09bf\u09a4\u09cd\u09a4\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be, \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u0993 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u09aa\u09b0\u09cd\u09af\u09be\u09b2\u09cb\u099a\u09a8\u09be\u09b0 \u09ae\u09be\u09a7\u09cd\u09af\u09ae\u09c7 \u09b6\u09c3\u0999\u09cd\u0996\u09b2\u09be\u09ac\u09a6\u09cd\u09a7 SSC \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf\u0964",
    ],
    icon: GraduationCap,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-batch",
    eyebrow: ["Academic Support", "\u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be"],
    title: ["Focused Small-Batch Learning", "\u099b\u09cb\u099f \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09ae\u09a8\u09cb\u09af\u09cb\u0997\u09c0 \u09b6\u09c7\u0996\u09be"],
    description: [
      "A maximum of 12 students per batch helps teachers notice individual learning gaps instead of teaching to a crowded room.",
      "\u09aa\u09cd\u09b0\u09a4\u09bf \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09b8\u09b0\u09cd\u09ac\u09cb\u099a\u09cd\u099a \u09e7\u09e8 \u099c\u09a8 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0 \u09a5\u09be\u0995\u09be\u09df \u09ad\u09bf\u09dc\u09c7\u09b0 \u09ae\u09a7\u09cd\u09af\u09c7 \u09aa\u09dc\u09be\u09a8\u09cb\u09b0 \u09ac\u09a6\u09b2\u09c7 \u09aa\u09cd\u09b0\u09a4\u09cd\u09af\u09c7\u0995 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0\u09b0 \u09b6\u09c7\u0996\u09be\u09b0 \u0998\u09be\u099f\u09a4\u09bf \u09b6\u09a8\u09be\u0995\u09cd\u09a4 \u0995\u09b0\u09be \u09b8\u09b9\u099c \u09b9\u09df\u0964",
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
            <LocalizedText en="Programs" bn="\u09aa\u09cd\u09b0\u09cb\u0997\u09cd\u09b0\u09be\u09ae\u09b8\u09ae\u09c2\u09b9" />
          </p>
          <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
            <LocalizedText
              en="Focused academic support\u2014not crowded coaching."
              bn="\u09ad\u09bf\u09dc\u09bc \u09a8\u09df\u2014\u09ae\u09a8\u09cb\u09af\u09cb\u0997\u09c0 \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be\u0964"
            />
          </h2>
          <p className="mt-4 max-w-2xl leading-7 text-muted-foreground">
            <LocalizedText
              en="Each program is designed around a clear academic purpose, manageable batch size and regular measurement of student progress."
              bn="\u09aa\u09cd\u09b0\u09a4\u09bf\u099f\u09bf \u09aa\u09cd\u09b0\u09cb\u0997\u09cd\u09b0\u09be\u09ae \u09b8\u09cd\u09aa\u09b7\u09cd\u099f \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b2\u0995\u09cd\u09b7\u09cd\u09af, \u09a8\u09bf\u09df\u09a8\u09cd\u09a4\u09cd\u09b0\u09bf\u09a4 \u09ac\u09cd\u09af\u09be\u099a \u09b8\u09be\u09a7\u09bf\u099c \u098f\u09ac\u0982 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0\u09b0 \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u09aa\u09b0\u09bf\u09ae\u09be\u09aa\u0995\u09c7 \u0995\u09c7\u09a8\u09cd\u09a6\u09cd\u09b0 \u0995\u09b0\u09c7 \u09b8\u09be\u099c\u09be\u09a8\u09cb\u0964"
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
                    <LocalizedText en="Register Interest" bn="\u0986\u0997\u09cd\u09b0\u09b9 \u09a8\u09bf\u09ac\u09a8\u09cd\u09a7\u09a8" />
                  </Link>
                  {program.acceptingApplications ? (
                    <Link
                      href={applyHref}
                      className="inline-flex min-h-11 flex-1 items-center justify-center rounded-xl bg-blue-700 px-3 text-sm font-semibold text-white hover:bg-blue-800"
                    >
                      <LocalizedText en="Apply for Admission" bn="\u09ad\u09b0\u09cd\u09a4\u09bf\u09b0 \u0986\u09ac\u09c7\u09a6\u09a8" />
                    </Link>
                  ) : (
                    <span className="inline-flex min-h-11 flex-1 items-center justify-center rounded-xl border border-dashed px-3 text-xs font-medium text-muted-foreground">
                      <LocalizedText en="Applications closed" bn="\u0986\u09ac\u09c7\u09a6\u09a8 \u09ac\u09a8\u09cd\u09a7" />
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
