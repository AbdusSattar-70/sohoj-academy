"use client";

import { motion } from "framer-motion";

interface LogoProps {
  size?: number;
  showText?: boolean;
}

export default function Logo({
  size = 48,
  showText = true,
}: LogoProps) {
  return (
    <div className="inline-flex items-center gap-2">
      <div
        className="relative shrink-0"
        style={{
          width: size,
          height: size,
        }}
      >
        <svg
          viewBox="0 0 1024 1024"
          width={size}
          height={size}
          className="absolute inset-0"
        >
          {/* Main logo */}
          <image
            href="/images/logo.svg"
            width="1024"
            height="1024"
          />

          <defs>
            <linearGradient
              id="flowGradient"
              x1="0%"
              y1="0%"
              x2="100%"
              y2="0%"
            >
              <stop offset="0%" stopColor="transparent" />
              <stop offset="40%" stopColor="transparent" />
              <stop offset="50%" stopColor="#67E8F9" />
              <stop offset="60%" stopColor="transparent" />
              <stop offset="100%" stopColor="transparent" />
            </linearGradient>

            {/* ribbon path duplicated from logo */}
            <path
              id="flowPath"
              d="M 250 360 L 512 590 L 774 360 L 774 420 L 512 660 L 250 420 Z"
            />
          </defs>

          {/* animated ribbon sweep */}
          <motion.rect
            x="-400"
            y="0"
            width="400"
            height="1024"
            fill="url(#flowGradient)"
            mask="url(#ribbonMask)"
            animate={{
              x: [-400, 1400],
            }}
            transition={{
              duration: 3.5,
              repeat: Infinity,
              ease: "linear",
              repeatDelay: 0.5,
            }}
          />

          <mask id="ribbonMask">
            <use href="#flowPath" fill="white" />
          </mask>
        </svg>
      </div>

      {showText && (
          <div className="font-semibold text-blue-600">
            Ledger
        </div>
      )}
    </div>
  );
}