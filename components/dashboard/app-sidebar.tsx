import * as React from "react";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar";
import { TeamSwitcher } from "./team-switcher";
import { NavMain } from "./nav-main";
import { NavUser } from "./nav-user";
import { ClerkLoadingButton } from "@/components/shared/clerk-loading-button";
import { User } from "@/types/user";

export function AppSidebar({ user, ...props }: { user: User }) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <TeamSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain />
      </SidebarContent>
      <SidebarFooter>
        <ClerkLoadingButton>
          <NavUser user={user} />
        </ClerkLoadingButton>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
