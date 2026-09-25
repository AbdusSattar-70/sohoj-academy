import Link from "next/link";
import { ArrowUpRight, Menu } from "lucide-react";
import Logo from "@/components/shared/logo";

const links = [
  ["Programs", "#programs"],
  ["Learning Method", "#method"],
  ["Why Sohoj", "#why-sohoj"],
  ["Digital Campus", "#digital-campus"],
] as const;

export default function Navbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-slate-200/80 bg-white/90 backdrop-blur-xl">
      <a
        href="#main-content"
        className="sr-only z-[60] rounded-md bg-slate-950 px-4 py-2 text-white focus:not-sr-only focus:absolute focus:left-4 focus:top-3"
      >
        Skip to main content
      </a>

      <nav
        aria-label="Primary navigation"
        className="mx-auto flex h-18 max-w-7xl items-center justify-between gap-4 px-5 sm:px-6 lg:px-8"
      >
        <Link href="/" aria-label="Sohoj Academy home" className="rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-4">
          <Logo />
        </Link>

        <div className="hidden items-center gap-1 lg:flex">
          {links.map(([label, href]) => (
            <Link
              key={label}
              href={href}
              className="rounded-lg px-3 py-2 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
            >
              {label}
            </Link>
          ))}
        </div>

        <div className="hidden items-center gap-3 sm:flex">
          <Link
            href="/auth"
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2"
          >
            Digital Campus
            <ArrowUpRight className="size-4" aria-hidden="true" />
          </Link>
        </div>

        <details className="group relative sm:hidden">
          <summary className="flex size-11 cursor-pointer list-none items-center justify-center rounded-xl border border-slate-200 bg-white text-slate-900 shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600">
            <Menu className="size-5" aria-hidden="true" />
            <span className="sr-only">Open navigation menu</span>
          </summary>
          <div className="absolute right-0 top-14 w-[min(20rem,calc(100vw-2.5rem))] rounded-2xl border border-slate-200 bg-white p-3 shadow-2xl">
            <div className="grid gap-1">
              {links.map(([label, href]) => (
                <Link key={label} href={href} className="rounded-xl px-3 py-3 text-sm font-medium text-slate-700 hover:bg-slate-50">
                  {label}
                </Link>
              ))}
              <Link
                href="/auth"
                className="mt-2 inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white"
              >
                Open Digital Campus
                <ArrowUpRight className="size-4" aria-hidden="true" />
              </Link>
            </div>
          </div>
        </details>
      </nav>
    </header>
  );
}
