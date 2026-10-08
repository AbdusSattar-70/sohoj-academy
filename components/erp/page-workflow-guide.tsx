"use client";
import { LocalizedText } from "@/components/shared/localized-text";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { CircleHelp, ArrowRight } from "lucide-react";
import { useLanguage } from "@/components/providers/language-provider";
import {
  getErpRoute,
  erpRouteRegistry,
} from "@/modules/platform/navigation/erp-route-registry";
import { workflowGuides } from "@/modules/platform/navigation/workflow-guides";
import { navigationLabel } from "@/modules/platform/navigation/workspace-navigation";
import { Button } from "@/components/ui/button";
export function PageWorkflowGuide({ permissions }: { permissions: string[] }) {
  const path = usePathname(),
    { locale } = useLanguage();
  const route = getErpRoute(path);
  const guide = route && workflowGuides[route.id];
  if (!guide || /\/print$/.test(path)) return null;
  return (
    <details
      key={route.id}
      className="mb-5 rounded-xl border bg-card print:hidden"
    >
      <summary className="flex min-h-11 cursor-pointer list-none items-center gap-2 rounded-xl px-4 py-3 text-sm font-medium hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
        <CircleHelp className="size-4" aria-hidden="true" />
        {locale === "bn" ? "এই পেজে কীভাবে কাজ করবেন" : "How to use this page"}
        <span className="ml-auto text-xs text-muted-foreground">
          {locale === "bn" ? "নির্দেশনা খুলুন" : "Open guide"}
        </span>
      </summary>
      <div className="space-y-3 border-t px-4 py-4">
        <p className="font-semibold">
          <LocalizedText en={guide.en} bn={guide.bn} />
        </p>
        <ol className="list-decimal space-y-2 pl-5 text-sm leading-6">
          {guide.steps.map(([en, bn], i) => (
            <li key={i}>
              <LocalizedText en={en} bn={bn} />
            </li>
          ))}
        </ol>
        <div className="flex flex-wrap gap-2">
          {guide.next?.map((id) => {
            const r = erpRouteRegistry.find((x) => x.id === id);
            return r && permissions.includes(r.permission) ? (
              <Button key={id} asChild variant="outline">
                <Link prefetch={false} href={r.href}>
                  {navigationLabel(id, r.title, locale)}
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
              </Button>
            ) : null;
          })}
        </div>
      </div>
    </details>
  );
}
