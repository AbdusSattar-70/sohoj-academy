"use client";

import Image from "next/image";

interface LogoProps {
  size?: number;
  showText?: boolean;
  compact?: boolean;
  inverse?: boolean;
  priority?: boolean;
  className?: string;
}

export default function Logo({
  size = 88,
  priority = false,
  className = "",
}: LogoProps) {
  return (
    <Image
      src="/branding/sohoj-academy-logo.webp"
      alt="সহজ একাডেমি — SOHOJ ACADEMY — Learning made easy & fun"
      width={192}
      height={192}
      priority={priority}
      sizes={`${size}px`}
      style={{ width: size, height: "auto" }}
      className={`shrink-0 object-contain ${className}`}
    />
  );
}
