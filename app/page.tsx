import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowRight,
  BarChart3,
  BookOpenCheck,
  Check,
  ClipboardCheck,
  GraduationCap,
  LineChart,
  MessageSquareText,
  ShieldCheck,
  Sparkles,
  UsersRound,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import Navbar from "@/components/home-navbar/navbar";
import Logo from "@/components/shared/logo";
import { LocalizedText } from "@/components/shared/localized-text";
import { getPublicProgrammeOfferings } from "@/modules/offerings/queries";

export const metadata: Metadata = {
  title: "Sohoj Academy | Focused Learning. Visible Progress.",
  description:
    "Sohoj Academy combines small-batch teaching, continuous assessment and clear guardian progress tracking for focused academic support.",
};

const SHOWCASE_ICONS: Record<string, LucideIcon> = {
  "clipboard-check": ClipboardCheck,
  "graduation-cap": GraduationCap,
  "users-round": UsersRound,
  "book-open-check": BookOpenCheck,
  "line-chart": LineChart,
  "shield-check": ShieldCheck,
};

type ProgramCard = {
  key: string;
  eyebrow: [string, string];
  title: [string, string];
  description: [string, string];
  icon: LucideIcon;
  offeringId: string | null;
  acceptingApplications: boolean;
};

/** Static fallback when no ACTIVE + website-visible offerings are curated. */
const FALLBACK_PROGRAMS: ProgramCard[] = [
  {
    key: "fallback-annual",
    eyebrow: ["Class 8\u20139", "\u0995\u09cd\u09b2\u09be\u09b8 \u09ee\u2013\u09ef"],
    title: ["Annual Exam Readiness", "\u09ac\u09be\u09b0\u09cd\u09b7\u09bf\u0995 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf"],
    description: [
      "Identify syllabus gaps, practise weak areas and prepare systematically for annual examinations with focused assessment.",
      "\u09b8\u09bf\u09b2\u09c7\u09ac\u09be\u09b8\u09c7\u09b0 \u0998\u09be\u099f\u09a4\u09bf \u09b6\u09a8\u09be\u0995\u09cd\u09a4 \u0995\u09b0\u09c7 \u09a6\u09c1\u09b0\u09cd\u09ac\u09b2 \u0985\u0982\u09b6\u09c7 \u0985\u09a8\u09c1\u09b6\u09c0\u09b2\u09a8 \u098f\u09ac\u0982 \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u09ae\u09c2\u09b2\u09cd\u09af\u09be\u09df\u09a8\u09c7\u09b0 \u09ae\u09be\u09a7\u09cd\u09af\u09ae\u09c7 \u09ac\u09be\u09b0\u09cd\u09b7\u09bf\u0995 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be\u09b0 \u099c\u09a8\u09cd\u09af \u09aa\u09b0\u09bf\u0995\u09b2\u09cd\u09aa\u09bf\u09a4 \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf\u0964",
    ],
    icon: ClipboardCheck,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-ssc",
    eyebrow: ["Class 10 \u2022 Science", "\u0995\u09cd\u09b2\u09be\u09b8 \u09e7\u09e6 \u2022 \u09ac\u09bf\u099c\u09cd\u099e\u09be\u09a8"],
    title: ["SSC A+ Preparation", "SSC A+ \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf"],
    description: [
      "Structured subject support, regular testing and progress review designed around disciplined SSC preparation.",
      "\u09ac\u09bf\u09b7\u09df\u09ad\u09bf\u09a4\u09cd\u09a4\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be, \u09a8\u09bf\u09df\u09ae\u09bf\u09a4 \u09aa\u09b0\u09c0\u0995\u09cd\u09b7\u09be \u0993 \u0985\u0997\u09cd\u09b0\u0997\u09a4\u09bf \u09aa\u09b0\u09cd\u09af\u09be\u09b2\u09cb\u099a\u09a8\u09be\u09b0 \u09ae\u09be\u09a7\u09cd\u09af\u09ae\u09c7 \u09b6\u09c3\u0999\u09cd\u0996\u09b2\u09be\u09ac\u09a6\u09cd\u09a7 SSC \u09aa\u09cd\u09b0\u09b8\u09cd\u09a4\u09c1\u09a4\u09bf\u0964",
    ],
    icon: GraduationCap,
    offeringId: null,
    acceptingApplications: true,
  },
  {
    key: "fallback-batch",
    eyebrow: ["Academic Support", "\u098f\u0995\u09be\u09a1\u09c7\u09ae\u09bf\u0995 \u09b8\u09b9\u09be\u09df\u09a4\u09be"],
    title: ["Focused Small-Batch Learning", "\u099b\u09cb\u099f \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09ae\u09a8\u09cb\u09af\u09cb\u0997\u09c0 \u09b6\u09c7\u0996\u09be"],
    description: [
      "A maximum of 12 students per batch helps teachers notice individual learning gaps instead of teaching to a crowded room.",
      "\u09aa\u09cd\u09b0\u09a4\u09bf \u09ac\u09cd\u09af\u09be\u099a\u09c7 \u09b8\u09b0\u09cd\u09ac\u09cb\u099a\u09cd\u099a \u09e7\u09e8 \u099c\u09a8 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0 \u09a5\u09be\u0995\u09be\u09df \u09ad\u09bf\u09dc\u09c7\u09b0 \u09ae\u09a7\u09cd\u09af\u09c7 \u09aa\u09dc\u09be\u09a8\u09cb\u09b0 \u09ac\u09a6\u09b2\u09c7 \u09aa\u09cd\u09b0\u09a4\u09cd\u09af\u09c7\u0995 \u09b6\u09bf\u0995\u09cd\u09b7\u09be\u09b0\u09cd\u09a5\u09c0\u09b0 \u09b6\u09c7\u0996\u09be\u09b0 \u0998\u09be\u099f\u09a4\u09bf \u09b6\u09a8\u09be\u0995\u09cd\u09a4 \u0995\u09b0\u09be \u09b8\u09b9\u099c \u09b9\u09df\u0964",
    ],
    icon: UsersRound,
    offeringId: null,
    acceptingApplications: true,
  },
];
