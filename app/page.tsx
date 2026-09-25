import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowRight,
  BarChart3,
  BookOpenCheck,
  Check,
  ClipboardCheck,
  GraduationCap,
  LineChart,
  MessageSquareText,
  ShieldCheck,
  Sparkles,
  UsersRound,
} from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import Logo from "@/components/shared/logo";

export const metadata: Metadata = {
  title: "Sohoj Academy | Focused Learning. Visible Progress.",
  description:
    "Sohoj Academy combines small-batch teaching, continuous assessment and clear guardian progress tracking for focused academic support.",
};

const programs = [
  {
    eyebrow: "Class 8–9",
    title: "Annual Exam Readiness",
    description:
      "Identify syllabus gaps, practise weak areas and prepare systematically for annual examinations with focused assessment.",
    icon: ClipboardCheck,
  },
  {
    eyebrow: "Class 10 • Science",
    title: "SSC A+ Preparation",
    description:
      "Structured subject support, regular testing and progress review designed around disciplined SSC preparation.",
    icon: GraduationCap,
  },
  {
    eyebrow: "Academic Support",
    title: "Focused Small-Batch Learning",
    description:
      "A maximum of 12 students per batch helps teachers notice individual learning gaps instead of teaching to a crowded room.",
    icon: UsersRound,
  },
] as const;

const trustPoints = [
  {
    title: "Maximum 12 students",
    description: "Small batches make personal attention practical, not promotional.",
    icon: UsersRound,
  },
  {
    title: "Continuous assessment",
    description: "Weekly, monthly and model-test performance turns progress into something measurable.",
    icon: BookOpenCheck,
  },
  {
    title: "Guardian visibility",
    description: "Attendance, results and progress records support clearer guardian follow-up.",
    icon: MessageSquareText,
  },
  {
    title: "Structured academic records",
    description: "Learning history is organised so important progress does not disappear between classes.",
    icon: ShieldCheck,
  },
] as const;

