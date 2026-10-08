const fs = require("node:fs"),
  assert = require("node:assert/strict");
const root = require("node:path").resolve(__dirname, "..");
const ts = require(root + "/node_modules/typescript");
require.extensions[".ts"] = (m, file) =>
  m._compile(
    ts.transpileModule(fs.readFileSync(file, "utf8"), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
      },
    }).outputText,
    file,
  );
const { getNavigation } = require(
  root + "/modules/platform/navigation/erp-navigation.ts",
);
const { erpRouteRegistry, getErpRoute } = require(
  root + "/modules/platform/navigation/erp-route-registry.ts",
);
const { workspaceHome } = require(
  root + "/modules/platform/navigation/workspace-navigation.ts",
);
const base = {
  profileId: "fixture",
  displayName: "Fixture",
  email: "test@example.test",
  status: "ACTIVE",
  staffId: "fixture",
  staffNo: "SA-STF-00001",
  staffName: "Fixture",
};
const make = (roles, permissions) => ({ ...base, roles, permissions });
const admin = make(
  ["ADMIN"],
  [
    ...new Set(erpRouteRegistry.map((r) => r.permission)),
    "workforce.manage",
    "payroll.manage",
    "accounting.expense.manage",
  ],
);
const teacher = make(
  ["TEACHER"],
  [
    "dashboard.view",
    "academics.view",
    "workforce.self.view",
    "referrals.portal.view",
  ],
);
const staff = make(["SUPPORT"], ["dashboard.view", "workforce.self.view"]);
const referrer = make(["REFERRER"], ["referrals.portal.view"]);
const accountant = make(
  ["ACCOUNTANT"],
  [
    "dashboard.view",
    "accounting.view",
    "workforce.self.view",
    "payroll.manage",
    "accounting.expense.manage",
  ],
);
for (const c of [
  admin,
  teacher,
  staff,
  referrer,
  accountant,
  make(["NONE"], []),
]) {
  const nav = getNavigation(c).flatMap((g) => g.items);
  assert.equal(new Set(nav.map((i) => i.href)).size, nav.length);
  for (const i of nav) assert(c.permissions.includes(i.permission));
}
assert.equal(workspaceHome(admin), "/dashboard");
assert.equal(workspaceHome(teacher), "/dashboard/teacher");
assert.equal(workspaceHome(staff), "/dashboard/my-work");
assert.equal(workspaceHome(referrer), "/dashboard/referrals");
const ids = getNavigation(teacher).flatMap((g) => g.items.map((i) => i.id));
assert(ids.includes("teacher-dashboard"));
assert(ids.includes("my-work"));
assert(!ids.includes("academic-operations"));
assert(!ids.includes("programme-offerings"));
assert(!ids.includes("payroll"));
assert(!ids.includes("account"));
assert.equal(getNavigation(admin)[0].title, "Daily work");
assert.equal(
  getNavigation(admin)
    .flatMap((g) => g.items)
    .filter((i) => i.id === "admin-review-queue").length,
  0,
);
assert.equal(getErpRoute("/dashboard/staff/operations").id, "staff-operations");
assert.equal(
  getErpRoute("/dashboard/academics/progress/report/print").id,
  "student-progress",
);
assert.equal(
  getErpRoute("/dashboard/academics/sessions/fixture").id,
  "academic-operations",
);
console.log(
  "PASS: role landing, unique permission-filtered destinations, ordered groups, teacher simplification and deepest active route",
);
