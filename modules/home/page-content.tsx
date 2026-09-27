import Link from "next/link";
import {
  ArrowRight,
  BarChart3,
  BookOpenCheck,
  Check,
  LineChart,
  MessageSquareText,
  ShieldCheck,
  Sparkles,
  UsersRound,
} from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import Logo from "@/components/shared/logo";
import { LocalizedText } from "@/components/shared/localized-text";
import { HomeProgramSection } from "@/modules/home/program-section";

const trustPoints = [
  {
    title: ["Maximum 12 students", "\u09b8\u09b0\u09cd\u09ac\u09cb\u099a\u09cd\u099a \u09e7\u09e8 \u099c\u09a8 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0"],
    description: [
      "Small batches make personal attention practical, not promotional.",
      "\u099b\u09cb\u099f \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09ac\u09cd\u09af\u0995\u09cd\u09a4\u09bf\u0997\u09a4 \u09ae\u09a8\u09cb\u09af\u09cb\u0997 \u09ac\u09be\u09b8\u09cd\u09a4\u09ac\u09c7 \u09a6\u09c7\u0993\u09df\u09be \u09b8\u09ae\u09cd\u09ad\u09ac \u09b9\u09df\u0964",
    ],
    icon: UsersRound,
  },
  {
    title: ["Continuous assessment", "\u09a7\u09be\u09b0\u09be\u09ac\u09be\u09b9\u09bf\u0995 \u09ae\u09c2\u09b2\u09cd\u09af\u09be\u09df\u09a8"],
    description: [
      "Weekly, monthly and model-test performance turns progress into something measurable.",
      "\u09b8\u09be\u09aa\u09cd\u09a4\u09be\u09b9\u09bf\u0995, \u09ae\u09be\u09b8\u09bf\u0995 \u0993 \u09ae\u09a1\u09c7\u09b2 \u099f\u09c7\u09b8\u09cd\u099f\u09c7\u09b0 \u09ab\u09b2\u09be\u09ab\u09b2 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf\u0995\u09c7 \u09aa\u09b0\u09bf\u09ae\u09be\u09aa\u09af\u09cb\u0997\u09cd\u09af \u0995\u09b0\u09c7\u0964",
    ],
    icon: BookOpenCheck,
  },
  {
    title: ["Guardian visibility", "\u0985\u09ad\u09bf\u09ad\u09be\u09ac\u0995\u09c7\u09b0 \u09b8\u09cd\u09aa\u09b7\u09cd\u099f \u09a7\u09be\u09b0\u09a3\u09be"],
    description: [
      "Attendance, results and progress records support clearer guardian follow-up.",
      "\u0989\u09aa\u09b8\u09cd\u09a5\u09bf\u09a4\u09bf, \u09ab\u09b2\u09be\u09ab\u09b2 \u0993 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf\u09b0 \u09b0\u09c7\u0995\u09b0\u09cd\u09a1 \u0985\u09ad\u09bf\u09ad\u09be\u09ac\u0995\u09c7\u09b0 \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u0985\u09a8\u09c1\u09b8\u09b0\u09a3\u0995\u09c7 \u09b8\u09b9\u099c \u0995\u09b0\u09c7\u0964",
    ],
    icon: MessageSquareText,
  },
  {
    title: ["Structured academic records", "\u0997\u09cb\u099b\u09be\u09a8\u09cb \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b0\u09c7\u0995\u09b0\u09cd\u09a1"],
    description: [
      "Learning history is organised so important progress does not disappear between classes.",
      "\u09b6\u09c7\u0996\u09be\u09b0 \u0987\u09a4\u09bf\u09b9\u09be\u09b8 \u09b8\u0982\u0997\u09a0\u09bf\u09a4 \u09a5\u09be\u0995\u09c7, \u09af\u09be\u09a4\u09c7 \u0995\u09cd\u09b2\u09be\u09b8\u09c7\u09b0 \u09ae\u09be\u099d\u09c7 \u0997\u09c1\u09b0\u09c1\u09a4\u09cd\u09ac\u09aa\u09c2\u09b0\u09cd\u09a3 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u09b9\u09be\u09b0\u09bf\u09df\u09c7 \u09a8\u09be \u09af\u09be\u09df\u0964",
    ],
    icon: ShieldCheck,
  },
] as const;

