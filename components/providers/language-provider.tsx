"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type AppLocale = "en" | "bn";

const STORAGE_KEY = "sohoj-locale";

const dictionary = {
  en: {
    language: "Language",
    theme: "Theme",
    english: "English",
    bengali: "বাংলা",
    light: "Light",
    dark: "Dark",
    system: "System",
    programs: "Programs",
    learningMethod: "Learning Method",
    whySohoj: "Why Sohoj",
    digitalCampus: "Digital Campus",
    registerInterest: "Register Interest",
    openDigitalCampus: "Open Digital Campus",
    skipToContent: "Skip to main content",
    dashboard: "Dashboard",
    sohojDigitalCampus: "Sohoj Academy Digital Campus",
  },
  bn: {
    language: "ভাষা",
    theme: "থিম",
    english: "English",
    bengali: "বাংলা",
    light: "লাইট",
    dark: "ডার্ক",
    system: "সিস্টেম",
    programs: "প্রোগ্রামসমূহ",
    learningMethod: "শেখার পদ্ধতি",
    whySohoj: "কেন সহজ",
    digitalCampus: "ডিজিটাল ক্যাম্পাস",
    registerInterest: "আগ্রহ নিবন্ধন",
    openDigitalCampus: "ডিজিটাল ক্যাম্পাস খুলুন",
    skipToContent: "মূল কনটেন্টে যান",
    dashboard: "ড্যাশবোর্ড",
    sohojDigitalCampus: "সহজ একাডেমি ডিজিটাল ক্যাম্পাস",
  },
} as const;

type TranslationKey = keyof typeof dictionary.en;

type LanguageContextValue = {
  locale: AppLocale;
  setLocale: (locale: AppLocale) => void;
  toggleLocale: () => void;
  t: (key: TranslationKey) => string;
};

const LanguageContext = createContext<LanguageContextValue | null>(null);

function getInitialLocale(): AppLocale {
  if (typeof window === "undefined") return "en";
  const stored = window.localStorage.getItem(STORAGE_KEY);
  if (stored === "bn" || stored === "en") return stored;
  return navigator.language.toLowerCase().startsWith("bn") ? "bn" : "en";
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<AppLocale>("en");

  useEffect(() => {
    const initial = getInitialLocale();
    setLocaleState(initial);
    document.documentElement.lang = initial === "bn" ? "bn-BD" : "en";
  }, []);

  const setLocale = useCallback((next: AppLocale) => {
    setLocaleState(next);
    window.localStorage.setItem(STORAGE_KEY, next);
    document.documentElement.lang = next === "bn" ? "bn-BD" : "en";
  }, []);

  const toggleLocale = useCallback(() => {
    setLocale(locale === "en" ? "bn" : "en");
  }, [locale, setLocale]);

  const value = useMemo<LanguageContextValue>(
    () => ({
      locale,
      setLocale,
      toggleLocale,
      t: (key) => dictionary[locale][key],
    }),
    [locale, setLocale, toggleLocale]
  );

  return (
    <LanguageContext.Provider value={value}>
      <div data-locale={locale}>{children}</div>
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error("useLanguage must be used within LanguageProvider.");
  }
  return context;
}
