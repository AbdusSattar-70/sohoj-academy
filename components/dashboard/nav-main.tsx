"use client";

import type { ComponentType } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  CalendarDays,
  ChevronRight,
  CircleDollarSign,
  GraduationCap,
  LayoutDashboard,
  Settings2,
  Users,
} from "lucide-react";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
} from "@/components/ui/sidebar";
import { useLanguage, type TranslationKey } from "@/components/providers/language-provider";
import type { AppRole } from "@/lib/constants";

type NavLeaf = {
  titleKey: TranslationKey;
  url: string;
  roles: AppRole[];
};

type NavGroup = {
  titleKey: TranslationKey;
  url?: string;
  icon: ComponentType<{ className?: string }>;
  roles: AppRole[];
  items: NavLeaf[];
};

const allRoles: AppRole[] = ["ADMIN", "OPERATOR", "TEACHER", "GUARDIAN", "STUDENT"];
const staffRoles: AppRole[] = ["ADMIN", "OPERATOR", "TEACHER"];
const financeRoles: AppRole[] = ["ADMIN", "OPERATOR"];

const groups: NavGroup[] = [
  {
    titleKey: "dashboard",
    url: "/dashboard",
    icon: LayoutDashboard,
    roles: allRoles,
    items: [],
  },
  {
    titleKey: "academic",
    icon: GraduationCap,
    roles: staffRoles,
    items: [
      { titleKey: "admissions", url: "/dashboard/admissions", roles: ["ADMIN", "OPERATOR"] },
      { titleKey: "students", url: "/dashboard/students", roles: staffRoles },
      { titleKey: "guardians", url: "/dashboard/guardians", roles: staffRoles },
      { titleKey: "attendance", url: "/dashboard/attendance", roles: staffRoles },
      { titleKey: "assessments", url: "/dashboard/assessments", roles: staffRoles },
      { titleKey: "progress", url: "/dashboard/progress", roles: staffRoles },
    ],
  },
  {
    titleKey: "finance",
    icon: CircleDollarSign,
    roles: financeRoles,
    items: [
      { titleKey: "feeStructure", url: "/dashboard/fees", roles: financeRoles },
      { titleKey: "feeCollection", url: "/dashboard/payments", roles: financeRoles },
    ],
  },
  {
    titleKey: "communication",
    icon: Users,
    roles: staffRoles,
    items: [
      { titleKey: "parentCommunication", url: "/dashboard/parents", roles: staffRoles },
      { titleKey: "notices", url: "/dashboard/notices", roles: ["ADMIN", "OPERATOR"] },
    ],
  },
  {
    titleKey: "management",
    icon: CalendarDays,
    roles: staffRoles,
    items: [{ titleKey: "teachers", url: "/dashboard/teachers", roles: staffRoles }],
  },
  {
    titleKey: "settingsGroup",
    icon: Settings2,
    roles: ["ADMIN"],
    items: [{ titleKey: "settings", url: "/dashboard/settings", roles: ["ADMIN"] }],
  },
];

function isCurrent(pathname: string, url: string) {
  if (url === "/dashboard") return pathname === url;
  return pathname === url || pathname.startsWith(`${url}/`);
}

export function NavMain({ role }: { role: AppRole }) {
  const pathname = usePathname();
  const { t } = useLanguage();

  const visibleGroups = groups
    .filter((group) => group.roles.includes(role))
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => item.roles.includes(role)),
    }))
    .filter((group) => group.url || group.items.length > 0);

  return (
    <SidebarGroup>
      <SidebarGroupLabel>Sohoj Academy</SidebarGroupLabel>
      <SidebarMenu>
        {visibleGroups.map((group) => {
          const groupTitle = t(group.titleKey);

          if (group.items.length === 0 && group.url) {
            const active = isCurrent(pathname, group.url);
            return (
              <SidebarMenuItem key={group.titleKey}>
                <SidebarMenuButton asChild tooltip={groupTitle} isActive={active}>
                  <Link href={group.url} aria-current={active ? "page" : undefined}>
                    <group.icon />
                    <span>{groupTitle}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            );
          }

          const groupActive = group.items.some((item) => isCurrent(pathname, item.url));

          return (
            <Collapsible
              key={group.titleKey}
              asChild
              defaultOpen={groupActive || group.titleKey === "academic"}
              className="group/collapsible"
            >
              <SidebarMenuItem>
                <CollapsibleTrigger asChild>
                  <SidebarMenuButton tooltip={groupTitle} isActive={groupActive}>
                    <group.icon />
                    <span>{groupTitle}</span>
                    <ChevronRight
                      className="ml-auto transition-transform group-data-[state=open]/collapsible:rotate-90"
                      aria-hidden="true"
                    />
                  </SidebarMenuButton>
                </CollapsibleTrigger>
                <CollapsibleContent>
                  <SidebarMenuSub>
                    {group.items.map((item) => {
                      const active = isCurrent(pathname, item.url);
                      const itemTitle = t(item.titleKey);

                      return (
                        <SidebarMenuSubItem key={item.url}>
                          <SidebarMenuSubButton asChild isActive={active}>
                            <Link href={item.url} aria-current={active ? "page" : undefined}>
                              <span>{itemTitle}</span>
                            </Link>
                          </SidebarMenuSubButton>
                        </SidebarMenuSubItem>
                      );
                    })}
                  </SidebarMenuSub>
                </CollapsibleContent>
              </SidebarMenuItem>
            </Collapsible>
          );
        })}
      </SidebarMenu>
    </SidebarGroup>
  );
}
