"use client";

import Link from "next/link";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import {
  navigationLabel,
  workspaceHome,
} from "@/modules/platform/navigation/workspace-navigation";
import { usePathname } from "next/navigation";
import {
  Activity,
  ChevronDown,
  Search,
  BookOpenCheck,
  ClipboardCheck,
  LayoutDashboard,
  ListChecks,
  ScrollText,
  Settings2,
  ShieldCheck,
  UserRoundSearch,
  UsersRound,
  GraduationCap,
  Calculator,
  CircleHelp,
} from "lucide-react";
import Logo from "@/components/shared/logo";
import { ErpAccount } from "@/components/erp/erp-account";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import type { ErpContext, ErpNavGroup, ErpNavIcon } from "@/types/erp";
import { getErpRoute } from "@/modules/platform/navigation/erp-route-registry";

const icons: Record<ErpNavIcon, typeof LayoutDashboard> = {
  dashboard: LayoutDashboard,
  "action-center": ListChecks,
  prospects: UserRoundSearch,
  students: BookOpenCheck,
  staff: UsersRound,
  offerings: BookOpenCheck,
  "fee-plans": Settings2,
  approvals: ClipboardCheck,
  audit: ScrollText,
  rules: ShieldCheck,
  settings: Settings2,
  teacher: GraduationCap,
  accounting: Calculator,
  help: CircleHelp,
};

function isActive(pathname: string, id: string) {
  const current = getErpRoute(pathname)?.id;
  return (
    current === id ||
    (id === "action-center" && current === "admin-review-queue") ||
    (id === "teacher-dashboard" && current === "academic-operations")
  );
}

export function ErpSidebar({
  context,
  navigation,
}: {
  context: ErpContext;
  navigation: ErpNavGroup[];
}) {
  const pathname = usePathname();
  const { locale } = useLanguage();
  const { setOpenMobile } = useSidebar();
  const [search, setSearch] = useState("");
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const label = (id: string, title: string) =>
    navigationLabel(id, title, locale);
  const visible = navigation
    .map((g) => ({
      ...g,
      items: g.items.filter((i) => {
        const text = label(i.id, i.title);
        return (
          !search ||
          (text + " " + i.title)
            .toLocaleLowerCase()
            .includes(search.toLocaleLowerCase())
        );
      }),
    }))
    .filter((g) => g.items.length);

  return (
    <Sidebar collapsible="icon" variant="sidebar">
      <SidebarHeader className="border-b border-sidebar-border">
        <Link
          href={workspaceHome(context)}
          className="flex min-h-14 items-center gap-3 rounded-lg px-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring"
          aria-label={
            locale === "bn"
              ? "সহজ একাডেমির কর্মক্ষেত্র"
              : "Sohoj Academy workspace"
          }
        >
          <Logo variant="mark" size={36} priority />
          <div className="min-w-0 group-data-[collapsible=icon]:hidden">
            <p className="truncate text-sm font-bold">Sohoj Academy</p>
            <p className="truncate text-[11px] text-sidebar-foreground/60">
              {locale === "bn" ? "পরিচালনার কর্মক্ষেত্র" : "Academy workspace"}
            </p>
          </div>
        </Link>
        <div className="flex items-center gap-2">
          <SidebarTrigger
            className="hidden cursor-pointer md:inline-flex"
            aria-label={
              locale === "bn"
                ? "মেনু ছোট বা বড় করুন"
                : "Collapse or expand navigation"
            }
          />
          <span className="text-xs text-muted-foreground group-data-[collapsible=icon]:hidden">
            {locale === "bn" ? "মেনু" : "Navigation"}
          </span>
        </div>
        <label className="flex items-center gap-2 rounded-lg border px-2 group-data-[collapsible=icon]:hidden">
          <Search className="size-4" aria-hidden="true" />
          <input
            aria-label={locale === "bn" ? "মেনু খুঁজুন" : "Find a page"}
            placeholder={locale === "bn" ? "মেনু খুঁজুন…" : "Find a page…"}
            className="min-h-10 min-w-0 w-full bg-transparent text-sm outline-none"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
      </SidebarHeader>

      <SidebarContent className="py-2">
        {visible.map((group, index) => {
          const activeGroup = group.items.some((i) => isActive(pathname, i.id));
          const open =
            !!search || (expanded[group.title] ?? (activeGroup || index === 0));
          return (
            <SidebarGroup key={group.title}>
              <SidebarGroupLabel asChild>
                <button
                  type="button"
                  className="cursor-pointer"
                  aria-expanded={open}
                  aria-controls={"nav-" + group.title.replaceAll(" ", "-")}
                  onClick={() =>
                    setExpanded((x) => ({ ...x, [group.title]: !open }))
                  }
                >
                  {label(group.title, group.title)}
                  <ChevronDown
                    aria-hidden="true"
                    className={
                      "ml-auto size-3 transition-transform " +
                      (open ? "" : "-rotate-90")
                    }
                  />
                </button>
              </SidebarGroupLabel>
              <SidebarMenu
                id={"nav-" + group.title.replaceAll(" ", "-")}
                className={
                  open ? "" : "hidden group-data-[collapsible=icon]:block"
                }
              >
                {group.items.map((item) => {
                  const Icon = icons[item.icon] ?? Activity;
                  const active =
                    isActive(pathname, item.id) ||
                    (item.id === "teacher-dashboard" &&
                      pathname === "/dashboard/academics/operations");

                  return (
                    <SidebarMenuItem key={item.href}>
                      <SidebarMenuButton
                        asChild
                        className="min-h-11 cursor-pointer"
                        isActive={active}
                        tooltip={
                          item.id === "referrals" &&
                          !context.permissions.includes("staff.manage")
                            ? label("own-referrals", item.title)
                            : label(item.id, item.title)
                        }
                      >
                        <Link
                          href={item.href}
                          prefetch={false}
                          onClick={() => setOpenMobile(false)}
                          onNavigate={(e) =>
                            guardWorkspaceNavigation(e, locale)
                          }
                          aria-current={active ? "page" : undefined}
                        >
                          <Icon aria-hidden="true" />
                          <span>
                            {item.id === "referrals" &&
                            !context.permissions.includes("staff.manage")
                              ? label("own-referrals", item.title)
                              : label(item.id, item.title)}
                          </span>
                        </Link>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  );
                })}
              </SidebarMenu>
            </SidebarGroup>
          );
        })}
        {!visible.length && (
          <p
            role="status"
            className="px-4 py-3 text-sm group-data-[collapsible=icon]:hidden"
          >
            {locale === "bn"
              ? "মিল পাওয়া যায়নি। অন্য শব্দ দিয়ে খুঁজুন।"
              : "No matching page. Try another word."}
          </p>
        )}
      </SidebarContent>

      <SidebarFooter className="border-t border-sidebar-border">
        <ErpAccount context={context} />
      </SidebarFooter>
    </Sidebar>
  );
}
