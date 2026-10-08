"use client";

import Link from "next/link";
import { useLanguage } from "@/components/providers/language-provider";
import { LogOut, UserRound } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";
import type { ErpContext } from "@/types/erp";

export function ErpAccount({ context }: { context: ErpContext }) {
  const router = useRouter();
  const { locale } = useLanguage();
  const [error, setError] = useState("");
  const [signingOut, setSigningOut] = useState(false);

  async function signOut() {
    if (signingOut) return;
    setSigningOut(true);

    setError("");
    try {
      const { error } = await createClient().auth.signOut();
      if (error) throw error;
      router.replace("/auth/sign-in");
      router.refresh();
    } catch {
      setError(
        locale === "bn"
          ? "সাইন আউট হয়নি। আবার চেষ্টা করুন।"
          : "Could not sign out. Try again.",
      );
      setSigningOut(false);
    }
  }

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <div className="mb-1 flex items-center gap-3 rounded-lg px-2 py-2 group-data-[collapsible=icon]:justify-center">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
            <UserRound className="size-4" aria-hidden="true" />
          </div>
          <div className="min-w-0 flex-1 group-data-[collapsible=icon]:hidden">
            <p className="truncate text-sm font-medium">
              {context.displayName}
            </p>
            <p className="truncate text-xs text-sidebar-foreground/60">
              {context.email}
            </p>
            <p className="truncate text-xs text-sidebar-foreground/70">
              {context.staffNo ?? ""}
              {context.staffNo ? " · " : ""}
              {context.roles
                .map((r) =>
                  locale === "bn"
                    ? ((
                        {
                          ADMIN: "প্রশাসক",
                          TEACHER: "শিক্ষক",
                          OPERATOR: "অপারেটর",
                          ACCOUNTANT: "হিসাবরক্ষক",
                          REFERRER: "রেফারাল সহযোগী",
                        } as Record<string, string>
                      )[r] ?? r)
                    : r,
                )
                .join(", ")}
            </p>
          </div>
        </div>
      </SidebarMenuItem>
      <SidebarMenuItem>
        <SidebarMenuButton
          asChild
          tooltip={locale === "bn" ? "আমার অ্যাকাউন্ট" : "My account"}
        >
          <Link href="/dashboard/account" prefetch={false}>
            <UserRound aria-hidden="true" />
            <span>{locale === "bn" ? "আমার অ্যাকাউন্ট" : "My account"}</span>
          </Link>
        </SidebarMenuButton>
        <SidebarMenuButton
          type="button"
          onClick={signOut}
          disabled={signingOut}
          tooltip={locale === "bn" ? "সাইন আউট" : "Sign out"}
        >
          <LogOut aria-hidden="true" />
          <span>
            {signingOut
              ? locale === "bn"
                ? "সাইন আউট হচ্ছে…"
                : "Signing out…"
              : locale === "bn"
                ? "সাইন আউট"
                : "Sign out"}
          </span>
        </SidebarMenuButton>
      </SidebarMenuItem>
      {error && (
        <li className="px-2 text-xs text-destructive" role="alert">
          {error}
        </li>
      )}
    </SidebarMenu>
  );
}
