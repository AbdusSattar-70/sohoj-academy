import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, Info, ShieldCheck } from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import { PublicInterestForm } from "@/components/public/interest-form";
import Logo from "@/components/shared/logo";
import { LocalizedText } from "@/components/shared/localized-text";
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
    <div className="min-h-screen bg-background text-foreground">
      <Navbar />
      <main id="main-content">
        <section className="border-b border-border bg-background">
          <div className="mx-auto max-w-5xl px-5 py-12 sm:px-6 lg:px-8 lg:py-16">
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground"
            >
              <ArrowLeft className="size-4" aria-hidden="true" />
              <LocalizedText en="Back to Sohoj Academy" bn="সহজ একাডেমিতে ফিরুন" />
            </Link>

            <div className="mt-8 max-w-3xl">
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400">
                <LocalizedText en="Student Interest Registration" bn="শিক্ষার্থী আগ্রহ নিবন্ধন" />
              </p>
              <h1 className="mt-3 text-3xl font-bold tracking-[-0.03em] sm:text-4xl lg:text-5xl">
                <LocalizedText
                  en="Tell us what support the student is looking for."
                  bn="শিক্ষার্থী কী ধরনের সহায়তা খুঁজছে তা আমাদের জানান।"
                />
              </h1>
              <p className="mt-5 text-base leading-8 text-muted-foreground">
                <LocalizedText
                  en="This short registration helps Sohoj Academy understand the student's class, programme or subject interests and preferred schedule before admission."
                  bn="এই সংক্ষিপ্ত নিবন্ধনটি ভর্তি হওয়ার আগে শিক্ষার্থীর বর্তমান ক্লাস, প্রোগ্রাম বা বিষয়ভিত্তিক আগ্রহ এবং পছন্দের সময় সম্পর্কে সহজ একাডেমিকে ধারণা দেয়।"
                />
              </p>
            </div>

            <div className="mt-7 grid gap-3 sm:grid-cols-2">
              <div className="flex gap-3 rounded-2xl border border-border bg-muted/50 p-4">
                <Info className="mt-0.5 size-5 shrink-0 text-blue-700 dark:text-blue-400" aria-hidden="true" />
                <div>
                  <p className="text-sm font-semibold">
                    <LocalizedText en="This is not admission" bn="এটি ভর্তি নয়" />
                  </p>
                  <p className="mt-1 text-xs leading-5 text-muted-foreground">
                    <LocalizedText
                      en="No fee or permanent Student ID is created by this interest form."
                      bn="এই ফর্ম থেকে কোনো ফি বা স্থায়ী Student ID তৈরি হয় না।"
                    />
                  </p>
                </div>
              </div>
              <div className="flex gap-3 rounded-2xl border border-border bg-muted/50 p-4">
                <ShieldCheck className="mt-0.5 size-5 shrink-0 text-blue-700 dark:text-blue-400" aria-hidden="true" />
                <div>
                  <p className="text-sm font-semibold">
                    <LocalizedText en="Structured follow-up" bn="গোছানো ফলো-আপ" />
                  </p>
                  <p className="mt-1 text-xs leading-5 text-muted-foreground">
                    <LocalizedText
                      en="The information becomes a traceable prospect record for academy follow-up."
                      bn="তথ্যগুলো একাডেমির ফলো-আপের জন্য ট্রেসযোগ্য Prospect রেকর্ড হিসেবে সংরক্ষিত হয়।"
                    />
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-5xl px-5 py-10 sm:px-6 lg:px-8 lg:py-14">
          {optionsUnavailable ? (
            <div
              role="alert"
              className="rounded-2xl border border-amber-300 bg-amber-50 p-5 text-sm leading-6 text-amber-900 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100"
            >
              <LocalizedText
                en="The registration choices are temporarily unavailable. Please refresh after the academy database update is completed."
                bn="নিবন্ধনের অপশনগুলো সাময়িকভাবে পাওয়া যাচ্ছে না। একাডেমির ডাটাবেজ আপডেট সম্পন্ন হলে পেজটি রিফ্রেশ করুন।"
              />
            </div>
          ) : (
            <div className="rounded-[2rem] border border-border bg-card p-5 text-card-foreground shadow-[0_24px_70px_-50px_rgba(15,23,42,.35)] sm:p-7 lg:p-9">
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

      <footer className="border-t border-border bg-background">
        <div className="mx-auto flex max-w-5xl flex-col gap-4 px-5 py-8 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
          <Logo size={76} />
          <p className="text-xs text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p>
        </div>
      </footer>
    </div>
  );
}