const method = [
  ["01", "বুঝি", "Concept first"],
  ["02", "অনুশীলন করি", "Practise deliberately"],
  ["03", "পরীক্ষা দিই", "Measure learning"],
  ["04", "বিশ্লেষণ করি", "Find the gap"],
] as const;

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#f7f9fc] text-slate-950">
      <Navbar />

      <main id="main-content">
        <section className="relative overflow-hidden border-b border-slate-200 bg-white">
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
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-blue-100 bg-blue-50 px-3 py-1.5 text-xs font-semibold text-blue-800">
                <Sparkles className="size-3.5" aria-hidden="true" />
                Small batch • Personal attention • Visible progress
              </div>

              <h1 className="max-w-4xl text-4xl font-bold tracking-[-0.04em] text-slate-950 sm:text-5xl lg:text-6xl">
                শিক্ষা হোক
                <span className="block text-blue-700">সহজ ও আনন্দময়</span>
              </h1>

              <p className="mt-6 max-w-2xl text-base leading-8 text-slate-600 sm:text-lg">
                Sohoj Academy is built around focused teaching, regular practice and measurable progress—so students know what to improve and guardians can follow the learning journey with confidence.
              </p>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link
                  href="#programs"
                  className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_30px_-12px_rgba(29,78,216,0.65)] transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2"
                >
                  Explore Programs
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
                <Link
                  href="/auth"
                  className="inline-flex min-h-12 items-center justify-center rounded-xl border border-slate-300 bg-white px-5 py-3 text-sm font-semibold text-slate-900 transition hover:border-slate-400 hover:bg-slate-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                >
                  Open Digital Campus
                </Link>
              </div>

              <div className="mt-8 grid max-w-2xl gap-3 text-sm text-slate-600 sm:grid-cols-3">
                {["Class 8–10 focus", "12 students per batch", "Regular progress review"].map((item) => (
                  <div key={item} className="flex items-center gap-2">
                    <span className="flex size-5 shrink-0 items-center justify-center rounded-full bg-emerald-50 text-emerald-700">
                      <Check className="size-3" aria-hidden="true" />
                    </span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="mx-auto w-full max-w-xl lg:mx-0">
              <div className="relative overflow-hidden rounded-[2rem] border border-slate-200 bg-slate-950 p-5 shadow-[0_30px_80px_-35px_rgba(15,23,42,0.55)] sm:p-7">
                <div className="absolute right-0 top-0 size-56 rounded-full bg-blue-600/20 blur-3xl" aria-hidden="true" />
                <div className="relative">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-300">
                        Sohoj Learning Method
                      </p>
                      <h2 className="mt-2 text-xl font-semibold text-white">
                        Learn → practise → measure → improve
                      </h2>
                    </div>
                    <div className="rounded-xl bg-white/10 p-2 text-blue-200">
                      <LineChart className="size-5" aria-hidden="true" />
                    </div>
                  </div>

                  <div className="mt-7 grid gap-3 sm:grid-cols-2">
                    {method.map(([number, bn, en]) => (
                      <div key={number} className="rounded-2xl border border-white/10 bg-white/[0.06] p-4">
                        <div className="flex items-center gap-3">
                          <span className="text-xs font-bold text-blue-300">{number}</span>
                          <span className="font-semibold text-white">{bn}</span>
                        </div>
                        <p className="mt-2 text-xs leading-5 text-slate-400">{en}</p>
                      </div>
                    ))}
                  </div>

                  <div className="mt-4 rounded-2xl border border-emerald-400/20 bg-emerald-400/[0.08] p-4">
                    <div className="flex items-center justify-between gap-4 text-sm">
                      <span className="font-medium text-emerald-100">৮০% দক্ষতা অর্জিত?</span>
                      <span className="rounded-full bg-emerald-400/15 px-2.5 py-1 text-xs font-semibold text-emerald-200">
                        YES → এগিয়ে যাই
                      </span>
                    </div>
                    <p className="mt-2 text-xs leading-5 text-emerald-100/65">
                      না হলে অনুশীলনে ফিরে গিয়ে gap ঠিক করি—তারপর আবার measure করি।
                    </p>
                  </div>
                </div>
              </div>

              <div className="relative -mt-5 ml-auto mr-4 w-[86%] rounded-2xl border border-slate-200 bg-white p-4 shadow-xl sm:mr-8">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-medium text-slate-500">Example progress snapshot</p>
                    <p className="mt-1 text-sm font-semibold text-slate-900">Weekly learning review</p>
                  </div>
                  <BarChart3 className="size-5 text-blue-700" aria-hidden="true" />
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                  {[
                    ["Homework", "90%"],
                    ["Participation", "85%"],
                    ["Weekly Test", "84%"],
                  ].map(([label, value]) => (
                    <div key={label} className="rounded-xl bg-slate-50 px-2 py-3">
                      <p className="text-sm font-bold text-slate-950">{value}</p>
                      <p className="mt-1 text-[11px] text-slate-500">{label}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="programs" className="scroll-mt-24 border-b border-slate-200 bg-[#f7f9fc]">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="max-w-3xl">
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700">Programs</p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                Focused academic support—not crowded coaching.
              </h2>
              <p className="mt-4 max-w-2xl leading-7 text-slate-600">
                Each program is designed around a clear academic purpose, manageable batch size and regular measurement of student progress.
              </p>
            </div>

            <div className="mt-10 grid gap-4 lg:grid-cols-3">
              {programs.map((program) => (
                <article
                  key={program.title}
                  className="group rounded-3xl border border-slate-200 bg-white p-6 shadow-[0_12px_40px_-28px_rgba(15,23,42,0.35)] transition hover:-translate-y-1 hover:border-blue-200 hover:shadow-[0_20px_50px_-28px_rgba(29,78,216,0.32)]"
                >
                  <div className="flex size-11 items-center justify-center rounded-2xl bg-blue-50 text-blue-700">
                    <program.icon className="size-5" aria-hidden="true" />
                  </div>
                  <p className="mt-6 text-xs font-bold uppercase tracking-[0.16em] text-blue-700">{program.eyebrow}</p>
                  <h3 className="mt-2 text-xl font-semibold tracking-tight">{program.title}</h3>
                  <p className="mt-3 text-sm leading-7 text-slate-600">{program.description}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="method" className="scroll-mt-24 bg-white">
          <div className="mx-auto grid max-w-7xl gap-12 px-5 py-18 sm:px-6 lg:grid-cols-[.78fr_1.22fr] lg:px-8 lg:py-24">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700">Learning Method</p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                Progress comes from a repeatable learning cycle.
              </h2>
              <p className="mt-4 leading-7 text-slate-600">
                Sohoj Learning Method keeps the process simple: understand the concept, practise it, test it, analyse the gap and repeat where necessary.
              </p>
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              {method.map(([number, bn, en]) => (
                <div key={number} className="rounded-2xl border border-slate-200 bg-slate-50/70 p-5">
                  <span className="text-xs font-bold text-blue-700">{number}</span>
                  <h3 className="mt-2 text-lg font-semibold">{bn}</h3>
                  <p className="mt-1 text-sm text-slate-500">{en}</p>
                </div>
              ))}
              <div className="rounded-2xl border border-blue-200 bg-blue-50 p-5 sm:col-span-2">
                <p className="text-sm font-semibold text-blue-950">Mastery check</p>
                <p className="mt-2 text-sm leading-6 text-blue-900/70">
                  ৮০% দক্ষতা অর্জিত হলে পরবর্তী ধাপে এগিয়ে যাই। না হলে প্রয়োজনীয় অনুশীলন ও সংশোধনের মাধ্যমে আবার যাচাই করি।
                </p>
              </div>
            </div>
          </div>
        </section>

        <section id="why-sohoj" className="scroll-mt-24 border-y border-slate-200 bg-slate-950 text-white">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="grid gap-10 lg:grid-cols-[.8fr_1.2fr]">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-300">Why Sohoj</p>
                <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                  Trust should come from a system you can see.
                </h2>
                <p className="mt-4 max-w-xl leading-7 text-slate-400">
                  We want academic support to be understandable for students, guardians and teachers—clear expectations, clear records and clear follow-up.
                </p>
              </div>

              <div className="grid gap-px overflow-hidden rounded-3xl border border-white/10 bg-white/10 sm:grid-cols-2">
                {trustPoints.map((item) => (
                  <article key={item.title} className="bg-slate-950 p-6">
                    <item.icon className="size-5 text-blue-300" aria-hidden="true" />
                    <h3 className="mt-5 font-semibold">{item.title}</h3>
                    <p className="mt-2 text-sm leading-6 text-slate-400">{item.description}</p>
                  </article>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section id="digital-campus" className="scroll-mt-24 bg-white">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="overflow-hidden rounded-[2rem] border border-blue-100 bg-blue-50">
              <div className="grid gap-10 p-6 sm:p-9 lg:grid-cols-[1fr_.9fr] lg:items-center lg:p-12">
                <div>
                  <div className="inline-flex items-center gap-2 rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-blue-800 shadow-sm">
                    <ShieldCheck className="size-3.5" aria-hidden="true" />
                    Sohoj Academy Digital Campus
                  </div>
                  <h2 className="mt-5 max-w-2xl text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                    One reliable place for academic operations and progress records.
                  </h2>
                  <p className="mt-4 max-w-2xl leading-7 text-slate-600">
                    The Digital Campus is being built to connect admissions, attendance, assessments, progress, guardian communication and academy operations without losing the history behind each action.
                  </p>
                  <Link
                    href="/auth"
                    className="mt-7 inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                  >
                    Sign in to Digital Campus
                    <ArrowRight className="size-4" aria-hidden="true" />
                  </Link>
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  {[
                    ["Attendance", "Class-by-class records and follow-up"],
                    ["Assessments", "Structured results and measurable progress"],
                    ["Guardian Care", "Communication and follow-up history"],
                    ["Academic Progress", "Weekly monitoring and learning trends"],
                  ].map(([title, description]) => (
                    <div key={title} className="rounded-2xl border border-blue-100 bg-white p-4 shadow-sm">
                      <p className="text-sm font-semibold text-slate-950">{title}</p>
                      <p className="mt-1 text-xs leading-5 text-slate-500">{description}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-slate-200 bg-[#f7f9fc]">
          <div className="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-14 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div>
              <p className="text-sm font-semibold text-blue-700">SOHOJ ACADEMY</p>
              <h2 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
                Focused learning. Visible progress.
              </h2>
              <p className="mt-2 text-sm text-slate-600">
                শিক্ষা হোক সহজ ও আনন্দময়
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <Link
                href="#programs"
                className="inline-flex min-h-11 items-center justify-center rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-900 hover:bg-slate-50"
              >
                View Programs
              </Link>
              <Link
                href="/auth"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-800"
              >
                Digital Campus
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl flex-col gap-5 px-5 py-8 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
          <Logo size={36} compact />
          <p className="text-xs leading-5 text-slate-500">
            © Sohoj Academy. Academic support and Digital Campus.
          </p>
        </div>
      </footer>
    </div>
  );
}
