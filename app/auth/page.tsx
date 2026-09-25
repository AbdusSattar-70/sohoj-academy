import Link from "next/link";
import {
  ArrowLeft,
  ArrowRight,
  BookOpenCheck,
  ClipboardCheck,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import Logo from "@/components/shared/logo";
import { ROUTES } from "@/lib/constants";

const workspaceFeatures = [
  {
    title: "Academic records",
    description: "Attendance, assessments and student progress in one connected workspace.",
    icon: BookOpenCheck,
  },
  {
    title: "Role-based access",
    description: "Each user sees the tools and records appropriate to their role.",
    icon: UsersRound,
  },
  {
    title: "Traceable operations",
    description: "Important academy actions are designed to remain reviewable and accountable.",
    icon: ClipboardCheck,
  },
] as const;

export default function AuthHomePage() {
  return (
    <main className="min-h-screen bg-[#f7f9fc] text-slate-950">
      <div className="mx-auto grid min-h-screen max-w-[96rem] lg:grid-cols-[1.05fr_.95fr]">
        <section className="relative hidden overflow-hidden bg-slate-950 p-10 text-white lg:flex lg:flex-col xl:p-14">
          <div
            className="pointer-events-none absolute inset-0"
            aria-hidden="true"
            style={{
              background:
                "radial-gradient(circle at 15% 15%, rgba(37,99,235,.28), transparent 28%), radial-gradient(circle at 85% 85%, rgba(14,165,233,.16), transparent 28%)",
            }}
          />

          <div className="relative">
            <Logo size={112} priority />
          </div>

          <div className="relative my-auto max-w-2xl py-16">
            <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-300">
              Sohoj Academy Digital Campus
            </p>
            <h1 className="mt-5 text-4xl font-bold tracking-[-0.04em] xl:text-5xl">
              Academy operations and learning records, connected with clarity.
            </h1>
            <p className="mt-5 max-w-xl text-base leading-8 text-slate-300">
              A secure workspace for authorised academy users to manage and follow the academic journey without losing important operational history.
            </p>

            <div className="mt-10 grid gap-3">
              {workspaceFeatures.map((item) => (
                <div key={item.title} className="flex gap-4 rounded-2xl border border-white/10 bg-white/[0.05] p-4">
                  <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-blue-400/10 text-blue-200">
                    <item.icon className="size-5" aria-hidden="true" />
                  </div>
                  <div>
                    <h2 className="text-sm font-semibold text-white">{item.title}</h2>
                    <p className="mt-1 text-sm leading-6 text-slate-400">{item.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <p className="relative text-xs text-slate-500">শিক্ষা হোক সহজ ও আনন্দময়</p>
        </section>

        <section className="flex min-h-screen flex-col bg-white">
          <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4 sm:px-8 lg:border-0 lg:px-10 xl:px-14">
            <div className="lg:hidden">
              <Logo size={76} priority />
            </div>
            <Link
              href="/"
              className="ml-auto inline-flex min-h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
            >
              <ArrowLeft className="size-4" aria-hidden="true" />
              Back to website
            </Link>
          </div>

          <div className="flex flex-1 items-center justify-center px-5 py-12 sm:px-8 lg:px-10 xl:px-14">
            <div className="w-full max-w-md">
              <div className="inline-flex size-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-700">
                <ShieldCheck className="size-6" aria-hidden="true" />
              </div>

              <h1 className="mt-6 text-3xl font-bold tracking-[-0.03em] text-slate-950">
                Welcome to Digital Campus
              </h1>
              <p className="mt-3 text-sm leading-7 text-slate-600">
                Sign in with your authorised Sohoj Academy account. Your available tools are determined by your assigned role.
              </p>

              <div className="mt-8 rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <p className="text-sm font-semibold text-slate-900">Who can sign in?</p>
                <p className="mt-2 text-sm leading-6 text-slate-600">
                  Admin, Operator, Teacher, Guardian and Student accounts that have been created or linked by Sohoj Academy.
                </p>
              </div>

              <Link
                href={ROUTES.SIGN_IN}
                className="mt-6 inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_30px_-12px_rgba(29,78,216,.65)] transition hover:bg-blue-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2"
              >
                Continue to Sign In
                <ArrowRight className="size-4" aria-hidden="true" />
              </Link>

              <p className="mt-5 text-center text-xs leading-5 text-slate-500">
                Access is for authorised users. Public admission-interest registration will be provided separately from account sign-in.
              </p>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
