"use client";

import { PreferenceControls } from "@/components/shared/preference-controls";

const sectionTitles: Record<string, string> = {
  dashboard: "Dashboard",
  admissions: "Admissions",
  students: "Students",
  guardians: "Guardians",
  attendance: "Attendance",
  assessments: "Assessments",
  progress: "Progress",
  fees: "Fee Structure",
  payments: "Fee Collection",
  parents: "Parent Communication",
  notices: "Notices",
  staff: "Staff",
  teachers: "Staff",
  settings: "Settings",
};

export function DashboardHeader({ section }: { section: string }) {
  const title = sectionTitles[section] ?? "Dashboard";

  return (
    <div className="flex min-w-0 flex-1 items-center justify-between gap-3">
      <div className="min-w-0">
        <p className="truncate font-semibold">{title}</p>
        <p className="truncate text-xs text-muted-foreground">
          Sohoj Academy Digital Campus
        </p>
      </div>
      <PreferenceControls showLanguage={false} compact className="shrink-0" />
    </div>
  );
}