const method = [
  ["01", "Understand", "\u09ac\u09c1\u099d\u09bf", "Concept first", "\u0986\u0997\u09c7 \u09a7\u09be\u09b0\u09a3\u09be \u09aa\u09b0\u09bf\u09b7\u09cd\u0995\u09be\u09b0 \u0995\u09b0\u09bf"],
  ["02", "Practise", "\u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u0995\u09b0\u09bf", "Practise deliberately", "\u0989\u09a6\u09cd\u09a6\u09c7\u09b6\u09cd\u09af\u09aa\u09c2\u09b0\u09cd\u09a3 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u0995\u09b0\u09bf"],
  ["03", "Assess", "\u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u09a6\u09bf\u0987", "Measure learning", "\u09b6\u09c7\u0996\u09be \u0995\u09a4\u099f\u09c1\u0995\u09c1 \u09b9\u09df\u09c7\u099b\u09c7 \u09af\u09be\u099a\u09be\u0987 \u0995\u09b0\u09bf"],
  ["04", "Analyse", "\u09ac\u09bf\u09b6\u09cd\u09b2\u09c7\u09b7\u09a3 \u0995\u09b0\u09bf", "Find the gap", "\u0998\u09be\u099f\u09a4\u09bf \u099a\u09bf\u09b9\u09cd\u09a8\u09bf\u09a4 \u0995\u09b0\u09bf"],
] as const;

