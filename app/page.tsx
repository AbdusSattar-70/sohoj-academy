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
import { LocalizedText } from "@/components/shared/localized-text";

export const metadata: Metadata = {
  title: "Sohoj Academy | Focused Learning. Visible Progress.",
  description:
    "Sohoj Academy combines small-batch teaching, continuous assessment and clear guardian progress tracking for focused academic support.",
};

const programs = [
  {
    eyebrow: ["Class 8–9", "ক্লাস ৮–৯"],
    title: ["Annual Exam Readiness", "বার্ষিক পরীক্ষা প্রস্তুতি"],
    description: [
      "Identify syllabus gaps, practise weak areas and prepare systematically for annual examinations with focused assessment.",
      "সিলেবাসের ঘাটতি শনাক্ত করে দুর্বল অংশে অনুশীলন এবং নিয়মিত মূল্যায়নের মাধ্যমে বার্ষিক পরীক্ষার জন্য পরিকল্পিত প্রস্তুতি।",
    ],
    icon: ClipboardCheck,
  },
  {
    eyebrow: ["Class 10 • Science", "ক্লাস ১০ • বিজ্ঞান"],
    title: ["SSC A+ Preparation", "SSC A+ প্রস্তুতি"],
    description: [
      "Structured subject support, regular testing and progress review designed around disciplined SSC preparation.",
      "বিষয়ভিত্তিক সহায়তা, নিয়মিত পরীক্ষা ও অগ্রগতি পর্যালোচনার মাধ্যমে শৃঙ্খলাবদ্ধ SSC প্রস্তুতি।",
    ],
    icon: GraduationCap,
  },
  {
    eyebrow: ["Academic Support", "একাডেমিক সহায়তা"],
    title: ["Focused Small-Batch Learning", "ছোট ব্যাচে মনোযোগী শেখা"],
    description: [
      "A maximum of 12 students per batch helps teachers notice individual learning gaps instead of teaching to a crowded room.",
      "প্রতি ব্যাচে সর্বোচ্চ ১২ জন শিক্ষার্থী থাকায় ভিড়ের মধ্যে পড়ানোর বদলে প্রত্যেক শিক্ষার্থীর শেখার ঘাটতি শনাক্ত করা সহজ হয়।",
    ],
    icon: UsersRound,
  },
] as const;

const trustPoints = [
  {
    title: ["Maximum 12 students", "সর্বোচ্চ ১২ জন শিক্ষার্থী"],
    description: [
      "Small batches make personal attention practical, not promotional.",
      "ছোট ব্যাচে ব্যক্তিগত মনোযোগ বাস্তবে দেওয়া সম্ভব হয়।",
    ],
    icon: UsersRound,
  },
  {
    title: ["Continuous assessment", "ধারাবাহিক মূল্যায়ন"],
    description: [
      "Weekly, monthly and model-test performance turns progress into something measurable.",
      "সাপ্তাহিক, মাসিক ও মডেল টেস্টের ফলাফল অগ্রগতিকে পরিমাপযোগ্য করে।",
    ],
    icon: BookOpenCheck,
  },
  {
    title: ["Guardian visibility", "অভিভাবকের স্পষ্ট ধারণা"],
    description: [
      "Attendance, results and progress records support clearer guardian follow-up.",
      "উপস্থিতি, ফলাফল ও অগ্রগতির রেকর্ড অভিভাবকের নিয়মিত অনুসরণকে সহজ করে।",
    ],
    icon: MessageSquareText,
  },
  {
    title: ["Structured academic records", "গোছানো একাডেমিক রেকর্ড"],
    description: [
      "Learning history is organised so important progress does not disappear between classes.",
      "শেখার ইতিহাস সংগঠিত থাকে, যাতে ক্লাসের মাঝে গুরুত্বপূর্ণ অগ্রগতি হারিয়ে না যায়।",
    ],
    icon: ShieldCheck,
  },
] as const;

const method = [
  ["01", "Understand", "বুঝি", "Concept first", "আগে ধারণা পরিষ্কার করি"],
  ["02", "Practise", "অনুশীলন করি", "Practise deliberately", "উদ্দেশ্যপূর্ণ অনুশীলন করি"],
  ["03", "Assess", "পরীক্ষা দিই", "Measure learning", "শেখা কতটুকু হয়েছে যাচাই করি"],
  ["04", "Analyse", "বিশ্লেষণ করি", "Find the gap", "ঘাটতি চিহ্নিত করি"],
] as const;

