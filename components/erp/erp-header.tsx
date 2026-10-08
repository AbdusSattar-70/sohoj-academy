"use client";

import { CentralSearch } from "./central-search";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { useLanguage } from "@/components/providers/language-provider";
import {
  navigationLabel,
  navigationGroups,
} from "@/modules/platform/navigation/workspace-navigation";
import { CircleHelp } from "lucide-react";
import { Separator } from "@/components/ui/separator";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { getErpRoute } from "@/modules/platform/navigation/erp-route-registry";

export function ErpHeader({
  canHelp = true,
  permissions = [],
}: {
  canHelp?: boolean;
  permissions?: string[];
}) {
  const pathname = usePathname();
  const current = getErpRoute(pathname);
  const { locale } = useLanguage();

  return (
    <header className="sticky top-0 z-30 flex min-h-16 items-center gap-3 border-b bg-background/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/85 sm:px-6">
      <SidebarTrigger className="-ml-1 md:hidden" />
      <Separator orientation="vertical" className="h-6" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
          {current
            ? navigationLabel(
                navigationGroups[current.id] ?? current.eyebrow,
                current.eyebrow,
                locale,
              )
            : "Sohoj Academy ERP"}
        </p>
        <p className="truncate text-sm font-semibold sm:text-base">
          {current
            ? navigationLabel(current.id, current.title, locale)
            : locale === "bn"
              ? "কর্মক্ষেত্র"
              : "Workspace"}
        </p>
      </div>
      <CentralSearch permissions={permissions} />
      {canHelp && (
        <Link
          prefetch={false}
          href="/dashboard/help"
          aria-label={locale === "bn" ? "সহায়তা খুলুন" : "Open help"}
          title={locale === "bn" ? "সহায়তা ও কাজের ধাপ" : "Help & workflows"}
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <CircleHelp className="size-5" aria-hidden="true" />
        </Link>
      )}
    </header>
  );
}
