"use client";

import {
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { useSidebar } from "@/components/ui/sidebar";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { LogOut, Settings } from "lucide-react";
import { SignOutAlert } from "./sign-out-alert";
import { UserProfileSheet } from "./user-profile-sheet";
import type { User } from "@/types/user";

export function NavUserDropdown({ user }: { user: User }) {
  const { isMobile } = useSidebar();

  return (
    <DropdownMenuContent
      className="w-(--radix-dropdown-menu-trigger-width) min-w-56 rounded-lg"
      side={isMobile ? "bottom" : "right"}
      align="end"
      sideOffset={4}
    >
      <DropdownMenuLabel className="p-0 font-normal">
        <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
          <Avatar className="h-8 w-8 rounded-lg">
            <AvatarImage src={user.avatar ?? undefined} alt="User Photo" />
            <AvatarFallback className="rounded-lg">CN</AvatarFallback>
          </Avatar>
          <div className="grid flex-1 text-left text-sm leading-tight">
            <span className="truncate font-medium">{user.name}</span>
            <span className="truncate text-xs">{user.email}</span>
          </div>
        </div>
      </DropdownMenuLabel>

      <DropdownMenuSeparator />

      <DropdownMenuGroup>
        <UserProfileSheet>
          <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
            <Settings />
            Manage Account
          </DropdownMenuItem>
        </UserProfileSheet>
      </DropdownMenuGroup>

      <DropdownMenuSeparator />

      <SignOutAlert>
        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
          <LogOut />
          Sign Out
        </DropdownMenuItem>
      </SignOutAlert>
    </DropdownMenuContent>
  );
}
