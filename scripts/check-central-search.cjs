const assert = require("node:assert/strict"),
  fs = require("node:fs"),
  vm = require("node:vm"),
  ts = require("typescript");
let context = {
    roles: ["TEACHER"],
    permissions: ["academics.view"],
    staffId: "10000000-0000-0000-0000-000000000001",
    status: "ACTIVE",
  },
  calls = [];
const db = {
  from(table) {
    const c = { table, filters: [] };
    calls.push(c);
    const chain = {
      select(fields) {
        c.fields = fields;
        return chain;
      },
      eq(key, value) {
        c.filters.push([key, value]);
        return chain;
      },
      in(key, values) {
        c.filters.push([key, values]);
        return chain;
      },
      ilike(key, value) {
        c.needle = value;
        return chain;
      },
      or(value) {
        c.or = value;
        return chain;
      },
      order() {
        return chain;
      },
      limit(n) {
        c.limit = n;
        const data =
          c.table === "guardians"
            ? [{ id: "20000000-0000-0000-0000-000000000002" }]
            : c.table === "student_guardians"
              ? [
                  {
                    students: {
                      id: "30000000-0000-0000-0000-000000000003",
                      student_no: "SA-000001",
                      full_name: "Student",
                    },
                  },
                ]
              : c.table === "admission_payments"
                ? [
                    {
                      id: "40000000-0000-0000-0000-000000000004",
                      receipt_no: "RCT-000001",
                    },
                  ]
                : c.table === "admission_payment_allocations"
                  ? [
                      {
                        payment_id: "40000000-0000-0000-0000-000000000004",
                        admission_invoices: {
                          admission_id: "50000000-0000-0000-0000-000000000005",
                        },
                      },
                    ]
                  : [];
        return Promise.resolve({ data, error: null });
      },
    };
    return chain;
  },
};
const sandbox = {
  exports: {},
  require(name) {
    if (name.includes("erp-context"))
      return { requireErpContext: async () => context };
    if (name.includes("rpc-client")) return { platformClient: async () => db };
    throw Error(name);
  },
};
vm.runInNewContext(
  ts.transpileModule(
    fs.readFileSync("modules/platform/search/actions.ts", "utf8"),
    {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
      },
    },
  ).outputText,
  sandbox,
);
(async () => {
  await sandbox.exports.searchErpRecords("Physics");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].table, "class_sessions");
  assert.deepEqual(calls[0].filters, [["teacher_id", context.staffId]]);
  assert.equal(calls[0].limit, 6);
  calls = [];
  context = {
    ...context,
    roles: ["REFERRER"],
    permissions: ["referrals.portal.view"],
  };
  await sandbox.exports.searchErpRecords("student");
  assert.equal(calls.length, 0);
  context = {
    ...context,
    roles: ["ADMIN"],
    permissions: ["students.view", "crm.prospects.view", "finance.view"],
  };
  await sandbox.exports.searchErpRecords("test),id.eq.unsafe%");
  assert.equal(calls.length, 3);
  assert.ok(calls.every((c) => c.limit === 5));
  assert.ok(calls.every((c) => !c.or.includes("),")));
  assert.ok(calls.some((c) => c.table === "admission_invoices"));
  calls = [];
  const mobile = await sandbox.exports.searchErpRecords("01775804070");
  assert.ok(mobile.rows.some((row) => row.href.includes("/students/3000")));
  assert.equal(calls.find((c) => c.table === "student_guardians").limit, 5);
  calls = [];
  const receipt = await sandbox.exports.searchErpRecords("RCT-000001");
  assert.ok(
    receipt.rows.some((row) => row.href.endsWith("/print?receipt=RCT-000001")),
  );
  assert.equal(
    calls.find((c) => c.table === "admission_payment_allocations").limit,
    10,
  );
  const migrations = fs
    .readdirSync("supabase/migrations")
    .filter((name) => name.endsWith(".sql"))
    .map((name) => fs.readFileSync("supabase/migrations/" + name, "utf8"))
    .join("\n");
  context.permissions = [
    "students.view",
    "crm.prospects.view",
    "finance.view",
    "staff.view",
    "academics.view",
    "admissions.view",
    "referrals.manage",
    "system.master_data.manage",
  ];
  await sandbox.exports.searchErpRecords("record");
  for (const c of calls)
    assert.ok(
      migrations.includes("create table public." + c.table + " ("),
      `Search table ${c.table} must exist in fresh schema`,
    );
  calls = [];
  context.status = "SUSPENDED";
  await sandbox.exports.searchErpRecords("student");
  assert.equal(calls.length, 0);
  context.status = "ACTIVE";
  await sandbox.exports.searchErpRecords("a");
  assert.equal(calls.length, 0);
  console.log(
    "PASS: bounded search, authoritative roles/permissions, teacher assignment, suspended accounts and short-query handling",
  );
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
