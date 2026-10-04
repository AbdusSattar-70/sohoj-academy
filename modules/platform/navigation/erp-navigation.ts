import type { ErpContext, ErpNavGroup } from "@/types/erp";
import { erpRouteRegistry } from "./erp-route-registry";

const groupOrder = ["Workspace", "People", "Academics", "Billing", "Settings", "Activity"];
const routeOrder = [
  "dashboard", "my-work", "action-center",
  "students", "staff", "staff-operations", "referrals",
  "admissions", "prospects", "programme-offerings", "batches",
  "teacher-dashboard", "academic-operations", "assessments", "question-bank",
  "student-accounts", "receivables", "purchases", "payroll", "reimbursements", "accounting",
  "academic-directory", "fee-plans", "operating-rules", "access-security",
  "admin-review-queue", "audit",
];

export function getNavigation(context: ErpContext): ErpNavGroup[] {
  const permitted = erpRouteRegistry.filter(
    route => !route.hidden && context.permissions.includes(route.permission),
  );
  return groupOrder.flatMap(title => {
    const items = permitted
      .filter(route => route.navGroup === title)
      .sort((a, b) => routeOrder.indexOf(a.id) - routeOrder.indexOf(b.id))
      .map(route => ({
        id: route.id, title: route.title, href: route.href,
        permission: route.permission, icon: route.icon,
      }));
    return items.length ? [{ title, items }] : [];
  });
}
