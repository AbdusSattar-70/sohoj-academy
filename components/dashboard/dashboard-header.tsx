"use client";

import { PreferenceControls } from "@/components/shared/preference-controls";
import { useLanguage, type TranslationKey } from "@/components/providers/language-provider";

const sectionKeys: Record<string, TranslationKey> = {
  dashboard: "dashboard",
  admissions: "admissions",
  students: "students",
  guardians: "guardians",
  attendance: "attendance",
  assessments: "assessments",
  progress: "progress",
  fees: "feeStructure",
  payments: "feeCollection",
  parents: "parentCommunication",
  notices: "notices",
  teachers: "teachers",
  settings: "settings",
};

export function DashboardHeader({ section }: { section: string }) {
  const { t } = useLanguage();
  const title = t(sectionKeys[section] ?? "dashboard");

  return (
    <div className="flex min-w-0 flex-1 items-center justify-between gap-3">
      <div className="min-w-0">
        <p className="truncate font-semibold">{title}</p>
        <p className="truncate text-xs text-muted-foreground">
          {t("sohojDigitalCampus")}
        </p>
      </div>
      <PreferenceControls compact className="shrink-0" />
    </div>
  );
}
