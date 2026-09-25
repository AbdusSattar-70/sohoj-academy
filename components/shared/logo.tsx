"use client";

import Image from "next/image";

interface LogoProps {
  size?: number;
  showText?: boolean;
  compact?: boolean;
  inverse?: boolean;
}

export default function Logo({
  size = 42,
  showText = true,
  compact = false,
  inverse = false,
}: LogoProps) {
  return (
    <span className="inline-flex items-center gap-2.5">
      <span
        className="relative block shrink-0 overflow-hidden rounded-xl bg-white/95 p-1 shadow-sm ring-1 ring-black/5"
        style={{ width: size, height: size }}
        aria-hidden="true"
      >
        <Image
          src="/images/logo.svg"
          alt=""
          fill
          sizes={`${size}px`}
          className="object-contain p-0.5"
          priority
        />
      </span>

      {showText && (
        <span className="min-w-0 leading-none">
          <span
            className={`block truncate text-sm font-bold tracking-[0.08em] ${inverse ? "text-white" : "text-slate-950"}`}
          >
            SOHOJ ACADEMY
          </span>
          {!compact && (
            <span className={`mt-1 block text-[11px] font-medium ${inverse ? "text-white/65" : "text-slate-500"}`}>
              সহজ একাডেমি
            </span>
          )}
        </span>
      )}
    </span>
  );
}
