import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, Info, ShieldCheck } from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import { PublicInterestForm } from "@/components/public/interest-form";
import Logo from "@/components/shared/logo";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Register Interest | Sohoj Academy",
  description:
    "Register academic interest with Sohoj Academy for programme, subject and schedule follow-up.",
};

export default async function InterestPage() {
  const supabase = await createClient();

  const [classesQ, programsQ, subjectsQ, schoolsQ] = await Promise.all([
    supabase.from("classes").select("id,name").order("sort_order"),
    supabase.from("programs").select("id,name").eq("is_active", true).order("name"),
    supabase.from("subjects").select("id,name").eq("is_active", true).order("name"),
    supabase.from("schools").select("id,name").eq("is_active", true).order("name").limit(500),
  ]);

  const optionsUnavailable =
    Boolean(classesQ.error) ||
    Boolean(programsQ.error) ||
    Boolean(subjectsQ.error) ||
    Boolean(schoolsQ.error);

  return (
    <div className="min-h-screen bg-[#f7f9fc] text-slate-950">
      <Navbar />
      <main id="main-content">
        <section className="border-b border-slate-200 bg-white">
          <div className="mx-auto max-w-5xl px-5 py-12 sm:px-6 lg:px-8 lg:py-16">
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-sm font-medium text-slate-500 hover:text-slate-950"
            >
              <ArrowLeft className="size-4" aria-hidden="true" />
              Back to Sohoj Academy
            </Link>

            <div className="mt-8 max-w-3xl">
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700">
                Student Interest Registration
              </p>
              <h1 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl lg:text-5xl">
                Tell us what support the student is looking for.
              </h1>
              <p className="mt-5 text-base leading-8 text-slate-600">
                This short registration helps Sohoj Academy understand the student&apos;s class, programme or subject interests and preferred schedule before admission.
              </p>
            </div>

            <div className="mt-7 grid gap-3 sm:grid-cols-2">
              <div className="flex gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <Info className="mt-0.5 size-5 shrink-0 text-blue-700" aria-hidden="true" />
                <div>
                  <p className="text-sm font-semibold">This is not admission</p>
                  <p className="mt-1 text-xs leading-5 text-slate-500">
                    No fee or permanent Student ID is created by this interest form.
                  </p>
                </div>
              </div>
              <div className="flex gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <ShieldCheck className="mt-0.5 size-5 shrink-0 text-blue-700" aria-hidden="true" />
                <div>
                  <p className="text-sm font-semibold">Structured follow-up</p>
                  <p className="mt-1 text-xs leading-5 text-slate-500">
                    The information becomes a traceable prospect record for academy follow-up.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-5xl px-5 py-10 sm:px-6 lg:px-8 lg:py-14">
          {optionsUnavailable ? (
            <div role="alert" className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm leading-6 text-amber-900">
              The registration choices are temporarily unavailable. Please refresh after the academy database update is completed.
            </div>
          ) : (
            <div className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_24px_70px_-50px_rgba(15,23,42,.35)] sm:p-7 lg:p-9">
              <PublicInterestForm
                classes={classesQ.data ?? []}
                programs={programsQ.data ?? []}
                subjects={subjectsQ.data ?? []}
                schools={(schoolsQ.data ?? []).map((school) => ({
                  id: school.id,
                  label: school.name,
                }))}
              />
            </div>
          )}
        </section>
      </main>

      <footer className="border-t border-slate-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-col gap-4 px-5 py-8 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
          <Logo size={34} compact />
          <p className="text-xs text-slate-500">শিক্ষা হোক সহজ ও আনন্দময়</p>
        </div>
      </footer>
    </div>
  );
}
