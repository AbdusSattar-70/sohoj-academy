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
        return Promise.resolve({ data: [], error: null });
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
    { compilerOptions: { module: ts.ModuleKind.CommonJS } },
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