export default function HomePage() {
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
                  en="Small batch • Personal attention • Visible progress"
                  bn="ছোট ব্যাচ • ব্যক্তিগত মনোযোগ • দৃশ্যমান অগ্রগতি"
                />
              </div>

              <h1 className="max-w-4xl text-4xl font-bold tracking-[-0.04em] sm:text-5xl lg:text-6xl">
                <LocalizedText en="Learning should be" bn="শিক্ষা হোক" />
                <span className="block text-blue-700 dark:text-blue-400">
                  <LocalizedText en="easy and enjoyable" bn="সহজ ও আনন্দময়" />
                </span>
              </h1>

              <p className="mt-6 max-w-2xl text-base leading-8 text-muted-foreground sm:text-lg">
                <LocalizedText
                  en="Sohoj Academy is built around focused teaching, regular practice and measurable progress—so students know what to improve and guardians can follow the learning journey with confidence."
                  bn="সহজ একাডেমিতে মনোযোগী পাঠদান, নিয়মিত অনুশীলন এবং পরিমাপযোগ্য অগ্রগতির ওপর গুরুত্ব দেওয়া হয়—যাতে শিক্ষার্থী বুঝতে পারে কোথায় উন্নতি প্রয়োজন এবং অভিভাবক আত্মবিশ্বাসের সঙ্গে শেখার যাত্রা অনুসরণ করতে পারেন।"
                />
              </p>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link
                  href="/interest"
                  className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_30px_-12px_rgba(29,78,216,0.65)] transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2"
                >
                  <LocalizedText en="Register Interest" bn="আগ্রহ নিবন্ধন করুন" />
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
                <Link
                  href="#programs"
                  className="inline-flex min-h-12 items-center justify-center rounded-xl border border-border bg-background px-5 py-3 text-sm font-semibold transition hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <LocalizedText en="Explore Programs" bn="প্রোগ্রাম দেখুন" />
                </Link>
              </div>

              <div className="mt-8 grid max-w-2xl gap-3 text-sm text-muted-foreground sm:grid-cols-3">
                {[
                  ["Class 8–10 focus", "ক্লাস ৮–১০ ফোকাস"],
                  ["12 students per batch", "প্রতি ব্যাচে ১২ জন"],
                  ["Regular progress review", "নিয়মিত অগ্রগতি পর্যালোচনা"],
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
                        <LocalizedText en="Sohoj Learning Method" bn="সহজ লার্নিং মেথড" />
                      </p>
                      <h2 className="mt-2 text-xl font-semibold text-white">
                        <LocalizedText
                          en="Learn → practise → measure → improve"
                          bn="বুঝি → অনুশীলন করি → পরীক্ষা দিই → উন্নতি করি"
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
                        <LocalizedText en="80% mastery achieved?" bn="৮০% দক্ষতা অর্জিত?" />
                      </span>
                      <span className="rounded-full bg-emerald-400/15 px-2.5 py-1 text-xs font-semibold text-emerald-200">
                        <LocalizedText en="YES → Move forward" bn="হ্যাঁ → এগিয়ে যাই" />
                      </span>
                    </div>
                    <p className="mt-2 text-xs leading-5 text-emerald-100/65">
                      <LocalizedText
                        en="If not, return to practice, fix the gap and measure again."
                        bn="না হলে অনুশীলনে ফিরে গিয়ে ঘাটতি ঠিক করি—তারপর আবার যাচাই করি।"
                      />
                    </p>
                  </div>
                </div>
              </div>

              <div className="relative -mt-5 ml-auto mr-4 w-[86%] rounded-2xl border border-border bg-card p-4 text-card-foreground shadow-xl sm:mr-8">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-medium text-muted-foreground">
                      <LocalizedText en="Example progress snapshot" bn="উদাহরণ অগ্রগতি চিত্র" />
                    </p>
                    <p className="mt-1 text-sm font-semibold">
                      <LocalizedText en="Weekly learning review" bn="সাপ্তাহিক শেখার পর্যালোচনা" />
                    </p>
                  </div>
                  <BarChart3 className="size-5 text-blue-700 dark:text-blue-400" aria-hidden="true" />
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                  {[
                    ["Homework", "হোমওয়ার্ক", "90%"],
                    ["Participation", "অংশগ্রহণ", "85%"],
                    ["Weekly Test", "সাপ্তাহিক টেস্ট", "84%"],
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
              {programs.map((program) => (
                <article
                  key={program.title[0]}
                  className="group rounded-3xl border border-border bg-card p-6 text-card-foreground shadow-[0_12px_40px_-28px_rgba(15,23,42,0.35)] transition hover:-translate-y-1 hover:border-blue-300 dark:hover:border-blue-800"
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
                  <p className="mt-3 text-sm leading-7 text-muted-foreground">
                    <LocalizedText en={program.description[0]} bn={program.description[1]} />
                  </p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="method" className="scroll-mt-24 bg-background">
          <div className="mx-auto grid max-w-7xl gap-12 px-5 py-18 sm:px-6 lg:grid-cols-[.78fr_1.22fr] lg:px-8 lg:py-24">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400">
                <LocalizedText en="Learning Method" bn="শেখার পদ্ধতি" />
              </p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                <LocalizedText
                  en="Progress comes from a repeatable learning cycle."
                  bn="পুনরাবৃত্ত শেখার চক্র থেকেই স্থায়ী অগ্রগতি আসে।"
                />
              </h2>
              <p className="mt-4 leading-7 text-muted-foreground">
                <LocalizedText
                  en="Sohoj Learning Method keeps the process simple: understand the concept, practise it, test it, analyse the gap and repeat where necessary."
                  bn="সহজ লার্নিং মেথড শেখার প্রক্রিয়াকে সহজ রাখে: ধারণা বুঝি, অনুশীলন করি, পরীক্ষা দিই, ঘাটতি বিশ্লেষণ করি এবং প্রয়োজন হলে আবার অনুশীলনে ফিরি।"
                />
              </p>
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              {method.map(([number, enTitle, bnTitle, enDesc, bnDesc]) => (
                <div key={number} className="rounded-2xl border border-border bg-muted/45 p-5">
                  <span className="text-xs font-bold text-blue-700 dark:text-blue-400">{number}</span>
                  <h3 className="mt-2 text-lg font-semibold">
                    <LocalizedText en={enTitle} bn={bnTitle} />
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    <LocalizedText en={enDesc} bn={bnDesc} />
                  </p>
                </div>
              ))}
              <div className="rounded-2xl border border-blue-200 bg-blue-50 p-5 text-blue-950 dark:border-blue-900 dark:bg-blue-950/40 dark:text-blue-100 sm:col-span-2">
                <p className="text-sm font-semibold">
                  <LocalizedText en="Mastery check" bn="দক্ষতা যাচাই" />
                </p>
                <p className="mt-2 text-sm leading-6 opacity-80">
                  <LocalizedText
                    en="When 80% mastery is achieved, move to the next step. Otherwise practise and correct the gap, then assess again."
                    bn="৮০% দক্ষতা অর্জিত হলে পরবর্তী ধাপে এগিয়ে যাই। না হলে প্রয়োজনীয় অনুশীলন ও সংশোধনের মাধ্যমে আবার যাচাই করি।"
                  />
                </p>
              </div>
            </div>
          </div>
        </section>

        <section id="why-sohoj" className="scroll-mt-24 border-y border-slate-800 bg-slate-950 text-white">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="grid gap-10 lg:grid-cols-[.8fr_1.2fr]">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-300">
                  <LocalizedText en="Why Sohoj" bn="কেন সহজ" />
                </p>
                <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                  <LocalizedText
                    en="Trust should come from a system you can see."
                    bn="বিশ্বাস আসুক এমন একটি ব্যবস্থা থেকে, যা আপনি দেখতে পারেন।"
                  />
                </h2>
                <p className="mt-4 max-w-xl leading-7 text-slate-400">
                  <LocalizedText
                    en="Academic support should be understandable for students, guardians and teachers—clear expectations, clear records and clear follow-up."
                    bn="একাডেমিক সহায়তা শিক্ষার্থী, অভিভাবক ও শিক্ষকের কাছে সহজবোধ্য হওয়া উচিত—স্পষ্ট প্রত্যাশা, স্পষ্ট রেকর্ড এবং স্পষ্ট ফলো-আপ।"
                  />
                </p>
              </div>

              <div className="grid gap-px overflow-hidden rounded-3xl border border-white/10 bg-white/10 sm:grid-cols-2">
                {trustPoints.map((item) => (
                  <article key={item.title[0]} className="bg-slate-950 p-6">
                    <item.icon className="size-5 text-blue-300" aria-hidden="true" />
                    <h3 className="mt-5 font-semibold">
                      <LocalizedText en={item.title[0]} bn={item.title[1]} />
                    </h3>
                    <p className="mt-2 text-sm leading-6 text-slate-400">
                      <LocalizedText en={item.description[0]} bn={item.description[1]} />
                    </p>
                  </article>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section id="digital-campus" className="scroll-mt-24 bg-background">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="overflow-hidden rounded-[2rem] border border-blue-200 bg-blue-50 dark:border-blue-900 dark:bg-blue-950/30">
              <div className="grid gap-10 p-6 sm:p-9 lg:grid-cols-[1fr_.9fr] lg:items-center lg:p-12">
                <div>
                  <div className="inline-flex items-center gap-2 rounded-full bg-background px-3 py-1.5 text-xs font-semibold text-blue-800 shadow-sm dark:text-blue-300">
                    <ShieldCheck className="size-3.5" aria-hidden="true" />
                    <LocalizedText en="Sohoj Academy Digital Campus" bn="সহজ একাডেমি ডিজিটাল ক্যাম্পাস" />
                  </div>
                  <h2 className="mt-5 max-w-2xl text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                    <LocalizedText
                      en="One reliable place for academic operations and progress records."
                      bn="একাডেমিক কার্যক্রম ও অগ্রগতির রেকর্ডের জন্য একটি নির্ভরযোগ্য জায়গা।"
                    />
                  </h2>
                  <p className="mt-4 max-w-2xl leading-7 text-muted-foreground">
                    <LocalizedText
                      en="The Digital Campus connects admissions, attendance, assessments, progress, guardian communication and academy operations without losing the history behind each action."
                      bn="ডিজিটাল ক্যাম্পাস ভর্তি, উপস্থিতি, মূল্যায়ন, অগ্রগতি, অভিভাবক যোগাযোগ এবং একাডেমি কার্যক্রমকে এক জায়গায় সংযুক্ত করে—প্রতিটি কাজের ইতিহাস সংরক্ষণ করে।"
                    />
                  </p>
                  <Link
                    href="/auth"
                    className="mt-7 inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    <LocalizedText en="Sign in to Digital Campus" bn="ডিজিটাল ক্যাম্পাসে সাইন ইন করুন" />
                    <ArrowRight className="size-4" aria-hidden="true" />
                  </Link>
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  {[
                    ["Attendance", "উপস্থিতি", "Class-by-class records and follow-up", "প্রতিটি ক্লাসের রেকর্ড ও ফলো-আপ"],
                    ["Assessments", "মূল্যায়ন", "Structured results and measurable progress", "গোছানো ফলাফল ও পরিমাপযোগ্য অগ্রগতি"],
                    ["Guardian Care", "অভিভাবক সেবা", "Communication and follow-up history", "যোগাযোগ ও ফলো-আপ ইতিহাস"],
                    ["Academic Progress", "একাডেমিক অগ্রগতি", "Weekly monitoring and learning trends", "সাপ্তাহিক পর্যবেক্ষণ ও শেখার প্রবণতা"],
                  ].map(([enTitle, bnTitle, enDesc, bnDesc]) => (
                    <div key={enTitle} className="rounded-2xl border border-border bg-card p-4 text-card-foreground shadow-sm">
                      <p className="text-sm font-semibold">
                        <LocalizedText en={enTitle} bn={bnTitle} />
                      </p>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        <LocalizedText en={enDesc} bn={bnDesc} />
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-border bg-muted/35">
          <div className="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-14 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div>
              <p className="text-sm font-semibold text-blue-700 dark:text-blue-400">SOHOJ ACADEMY</p>
              <h2 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
                <LocalizedText en="Focused learning. Visible progress." bn="মনোযোগী শেখা। দৃশ্যমান অগ্রগতি।" />
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <Link
                href="#programs"
                className="inline-flex min-h-11 items-center justify-center rounded-xl border border-border bg-background px-4 py-2.5 text-sm font-semibold hover:bg-muted"
              >
                <LocalizedText en="View Programs" bn="প্রোগ্রাম দেখুন" />
              </Link>
              <Link
                href="/interest"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-800"
              >
                <LocalizedText en="Register Interest" bn="আগ্রহ নিবন্ধন করুন" />
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
              en="© Sohoj Academy. Academic support and Digital Campus."
              bn="© সহজ একাডেমি। একাডেমিক সহায়তা ও ডিজিটাল ক্যাম্পাস।"
            />
          </p>
        </div>
      </footer>
    </div>
  );
}
