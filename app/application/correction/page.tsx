import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, Info } from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import Logo from "@/components/shared/logo";
import { LocalizedText } from "@/components/shared/localized-text";
import { ApplicantCorrectionForm } from "@/components/public/applicant-correction-form";

export const metadata: Metadata = {
  title: "Correct an Application | Sohoj Academy",
  description:
    "Submit a correction request for an account-free admission application.",
};

export default function ApplicantCorrectionPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Navbar />
      <main id="main-content">
        <section className="border-b border-border bg-background">
          <div className="mx-auto max-w-3xl px-5 py-12 sm:px-6 lg:px-8 lg:py-16">
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground"
            >
              <ArrowLeft className="size-4" aria-hidden="true" />
              <LocalizedText
                en="Back to Sohoj Academy"
                bn="সহজ একাডেমিতে ফিরুন"
              />
            </Link>
            <div className="mt-8 flex items-center gap-3">
              <Logo />
              <p className="text-xs font-bold uppercase tracking-[0.22em] text-blue-700 dark:text-blue-400">
                <LocalizedText en="Applicant support" bn="আবেদনকারী সহায়তা" />
              </p>
            </div>
            <h1 className="mt-5 text-3xl font-bold tracking-[-0.03em] sm:text-4xl">
              <LocalizedText
                en="Correct an admission application"
                bn="ভর্তির আবেদনের তথ্য সংশোধন করুন"
              />
            </h1>
            <p className="mt-5 text-base leading-8 text-muted-foreground">
              <LocalizedText
                en="Use the reference and mobile number from your application. Staff will verify the request before changing any operational record."
                bn="আপনার আবেদনের রেফারেন্স ও মোবাইল নম্বর ব্যবহার করুন। কোনো কার্যকরী রেকর্ড পরিবর্তনের আগে স্টাফ অনুরোধটি যাচাই করবে।"
              />
            </p>
            <div className="mt-7 flex gap-3 rounded-2xl border-border bg-muted/50 p-4">
              <Info
                className="mt-0.5 size-5 shrink-0 text-blue-700 dark:text-blue-400"
                aria-hidden="true"
              />
              <p className="text-sm leading-6 text-muted-foreground">
                <LocalizedText
                  en="This channel does not create an account, change your application immediately, or confirm admission. Keep the returned correction reference for follow-up."
                  bn="এই চ্যানেল কোনো অ্যাকাউন্ট তৈরি করে না, সঙ্গে আবেদন পরিবর্তন করে না বা ভর্তি নিশ্চিত করে না। পরবর্তী যোগাযোগের জন্য সংশোধন রেফারেন্সটি সংরক্ষণ করুন।"
                />
              </p>
            </div>
          </div>
        </section>
        <section className="mx-auto max-w-3xl px-5 py-10 sm:px-6 lg:px-8">
          <ApplicantCorrectionForm />
        </section>
      </main>
    </div>
  );
}
