"use client";

import Link from "next/link";
import Logo from "@/components/shared/logo";
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";

export function TeamSwitcher() {
  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton size="lg" asChild>
          <Link href="/dashboard" aria-label="Sohoj Academy Digital Campus">
            <div className="flex aspect-square size-8 items-center justify-center overflow-hidden rounded-lg bg-white ring-1 ring-sidebar-border">
              <Logo variant="mark" size={30} priority />
            </div>
            <div className="grid flex-1 text-left text-sm leading-tight">
              <span className="truncate font-semibold">Sohoj Academy</span>
              <span className="truncate text-xs">Digital Campus</span>
            </div>
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
