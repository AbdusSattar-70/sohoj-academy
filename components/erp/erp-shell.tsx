import type { ReactNode } from "react";
import { ErpSidebar } from "@/components/erp/erp-sidebar";
import { ErpHeader } from "@/components/erp/erp-header";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";
import { getNavigation } from "@/modules/platform/navigation/erp-navigation";
import type { ErpContext } from "@/types/erp";

export function ErpShell({
  context,
  children,
}: {
  context: ErpContext;
  children: ReactNode;
}) {
  const navigation = getNavigation(context);

  return (
    <SidebarProvider>
      <ErpSidebar context={context} navigation={navigation} />
      <SidebarInset className="min-w-0 bg-muted/20">
        <ErpHeader />
        <main
          id="erp-main"
          className="mx-auto w-full max-w-[1600px] flex-1 px-4 py-5 sm:px-6 lg:px-8 lg:py-7"
        >
          {children}
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
