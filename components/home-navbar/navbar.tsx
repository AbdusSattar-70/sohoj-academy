"use client";

import Link from "next/link";
import { ArrowUpRight, Menu } from "lucide-react";
import Logo from "@/components/shared/logo";
import { PreferenceControls } from "@/components/shared/preference-controls";
import { useLanguage } from "@/components/providers/language-provider";

export default function Navbar() {
  const { t } = useLanguage();

  const links = [
    [t("programs"), "#programs"],
    [t("learningMethod"), "#method"],
    [t("whySohoj"), "#why-sohoj"],
    [t("digitalCampus"), "#digital-campus"],
    [t("registerInterest"), "/interest"],
  ] as const;

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-background/90 backdrop-blur-xl">
      <a
        href="#main-content"
        className="sr-only z-[60] rounded-md bg-primary px-4 py-2 text-primary-foreground focus:not-sr-only focus:absolute focus:left-4 focus:top-3"
      >
        {t("skipToContent")}
      </a>

      <nav
        aria-label="Primary navigation"
        className="mx-auto flex h-24 max-w-7xl items-center justify-between gap-4 px-5 sm:px-6 lg:px-8"
      >
        <Link
          href="/"
          aria-label="Sohoj Academy home"
          className="rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-4"
        >
          <Logo size={82} priority />
        </Link>

        <div className="hidden items-center gap-1 xl:flex">
          {links.map(([label, href]) => (
            <Link
              key={href}
              href={href}
              className="rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition hover:bg-muted hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              {label}
            </Link>
          ))}
        </div>

        <div className="hidden items-center gap-2 sm:flex">
          <PreferenceControls compact />
          <Link
            href="/auth"
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground shadow-sm transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
          >
            {t("digitalCampus")}
            <ArrowUpRight className="size-4" aria-hidden="true" />
          </Link>
        </div>

        <details className="group relative sm:hidden">
          <summary className="flex size-11 cursor-pointer list-none items-center justify-center rounded-xl border border-border bg-background text-foreground shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
            <Menu className="size-5" aria-hidden="true" />
            <span className="sr-only">Open navigation menu</span>
          </summary>
          <div className="absolute right-0 top-14 w-[min(21rem,calc(100vw-2.5rem))] rounded-2xl border border-border bg-popover p-3 text-popover-foreground shadow-2xl">
            <PreferenceControls className="mb-3 w-full justify-between" />
            <div className="grid gap-1">
              {links.map(([label, href]) => (
                <Link
                  key={href}
                  href={href}
                  className="rounded-xl px-3 py-3 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground"
                >
                  {label}
                </Link>
              ))}
              <Link
                href="/auth"
                className="mt-2 inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground"
              >
                {t("openDigitalCampus")}
                <ArrowUpRight className="size-4" aria-hidden="true" />
              </Link>
            </div>
          </div>
        </details>
      </nav>
    </header>
  );
}