export async function HomePageContent() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Navbar />

      <main id="main-content">
        <section className="relative overflow-hidden border-b border-border bg-background">
          <div
            className="pointer-events-none absolute inset-0"
            aria-hidden="true"
            style={{
              background:
                "radial-gradient(circle at 75% 20%, rgba(37,99,235,0.10), transparent 28%), radial-gradient(circle at 20% 70%, rgba(14,165,233,0.08), transparent 25%)",
            }}
          />

          <div className="relative mx-auto grid max-w-7xl gap-12 px-5 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.08fr_.92fr] lg:items-center lg:px-8 lg:py-24">
            <div className="max-w-3xl">
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-blue-200 bg-blue-50 px-3 py-1.5 text-xs font-semibold text-blue-800 dark:border-blue-900 dark:bg-blue-950/50 dark:text-blue-200">
                <Sparkles className="size-3.5" aria-hidden="true" />
                <LocalizedText
                  en="Small batch \u2022 Personal attention \u2022 Visible progress"
                  bn="\u099b\u09cb\u099f \u09ac\u09cd\u09af\u09be\u099a \u2022 \u09ac\u09cd\u09af\u0995\u09cd\u09a4\u09bf\u0997\u09a4 \u09ae\u09a8\u09cb\u09af\u09cb\u0997 \u2022 \u09a6\u09c3\u09b6\u09cd\u09af\u09ae\u09be\u09a8 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf"
                />
              </div>

              <h1 className="max-w-4xl text-4xl font-bold tracking-[-0.04em] sm:text-5xl lg:text-6xl">
                <LocalizedText en="Learning should be" bn="\u09b6\u09bf\u0995\u09cd\u09b7\u09be \u09b9\u09cb\u0995" />
                <span className="block text-blue-700 dark:text-blue-400">
                  <LocalizedText en="easy and enjoyable" bn="\u09b8\u09b9\u099c \u0993 \u0986\u09a8\u09a8\u09cd\u09a6\u09ae\u09df" />
                </span>
              </h1>

              <p className="mt-6 max-w-2xl text-base leading-8 text-muted-foreground sm:text-lg">
                <LocalizedText
                  en="Sohoj Academy is built around focused teaching, regular practice and measurable progress\u2014so students know what to improve and guardians can follow the learning journey with confidence."
                  bn="\u09b8\u09b9\u099c \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u09a4\u09c7 \u09ae\u09a8\u09cb\u09af\u09cb\u0997\u09c0 \u09aa\u09be\u09a0\u09a6\u09be\u09a8, \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u098f\u09ac\u0982 \u09aa\u09b0\u09bf\u09ae\u09be\u09aa\u09af\u09cb\u0997\u09cd\u09af \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf\u09b0 \u0993\u09aa\u09b0 \u0997\u09c1\u09b0\u09c1\u09a4\u09cd\u09ac \u09a6\u09c7\u0993\u09df\u09be \u09b9\u09df\u2014\u09af\u09be\u09a4\u09c7 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0 \u09ac\u09c1\u099d\u09a4\u09c7 \u09aa\u09be\u09b0\u09c7 \u0995\u09cb\u09a5\u09be\u09df \u0989\u09a8\u09cd\u09a8\u09a4\u09bf \u09aa\u09cd\u09b0\u09df\u09cb\u099c\u09a8 \u098f\u09ac\u0982 \u0985\u09ad\u09bf\u09ad\u09be\u09ac\u0995 \u0986\u09a4\u09cd\u09ae\u09ac\u09bf\u09b6\u09cd\u09ac\u09be\u09b8\u09c7\u09b0 \u09b8\u0999\u09cd\u0997\u09c7 \u09b6\u09c7\u0996\u09be\u09b0 \u09af\u09be\u09a4\u09cd\u09b0\u09be \u0985\u09a8\u09c1\u09b8\u09b0\u09a3 \u0995\u09b0\u09a4\u09c7 \u09aa\u09be\u09b0\u09c7\u09a8\u0964"
                />
              </p>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link
                  href="/interest"
                  className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_30px_-12px_rgba(29,78,216,0.65)] transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2"
                >
                  <LocalizedText en="Register Interest" bn="\u0986\u0997\u09cd\u09b0\u09b9 \u09a8\u09bf\u09ac\u09a8\u09cd\u09a7\u09a8 \u0995\u09b0\u09c1\u09a8" />
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
                <Link
                  href="#programs"
                  className="inline-flex min-h-12 items-center justify-center rounded-xl border border-border bg-background px-5 py-3 text-sm font-semibold transition hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <LocalizedText en="Explore Programs" bn="\u09aa\u09cd\u09b0\u09cb\u0997\u09cd\u09b0\u09be\u09ae \u09a6\u09c7\u0996\u09c1\u09a8" />
                </Link>
              </div>

              <div className="mt-8 grid max-w-2xl gap-3 text-sm text-muted-foreground sm:grid-cols-3">
                {[
                  ["Class 8\u201310 focus", "\u0995\u09cd\u09b2\u09be\u09b8 \u09ee\u2013\u09e7\u09e6 \u09ab\u09cb\u0995\u09be\u09b8"],
                  ["12 students per batch", "\u09aa\u09cd\u09b0\u09a4\u09bf \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09e7\u09e8 \u099c\u09a8"],
                  ["Regular progress review", "\u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u09aa\u09b0\u09cd\u09af\u09be\u09b2\u09cb\u099a\u09a8\u09be"],
                ].map(([en, bn]) => (
                  <div key={en} className="flex items-center gap-2">
                    <span className="flex size-5 shrink-0 items-center justify-center rounded-full bg-emerald-50 text-emerald-700 dark:bg-emerald-950/50 dark:text-emerald-300">
                      <Check className="size-3" aria-hidden="true" />
                    </span>
                    <LocalizedText en={en} bn={bn} />
                  </div>
                ))}
              </div>
            </div>

            <div className="mx-auto w-full max-w-xl lg:mx-0">
              <div className="relative overflow-hidden rounded-[2rem] border border-slate-800 bg-slate-950 p-5 text-white shadow-[0_30px_80px_-35px_rgba(15,23,42,0.55)] sm:p-7">
                <div className="absolute right-0 top-0 size-56 rounded-full bg-blue-600/20 blur-3xl" aria-hidden="true" />
                <div className="relative">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-300">
                        <LocalizedText en="Sohoj Learning Method" bn="\u09b8\u09b9\u099c \u09b2\u09be\u09b0\u09cd\u09a8\u09bf\u0982 \u09ae\u09c7\u09a5\u09a1" />
                      </p>
                      <h2 className="mt-2 text-xl font-semibold text-white">
                        <LocalizedText
                          en="Learn \u2192 practise \u2192 measure \u2192 improve"
                          bn="\u09ac\u09c1\u099d\u09bf \u2192 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u0995\u09b0\u09bf \u2192 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u09a6\u09bf\u0987 \u2192 \u0989\u09a8\u09cd\u09a8\u09a4\u09bf \u0995\u09b0\u09bf"
                        />
                      </h2>
                    </div>
                    <div className="rounded-xl bg-white/10 p-2 text-blue-200">
                      <LineChart className="size-5" aria-hidden="true" />
                    </div>
                  </div>

                  <div className="mt-7 grid gap-3 sm:grid-cols-2">
                    {method.map(([number, enTitle, bnTitle, enDesc, bnDesc]) => (
                      <div key={number} className="rounded-2xl border border-white/10 bg-white/[0.06] p-4">
                        <div className="flex items-center gap-3">
                          <span className="text-xs font-bold text-blue-300">{number}</span>
                          <span className="font-semibold text-white">
                            <LocalizedText en={enTitle} bn={bnTitle} />
                          </span>
                        </div>
                        <p className="mt-2 text-xs leading-5 text-slate-400">
                          <LocalizedText en={enDesc} bn={bnDesc} />
                        </p>
                      </div>
                    ))}
                  </div>

                  <div className="mt-4 rounded-2xl border border-emerald-400/20 bg-emerald-400/[0.08] p-4">
                    <div className="flex items-center justify-between gap-4 text-sm">
                      <span className="font-medium text-emerald-100">
                        <LocalizedText en="80% mastery achieved?" bn="\u09ee\u09e6% \u09a6\u0995\u09cd\u09b7\u09a4\u09be \u0985\u09b0\u09cd\u099c\u09bf\u09a4?" />
                      </span>
                      <span className="rounded-full bg-emerald-400/15 px-2.5 py-1 text-xs font-semibold text-emerald-200">
                        <LocalizedText en="YES \u2192 Move forward" bn="\u09b9\u09cd\u09af\u09be\u0981 \u2192 \u098f\u0997\u09bf\u09df\u09c7 \u09af\u09be\u0987" />
                      </span>
                    </div>
                    <p className="mt-2 text-xs leading-5 text-emerald-100/65">
                      <LocalizedText
                        en="If not, return to practice, fix the gap and measure again."
                        bn="\u09a8\u09be \u09b9\u09b2\u09c7 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8\u09c7 \u09ab\u09bf\u09b0\u09c7 \u0997\u09bf\u09df\u09c7 \u0998\u09be\u099f\u09a4\u09bf \u09a0\u09bf\u0995 \u0995\u09b0\u09bf\u2014\u09a4\u09be\u09b0\u09aa\u09b0 \u0986\u09ac\u09be\u09b0 \u09af\u09be\u099a\u09be\u0987 \u0995\u09b0\u09bf\u0964"
                      />
                    </p>
                  </div>
                </div>
              </div>

              <div className="relative -mt-5 ml-auto mr-4 w-[86%] rounded-2xl border border-border bg-card p-4 text-card-foreground shadow-xl sm:mr-8">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-medium text-muted-foreground">
                      <LocalizedText en="Example progress snapshot" bn="\u0989\u09a6\u09be\u09b9\u09b0\u09a3 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u099a\u09bf\u09a4\u09cd\u09b0" />
                    </p>
                    <p className="mt-1 text-sm font-semibold">
                      <LocalizedText en="Weekly learning review" bn="\u09b8\u09be\u09aa\u09cd\u09a4\u09be\u09b9\u09bf\u0995 \u09b6\u09c7\u0996\u09be\u09b0 \u09aa\u09b0\u09cd\u09af\u09be\u09b2\u09cb\u099a\u09a8\u09be" />
                    </p>
                  </div>
                  <BarChart3 className="size-5 text-blue-700 dark:text-blue-400" aria-hidden="true" />
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                  {[
                    ["Homework", "\u09b9\u09cb\u09ae\u0993\u09df\u09be\u09b0\u09cd\u0995", "90%"],
                    ["Participation", "\u0985\u0982\u09b6\u0997\u09cd\u09b0\u09b9\u09a3", "85%"],
                    ["Weekly Test", "\u09b8\u09be\u09aa\u09cd\u09a4\u09be\u09b9\u09bf\u0995 \u099f\u09c7\u09b8\u09cd\u099f", "84%"],
                  ].map(([en, bn, value]) => (
                    <div key={en} className="rounded-xl bg-muted px-2 py-3">
                      <p className="text-sm font-bold">{value}</p>
                      <p className="mt-1 text-[11px] text-muted-foreground">
                        <LocalizedText en={en} bn={bn} />
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <HomeProgramSection />

        <section id="method" className="scroll-mt-24 bg-background">
          <div className="mx-auto grid max-w-7xl gap-12 px-5 py-18 sm:px-6 lg:grid-cols-[.78fr_1.22fr] lg:px-8 lg:py-24">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400">
                <LocalizedText en="Learning Method" bn="\u09b6\u09c7\u0996\u09be\u09b0 \u09aa\u09a6\u09cd\u09a7\u09a4\u09bf" />
              </p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                <LocalizedText
                  en="Progress comes from a repeatable learning cycle."
                  bn="\u09aa\u09c1\u09a8\u09b0\u09be\u09ac\u09c3\u09a4\u09cd\u09a4 \u09b6\u09c7\u0996\u09be\u09b0 \u099a\u0995\u09cd\u09b0 \u09a5\u09c7\u0995\u09c7\u0987 \u09b8\u09cd\u09a5\u09be\u09df\u09c0 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u0986\u09b8\u09c7\u0964"
                />
              </h2>
            </div>
          </div>
        </section>

        <section className="border-t border-border bg-muted/35">
          <div className="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-14 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div>
              <p className="text-sm font-semibold text-blue-700 dark:text-blue-400">SOHOJ ACADEMY</p>
              <h2 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
                <LocalizedText en="Focused learning. Visible progress." bn="\u09ae\u09a8\u09cb\u09af\u09cb\u0997\u09c0 \u09b6\u09c7\u0996\u09be\u0964 \u09a6\u09c3\u09b6\u09cd\u09af\u09ae\u09be\u09a8 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf\u0964" />
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">\u09b6\u09bf\u0995\u09cd\u09b7\u09be \u09b9\u09cb\u0995 \u09b8\u09b9\u099c \u0993 \u0986\u09a8\u09a8\u09cd\u09a6\u09ae\u09df</p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <Link
                href="#programs"
                className="inline-flex min-h-11 items-center justify-center rounded-xl border border-border bg-background px-4 py-2.5 text-sm font-semibold hover:bg-muted"
              >
                <LocalizedText en="View Programs" bn="\u09aa\u09cd\u09b0\u09cb\u0997\u09cd\u09b0\u09be\u09ae \u09a6\u09c7\u0996\u09c1\u09a8" />
              </Link>
              <Link
                href="/interest"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-800"
              >
                <LocalizedText en="Register Interest" bn="\u0986\u0997\u09cd\u09b0\u09b9 \u09a8\u09bf\u09ac\u09a8\u09cd\u09a7\u09a8 \u0995\u09b0\u09c1\u09a8" />
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-border bg-background">
        <div className="mx-auto flex max-w-7xl flex-col gap-5 px-5 py-8 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
          <Logo size={76} />
          <p className="text-xs leading-5 text-muted-foreground">
            <LocalizedText
              en="\u00a9 Sohoj Academy. Academic support and Digital Campus."
              bn="\u00a9 \u09b8\u09b9\u099c \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0964 \u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be \u0993 \u09a1\u09bf\u099c\u09bf\u099f\u09be\u09b2 \u0995\u09cd\u09af\u09be\u09ae\u09cd\u09aa\u09be\u09b8\u0964"
            />
          </p>
        </div>
      </footer>
    </div>
  );
}
