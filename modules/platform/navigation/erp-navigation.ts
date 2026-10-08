import type { ErpContext, ErpNavGroup } from "@/types/erp";
import { erpRouteRegistry } from "./erp-route-registry";
import {
  navigationGroups,
  navigationOrder,
  navigationSections,
  workspaceHome,
} from "./workspace-navigation";
export function getNavigation(context: ErpContext): ErpNavGroup[] {
  const groups = new Map<string, ErpNavGroup>();
  const home = workspaceHome(context);
  const manager = context.permissions.includes("workforce.manage");
  const seen = new Set<string>();
  const routes = [...erpRouteRegistry].sort(
    (a, b) =>
      (navigationOrder.includes(a.id)
        ? navigationOrder.indexOf(a.id)
        : navigationOrder.length) -
      (navigationOrder.includes(b.id)
        ? navigationOrder.indexOf(b.id)
        : navigationOrder.length),
  );
  for (const route of routes) {
    if (!context.permissions.includes(route.permission) || seen.has(route.href))
      continue;
    // These remain reachable as contextual workflows; they are not duplicate sidebar destinations.
    if (["admin-review-queue", "account"].includes(route.id)) continue;
    if (route.id === "dashboard" && home !== "/dashboard") continue;
    if (route.id === "teacher-dashboard" && home !== "/dashboard/teacher")
      continue;
    if (
      route.id === "academic-operations" &&
      home === "/dashboard/teacher" &&
      !context.permissions.includes("academics.sessions.manage")
    )
      continue;
    if (
      ((route.id === "payroll" &&
        !context.permissions.includes("payroll.manage")) ||
        (route.id === "reimbursements" &&
          !context.permissions.includes("accounting.expense.manage"))) &&
      !manager &&
      context.permissions.includes("workforce.self.view")
    )
      continue;
    if (
      ["batches", "programme-offerings", "fee-plans"].includes(route.id) &&
      home === "/dashboard/teacher" &&
      !context.permissions.includes("academics.sessions.manage")
    )
      continue;
    const title = navigationGroups[route.id] ?? route.navGroup;
    const g = groups.get(title) ?? { title, items: [] };
    g.items.push({
      id: route.id,
      title: route.title,
      href: route.href,
      permission: route.permission,
      icon: route.icon,
    });
    groups.set(title, g);
    seen.add(route.href);
  }
  const ordered = navigationSections
    .map((k) => groups.get(k))
    .filter((g): g is ErpNavGroup => !!g);
  return [
    ...ordered,
    ...Array.from(groups.values()).filter(
      (g) => !navigationSections.includes(g.title),
    ),
  ];
}
