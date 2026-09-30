import Link from "next/link";
import Image from "next/image";
import {
  ArrowRight,
  BookOpenCheck,
  Check,
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
    title: ["Small learning groups", "ছোট শেখার দল"],
    description: [
      "Small batches make personal attention practical, not promotional.",
      "ছোট ব্যাচে ব্যক্তিগত মনোযোগ বাস্তবে দেওয়া সম্ভব হয়।",
    ],
    icon: UsersRound,
  },
  {
    title: ["Continuous assessment", "ধারাবাহিক মূল্যায়ন"],
    description: [
      "Regular practice and review help make progress measurable.",
      "নিয়মিত অনুশীলন ও পর্যালোচনা অগ্রগতি পরিমাপে সাহায্য করে।",
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
  ["01", "Understand", "বুঝি", "Build the concept", "ধারণা পরিষ্কার করি", "from-blue-500 to-cyan-400"],
  ["02", "Practise", "অনুশীলন করি", "Work it through", "অনুশীলন করি", "from-violet-500 to-blue-500"],
  ["03", "Test", "পরীক্ষা দিই", "Check understanding", "বোঝা যাচাই করি", "from-amber-400 to-orange-500"],
  ["04", "Find mistakes", "ভুল খুঁজি", "Spot what needs work", "কোথায় কাজ দরকার দেখি", "from-rose-500 to-pink-500"],
  ["05", "Learn again", "আবার শিখি", "Close the learning gap", "শেখার ঘাটতি পূরণ করি", "from-emerald-500 to-teal-400"],
  ["06", "Improve", "উন্নতি করি", "Move forward with clarity", "আত্মবিশ্বাসে এগিয়ে যাই", "from-blue-600 to-indigo-500"],
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

            <div className="relative mx-auto w-full max-w-2xl lg:mx-0">
              <div className="absolute -inset-4 rounded-[2.5rem] bg-gradient-to-br from-blue-500/20 via-transparent to-emerald-400/20 blur-2xl" aria-hidden="true" />
              <div className="relative overflow-hidden rounded-[2rem] border border-white/10 bg-slate-950 shadow-[0_35px_90px_-35px_rgba(2,6,23,.8)]">
                <Image
                  src="/images/sohoj-classroom.webp"
                  alt="Illustrative classroom photo of a teacher guiding students through a lesson"
                  width={1672}
                  height={941}
                  priority
                  sizes="(max-width: 1024px) 100vw, 48vw"
                  className="aspect-[1.22] w-full object-cover object-center sm:aspect-[1.38]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/90 via-slate-950/10 to-transparent" aria-hidden="true" />
                <div className="absolute inset-x-0 bottom-0 p-5 text-white sm:p-7">
                  <p className="text-xs font-bold uppercase tracking-[0.2em] text-blue-200">
                    <LocalizedText en="LEARNING, MADE CLEAR" bn="সহজভাবে শেখা" />
                  </p>
                  <p className="mt-2 max-w-md text-xl font-semibold leading-snug sm:text-2xl">
                    <LocalizedText en="A classroom where every question gets room." bn="যে শ্রেণিকক্ষে প্রতিটি প্রশ্নের জন্য জায়গা আছে।" />
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <HomeProgramSection />

        <section id="method" className="scroll-mt-24 overflow-hidden border-b border-border bg-slate-950 text-white">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-24">
            <div className="mx-auto max-w-3xl text-center">
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-300">
                <LocalizedText en="The Sohoj Learning Method" bn="সহজ একাডেমির শেখার পদ্ধতি" />
              </p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
                <LocalizedText
                  en="A clear path from first understanding to steady improvement."
                  bn="প্রথম ধারণা থেকে ধারাবাহিক উন্নতি—একটি পরিষ্কার শেখার পথ।"
                />
              </h2>
              <p className="mx-auto mt-4 max-w-2xl text-sm leading-7 text-slate-300">
                <LocalizedText en="When a test reveals a gap, students return to the concept and practise again. Learning moves forward when understanding is stronger." bn="পরীক্ষায় ঘাটতি ধরা পড়লে শিক্ষার্থী ধারণায় ফিরে গিয়ে আবার অনুশীলন করে। বোঝাপড়া শক্ত হলে শেখা সামনে এগোয়।" />
              </p>
            </div>
            <div className="relative mx-auto mt-14 max-w-5xl [perspective:1400px]">
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {method.map(([number, enTitle, bnTitle, enDesc, bnDesc, color], index) => (
                  <div
                    key={number}
                    className={`group relative rounded-2xl border border-white/10 bg-gradient-to-br from-white/[0.11] to-white/[0.035] p-5 shadow-[0_18px_35px_-20px_rgba(0,0,0,.8)] transition duration-300 [transform:rotateX(5deg)_rotateY(-3deg)] hover:-translate-y-1 hover:border-white/25 hover:[transform:rotateX(0deg)_rotateY(0deg)] ${index === 3 ? "lg:col-start-3 lg:row-start-2" : index === 4 ? "lg:col-start-2 lg:row-start-2" : index === 5 ? "lg:col-start-1 lg:row-start-2" : ""}`}
                  >
                    <div className={`mb-5 inline-flex size-11 items-center justify-center rounded-xl bg-gradient-to-br ${color} text-sm font-black text-white shadow-lg shadow-black/25`}>
                      {number}
                    </div>
                    <h3 className="text-lg font-semibold"><LocalizedText en={enTitle} bn={bnTitle} /></h3>
                    <p className="mt-1 text-sm text-slate-300"><LocalizedText en={enDesc} bn={bnDesc} /></p>
                    {index === 0 || index === 1 ? <ArrowRight className="absolute -right-3 top-1/2 z-10 hidden size-6 -translate-y-1/2 rounded-full border border-white/15 bg-slate-900 p-1 text-blue-200 lg:block" aria-hidden="true" /> : null}
                    {index === 2 ? <ArrowRight className="absolute -bottom-3 right-5 z-10 hidden size-6 rotate-90 rounded-full border border-white/15 bg-slate-900 p-1 text-blue-200 lg:block" aria-hidden="true" /> : null}
                    {index === 3 || index === 4 ? <ArrowRight className="absolute -left-3 top-1/2 z-10 hidden size-6 rotate-180 -translate-y-1/2 rounded-full border border-white/15 bg-slate-900 p-1 text-blue-200 lg:block" aria-hidden="true" /> : null}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section id="why-sohoj" className="scroll-mt-24 bg-background">
          <div className="mx-auto max-w-7xl px-5 py-18 sm:px-6 lg:px-8 lg:py-20">
            <div className="max-w-2xl">
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400"><LocalizedText en="Why Sohoj" bn="কেন সহজ একাডেমি" /></p>
              <h2 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl"><LocalizedText en="Attention you can see in the learning." bn="শেখার অগ্রগতিতে স্পষ্ট মনোযোগ।" /></h2>
            </div>
            <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {trustPoints.map((point) => (
                <div key={point.title[0]} className="rounded-2xl border border-border bg-card p-5">
                  <div className="flex size-10 items-center justify-center rounded-xl bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300"><point.icon className="size-5" aria-hidden="true" /></div>
                  <h3 className="mt-4 font-semibold"><LocalizedText en={point.title[0]} bn={point.title[1]} /></h3>
                  <p className="mt-2 text-sm leading-6 text-muted-foreground"><LocalizedText en={point.description[0]} bn={point.description[1]} /></p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="border-t border-border bg-muted/35">
          <div className="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-14 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div>
              <p className="text-sm font-semibold text-blue-700 dark:text-blue-400">SOHOJ ACADEMY</p>
              <h2 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
                <LocalizedText en="Find the right next step for your student." bn="আপনার শিক্ষার্থীর জন্য সঠিক পরবর্তী পদক্ষেপটি খুঁজুন।" />
              </h2>
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
          <div className="flex flex-wrap gap-x-4 gap-y-2 text-sm text-muted-foreground">
            <Link href="/about" className="hover:text-foreground"><LocalizedText en="About" bn="পরিচিতি" /></Link>
            <Link href="/faq" className="hover:text-foreground"><LocalizedText en="FAQ" bn="প্রশ্নোত্তর" /></Link>
            <Link href="/journal" className="hover:text-foreground"><LocalizedText en="Journal" bn="শিক্ষা-জার্নাল" /></Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
