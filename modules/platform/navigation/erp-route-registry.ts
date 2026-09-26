export type ErpRouteIcon =
  | "dashboard"
  | "action-center"
  | "prospects"
  | "students"
  | "staff"
  | "offerings"
  | "fee-plans"
  | "approvals"
  | "audit"
  | "rules"
  | "settings";

export type ErpRouteDefinition = {
  id: string;
  title: string;
  eyebrow: string;
  href: string;
  navGroup: string;
  permission: string;
  icon: ErpRouteIcon;
  exact?: boolean;
};

export const erpRouteRegistry: ErpRouteDefinition[] = [
  {
    id: "academic-operations",
    title: "Academic Operations",
    eyebrow: "Academics",
    href: "/dashboard/academics/operations",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },

  {
    id: "billing",
    title: "Billing & Adjustments",
    eyebrow: "Finance",
    href: "/dashboard/finance/billing",
    navGroup: "Finance",
    permission: "finance.view",
    icon: "fee-plans",
  },
  {
    id: "dashboard",
    title: "Dashboard",
    eyebrow: "Workspace",
    href: "/dashboard",
    navGroup: "Workspace",
    permission: "dashboard.view",
    icon: "dashboard",
    exact: true,
  },
  {
    id: "action-center",
    title: "Action Center",
    eyebrow: "Workspace",
    href: "/dashboard/action-center",
    navGroup: "Workspace",
    permission: "action_center.view",
    icon: "action-center",
  },
  {
    id: "prospects",
    title: "Prospects",
    eyebrow: "CRM & Student Bank",
    href: "/dashboard/crm/prospects",
    navGroup: "CRM & Students",
    permission: "crm.prospects.view",
    icon: "prospects",
  },
  {
    id: "students",
    title: "Students",
    eyebrow: "Student Core",
    href: "/dashboard/students",
    navGroup: "CRM & Students",
    permission: "students.view",
    icon: "students",
  },
  {
    id: "admissions",
    title: "Admissions",
    eyebrow: "Student Lifecycle",
    href: "/dashboard/admissions",
    navGroup: "CRM & Students",
    permission: "admissions.view",
    icon: "students",
  },
  {
    id: "batches",
    title: "Batches",
    eyebrow: "Academics",
    href: "/dashboard/academics/batches",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },
  {
    id: "staff",
    title: "Staff",
    eyebrow: "People",
    href: "/dashboard/staff",
    navGroup: "People",
    permission: "staff.view",
    icon: "staff",
  },
  {
    id: "programme-offerings",
    title: "Programme Offerings",
    eyebrow: "Academics",
    href: "/dashboard/academics/offerings",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },
  {
    id: "fee-plans",
    title: "Fee Plans",
    eyebrow: "Finance / Control Center",
    href: "/dashboard/finance/fee-plans",
    navGroup: "Finance",
    permission: "finance.view",
    icon: "fee-plans",
  },
  {
    id: "approvals",
    title: "Approvals",
    eyebrow: "Governance",
    href: "/dashboard/governance/approvals",
    navGroup: "Governance",
    permission: "approvals.view",
    icon: "approvals",
  },
  {
    id: "audit",
    title: "Audit Trail",
    eyebrow: "Governance",
    href: "/dashboard/governance/audit",
    navGroup: "Governance",
    permission: "audit.view",
    icon: "audit",
  },
  {
    id: "business-rules",
    title: "Business Rules",
    eyebrow: "Governance",
    href: "/dashboard/governance/rules",
    navGroup: "Governance",
    permission: "system.rules.view",
    icon: "rules",
  },
  {
    id: "settings",
    title: "Settings",
    eyebrow: "Control Center",
    href: "/dashboard/settings",
    navGroup: "Governance",
    permission: "system.settings.view",
    icon: "settings",
  },
];

export function routeMatches(pathname: string, route: ErpRouteDefinition) {
  if (
    route.id === "academic-operations" &&
    pathname.startsWith("/dashboard/academics/sessions/")
  )
    return true;
  if (route.exact) return pathname === route.href;
  return pathname === route.href || pathname.startsWith(`${route.href}/`);
}

export function getErpRoute(pathname: string) {
  return (
    erpRouteRegistry
      .filter((route) => routeMatches(pathname, route))
      .sort((a, b) => b.href.length - a.href.length)[0] ?? erpRouteRegistry[0]
  );
}
