"use client";

import { usePathname } from "next/navigation";
import { PreferenceControls } from "@/components/shared/preference-controls";
import { Separator } from "@/components/ui/separator";
import { SidebarTrigger } from "@/components/ui/sidebar";

const titles: Record<string, { title: string; eyebrow: string }> = {
  "/dashboard": { title: "Dashboard", eyebrow: "Workspace" },
  "/dashboard/action-center": {
    title: "Action Center",
    eyebrow: "Workspace",
  },
  "/dashboard/crm/prospects": {
    title: "Prospects",
    eyebrow: "CRM & Student Bank",
  },
  "/dashboard/students": {
    title: "Students",
    eyebrow: "Student Core",
  },
  "/dashboard/staff": {
    title: "Staff",
    eyebrow: "People",
  },
  "/dashboard/governance/approvals": {
    title: "Approvals",
    eyebrow: "Governance",
  },
  "/dashboard/governance/audit": {
    title: "Audit Trail",
    eyebrow: "Governance",
  },
  "/dashboard/governance/rules": {
    title: "Business Rules",
    eyebrow: "Governance",
  },
  "/dashboard/settings": {
    title: "Settings",
    eyebrow: "Control Center",
  },
};

export function ErpHeader() {
  const pathname = usePathname();
  const exact = titles[pathname];
  const fallback = Object.entries(titles)
    .filter(([href]) => href !== "/dashboard" && pathname.startsWith(`${href}/`))
    .sort((a, b) => b[0].length - a[0].length)[0]?.[1];
  const current = exact ?? fallback ?? titles["/dashboard"];

  return (
    <header className="sticky top-0 z-30 flex min-h-16 items-center gap-3 border-b bg-background/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/85 sm:px-6">
      <SidebarTrigger className="-ml-1" />
      <Separator orientation="vertical" className="h-6" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
          {current.eyebrow}
        </p>
        <h1 className="truncate text-sm font-semibold sm:text-base">
          {current.title}
        </h1>
      </div>
      <PreferenceControls
        showLanguage={false}
        compact
        className="shrink-0"
      />
    </header>
  );
}
