import type { ErpContext, ErpNavGroup, ErpNavItem } from "@/types/erp";

const groups: ErpNavGroup[] = [
  {
    title: "Workspace",
    items: [
      { title: "Dashboard", href: "/dashboard", permission: "dashboard.view" },
      {
        title: "Action Center",
        href: "/dashboard/action-center",
        permission: "action_center.view",
      },
    ],
  },
  {
    title: "CRM & Students",
    items: [
      {
        title: "Prospects",
        href: "/dashboard/crm/prospects",
        permission: "crm.prospects.view",
      },
      {
        title: "Students",
        href: "/dashboard/students",
        permission: "students.view",
      },
    ],
  },
  {
    title: "People",
    items: [
      {
        title: "Staff",
        href: "/dashboard/staff",
        permission: "staff.view",
      },
    ],
  },
  {
    title: "Governance",
    items: [
      {
        title: "Approvals",
        href: "/dashboard/governance/approvals",
        permission: "approvals.view",
      },
      {
        title: "Audit Trail",
        href: "/dashboard/governance/audit",
        permission: "audit.view",
      },
      {
        title: "Business Rules",
        href: "/dashboard/governance/rules",
        permission: "system.rules.view",
      },
      {
        title: "Settings",
        href: "/dashboard/settings",
        permission: "system.settings.view",
      },
    ],
  },
];

export function getNavigation(context: ErpContext): ErpNavGroup[] {
  return groups
    .map((group) => ({
      ...group,
      items: group.items.filter(
        (item) =>
          !item.permission || context.permissions.includes(item.permission)
      ),
    }))
    .filter((group) => group.items.length > 0);
}

export function canNavigate(context: ErpContext, item: ErpNavItem) {
  return !item.permission || context.permissions.includes(item.permission);
}
