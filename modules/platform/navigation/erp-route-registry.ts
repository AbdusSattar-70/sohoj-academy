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
  | "settings"
  | "teacher"
  | "accounting"
  | "help";

export type ErpRouteDefinition = {
  id: string;
  title: string;
  eyebrow: string;
  href: string;
  navGroup: string;
  permission: string;
  icon: ErpRouteIcon;
  exact?: boolean;
  /** Legacy route metadata may remain available without appearing in navigation. */
  hidden?: boolean;
};

export const erpRouteRegistry: ErpRouteDefinition[] = [
  {id:"procurement-orders",title:"Orders & partial receipts",eyebrow:"Finance",href:"/dashboard/finance/procurement",navGroup:"Finance",permission:"accounting.expense.manage",icon:"accounting",hidden:true},
  {id:"consumable-stock",title:"Consumable stock",eyebrow:"Finance",href:"/dashboard/finance/stock",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"supplier-accounts",title:"Supplier accounts",eyebrow:"Finance",href:"/dashboard/finance/suppliers",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"year-end",title:"Year closing",eyebrow:"Finance",href:"/dashboard/finance/year-end",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"cash-flow",title:"Cash flow",eyebrow:"Finance",href:"/dashboard/finance/cash-flow",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"bank-matching",title:"Bank statements & matching",eyebrow:"Finance",href:"/dashboard/finance/bank",navGroup:"Finance",permission:"accounting.reconcile",icon:"accounting",hidden:true},
  {id:"finance-planning",title:"Budgets & programme contribution",eyebrow:"Finance",href:"/dashboard/finance/planning",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"owner-capital",title:"Owner capital & funding",eyebrow:"Finance",href:"/dashboard/finance/capital",navGroup:"Finance",permission:"accounting.reconcile",icon:"accounting",hidden:true},
  {id:"receivables",title:"Receivables & collection follow-up",eyebrow: "Billing",href:"/dashboard/finance/receivables",navGroup: "Billing",permission:"finance.view",icon:"accounting"},
  {id:"recurring-expenses",title:"Recurring expenses",eyebrow:"Finance",href:"/dashboard/finance/recurring",navGroup:"Finance",permission:"accounting.expense.manage",icon:"accounting",hidden:true},
  {id:"cash-counters",title:"Cash counters & opening float",eyebrow:"Finance",href:"/dashboard/finance/counters",navGroup:"Finance",permission:"workforce.self.view",icon:"accounting",hidden:true},
  {id:"cash-handovers",title:"Cash handover receipts",eyebrow:"Finance",href:"/dashboard/finance/handovers",navGroup:"Finance",permission:"workforce.self.view",icon:"accounting",hidden:true},
  {id:"assets",title:"Assets & custody",eyebrow:"Finance",href:"/dashboard/finance/assets",navGroup:"Finance",permission:"workforce.self.view",icon:"accounting",hidden:true},
  {id:"reimbursements",title:"Staff expense claims",eyebrow: "Billing",href:"/dashboard/finance/reimbursements",navGroup: "Billing",permission:"workforce.self.view",icon:"accounting"},
  {id:"purchases",title: "Running expenses",eyebrow: "Billing",href:"/dashboard/finance/purchases",navGroup: "Billing",permission:"accounting.expense.manage",icon:"accounting"},
  {id:"financial-reports",title:"Monthly accounts & period close",eyebrow:"Finance",href:"/dashboard/finance/reports",navGroup:"Finance",permission:"accounting.view",icon:"accounting",hidden:true},
  {id:"daily-close",title:"Daily cash & statement close",eyebrow:"Finance",href:"/dashboard/finance/daily-close",navGroup:"Finance",permission:"accounting.reconcile",icon:"accounting",hidden:true},
  {id:"payroll",title:"Payroll & payslips",eyebrow: "Billing",href:"/dashboard/finance/payroll",navGroup: "Billing",permission:"workforce.self.view",icon:"accounting"},
  {id:"my-work",title:"My work & attendance",eyebrow: "Workspace",href:"/dashboard/my-work",navGroup: "Workspace",permission:"workforce.self.view",icon:"staff"},
  {id:"staff-operations",title:"Staff attendance & terms",eyebrow: "People",href:"/dashboard/staff/operations",navGroup: "People",permission:"workforce.manage",icon:"staff"},
  { id: "referrals", title: "Referrers / My referrals", eyebrow: "People", href: "/dashboard/referrals", navGroup: "People", permission: "referrals.portal.view", icon: "students" },
  // Workspace
  {
    id: "dashboard",
    title: "Today",
    eyebrow: "Workspace",
    href: "/dashboard",
    navGroup: "Workspace",
    permission: "dashboard.view",
    icon: "dashboard",
    exact: true,
  },
  {
    id: "action-center",
    title: "Tasks & reviews",
    eyebrow: "Workspace",
    href: "/dashboard/action-center",
    navGroup: "Workspace",
    permission: "action_center.view",
    icon: "action-center",
  },

  // Admissions & Students
  {
    id: "admissions",
    title: "Admissions",
    eyebrow: "Academics",
    href: "/dashboard/admissions",
    navGroup: "Academics",
    permission: "admissions.view",
    icon: "students",
  },
  {
    id: "students",
    title: "Students",
    eyebrow: "People",
    href: "/dashboard/students",
    navGroup: "People",
    permission: "students.view",
    icon: "students",
  },
  {
    id: "prospects",
    title: "Enquiries",
    eyebrow: "Academics",
    href: "/dashboard/crm/prospects",
    navGroup: "Academics",
    permission: "crm.prospects.view",
    icon: "prospects",
  },

  // Teaching & Academics
  {
    id: "teacher-dashboard",
    title: "My Classes",
    eyebrow: "Academics",
    href: "/dashboard/teacher",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "teacher",
  },
  {
    id: "academic-operations",
    title: "Sessions & Attendance",
    eyebrow: "Academics",
    href: "/dashboard/academics/operations",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },
  {
    id: "assessments",
    title: "Assessments",
    eyebrow: "Academics",
    href: "/dashboard/academics/assessments",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },
  {
    id: "question-bank",
    title: "Question Bank",
    eyebrow: "Academics",
    href: "/dashboard/academics/questions",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
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

  // Finance
  {
    id: "student-accounts",
    title: "Student fees & collections",
    eyebrow: "Billing",
    href: "/dashboard/finance/billing",
    navGroup: "Billing",
    permission: "finance.view",
    icon: "fee-plans",
  },
  {
    id: "accounting",
    title: "Expenses & remuneration",
    eyebrow: "Billing",
    href: "/dashboard/finance/accounting",
    navGroup: "Billing",
    permission: "accounting.view",
    icon: "accounting",
  },

  // People
  {
    id: "staff",
    title: "Staff & Teaching Assignments",
    eyebrow: "People",
    href: "/dashboard/staff",
    navGroup: "People",
    permission: "staff.view",
    icon: "staff",
  },

  // Academy Setup
  {
    id: "academic-directory",
    title: "Academic directory",
    eyebrow: "Settings",
    href: "/dashboard/crm/manage",
    navGroup: "Settings",
    permission: "system.master_data.manage",
    icon: "settings",
  },
  {
    id: "programme-offerings",
    title: "Programmes",
    eyebrow: "Academics",
    href: "/dashboard/academics/offerings",
    navGroup: "Academics",
    permission: "academics.view",
    icon: "offerings",
  },
  {
    id: "fee-plans",
    title: "Fee Plans",
    eyebrow: "Settings",
    href: "/dashboard/finance/fee-plans",
    navGroup: "Settings",
    permission: "finance.view",
    icon: "fee-plans",
  },
  {
    id: "operating-rules",
    title: "Operating Rules",
    eyebrow: "Settings",
    href: "/dashboard/governance/rules",
    navGroup: "Settings",
    permission: "system.rules.view",
    icon: "rules",
  },
  {
    id: "access-security",
    title: "Settings",
    eyebrow: "Settings",
    href: "/dashboard/settings",
    navGroup: "Settings",
    permission: "system.settings.view",
    icon: "settings",
  },

  // Governance
  {
    id: "admin-review-queue",
    title: "Admin Review Queue",
    eyebrow: "Activity",
    href: "/dashboard/governance/approvals",
    navGroup: "Activity",
    permission: "approvals.view",
    icon: "approvals",
  },
  {
    id: "audit",
    title: "Audit Trail",
    eyebrow: "Activity",
    href: "/dashboard/governance/audit",
    navGroup: "Activity",
    permission: "audit.view",
    icon: "audit",
  }
];

export function routeMatches(pathname: string, route: ErpRouteDefinition) {
  if (
    route.id === "academic-operations" &&
    pathname.startsWith("/dashboard/academics/sessions/")
  ) {
    return true;
  }

  if (route.exact) return pathname === route.href;
  return pathname === route.href || pathname.startsWith(`${route.href}/`);
}

export function getErpRoute(pathname: string) {
  return (
    erpRouteRegistry
      .filter((route) => routeMatches(pathname, route))
      .sort((a, b) => b.href.length - a.href.length)[0] ?? null
  );
}
