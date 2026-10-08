const assert = require("node:assert/strict"),
  fs = require("node:fs"),
  vm = require("node:vm"),
  ts = require("typescript");
const helper = { exports: {} };
vm.runInNewContext(
  ts.transpileModule(
    fs.readFileSync("modules/workforce/daily-attendance.ts", "utf8"),
    {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
      },
    },
  ).outputText,
  helper,
);
const { dailyAttendancePayload, bangladeshDate, bangladeshClock } =
  helper.exports;
const now = new Date("2026-10-09T06:00:00Z");
assert.equal(bangladeshDate(new Date("2026-10-08T20:00:00Z")), "2026-10-09");
assert.equal(bangladeshClock("2026-10-09T01:00:00Z"), "07:00");
const input = {
  staff_id: "97000000-0000-4000-8000-000000000001",
  work_date: "2026-10-09",
  status: "PRESENT",
  start_time: "07:00",
  end_time: "09:00",
  ends_next_day: false,
  break_minutes: 0,
  reason: "Recorded actual attendance",
  request_id: "97000000-0000-4000-8000-000000000002",
};
assert.equal(
  dailyAttendancePayload(input, now).started_at,
  "2026-10-09T07:00:00+06:00",
);
assert.equal(
  dailyAttendancePayload(input, now).ended_at,
  "2026-10-09T09:00:00+06:00",
);
const night = dailyAttendancePayload(
  {
    ...input,
    work_date: "2026-10-08",
    start_time: "22:00",
    end_time: "02:00",
    ends_next_day: true,
  },
  now,
);
assert.equal(night.ended_at, "2026-10-09T02:00:00+06:00");
for (const status of ["ABSENT", "LEAVE", "HOLIDAY"]) {
  const payload = dailyAttendancePayload(
    { ...input, status, break_minutes: 20 },
    now,
  );
  assert.equal(payload.break_minutes, 0);
  assert.ok(!("started_at" in payload));
  assert.ok(!("ended_at" in payload));
}
for (const change of [
  { work_date: "2026-10-10" },
  { work_date: "2026-02-30" },
  { start_time: "" },
  { end_time: "06:00" },
  { end_time: "13:00" },
  { break_minutes: 120 },
])
  assert.throws(() => dailyAttendancePayload({ ...input, ...change }, now));
let context = { status: "ACTIVE", permissions: ["workforce.manage"] },
  calls = [],
  saved;
const db = {
  from(table) {
    calls.push(["table", table]);
    return this;
  },
  select() {
    return this;
  },
  eq(key, value) {
    calls.push([key, value]);
    return this;
  },
  async maybeSingle() {
    return { data: null, error: null };
  },
};
const action = {
  exports: {},
  require(name) {
    if (name === "zod") return require("zod");
    if (name.includes("erp-context"))
      return { getErpContext: async () => context };
    if (name.includes("rpc-client")) return { platformClient: async () => db };
    if (name === "./daily-attendance") return helper.exports;
    if (name === "./actions")
      return {
        workforceAction: async (payload) => {
          saved = payload;
          return { ok: true, message: "Saved" };
        },
      };
    throw Error(name);
  },
};
vm.runInNewContext(
  ts.transpileModule(
    fs.readFileSync("modules/workforce/daily-attendance-actions.ts", "utf8"),
    {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
      },
    },
  ).outputText,
  action,
);
(async () => {
  const result = await action.exports.readDailyAttendance({
    staff_id: input.staff_id,
    work_date: input.work_date,
  });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, [
    ["table", "staff_attendance_records"],
    ["staff_id", input.staff_id],
    ["work_date", input.work_date],
  ]);
  context = { status: "ACTIVE", permissions: [] };
  calls = [];
  assert.equal((await action.exports.readDailyAttendance(input)).ok, false);
  assert.equal((await action.exports.recordDailyAttendance(input)).ok, false);
  assert.equal(calls.length, 0);
  assert.equal(saved, undefined);
  context = { status: "SUSPENDED", permissions: ["workforce.manage"] };
  assert.equal((await action.exports.readDailyAttendance(input)).ok, false);
  assert.equal((await action.exports.recordDailyAttendance(input)).ok, false);
  context = { status: "ACTIVE", permissions: ["workforce.manage"] };
  const posted = await action.exports.recordDailyAttendance({
    ...input,
    work_date: "2020-01-02",
  });
  assert.equal(posted.ok, true);
  assert.equal(saved.started_at, "2020-01-02T07:00:00+06:00");
  assert.equal(saved.work_date, "2020-01-02");
  const page = fs.readFileSync("app/dashboard/attendance/page.tsx", "utf8");
  assert.ok(page.includes("<DailyAttendanceForm"));
  assert.ok(page.includes("initialDate={date}"));
  const form = fs.readFileSync(
    "modules/workforce/daily-attendance-form.tsx",
    "utf8",
  );
  assert.ok(!form.includes("datetime-local") && !form.includes('type="month"'));
  assert.ok(form.includes('type="date"') && form.includes('type="time"'));
  assert.ok(form.includes("result.ok") && form.includes("loading={pending}"));
  console.log(
    "PASS: single-day/date-clock conversion, overnight, no-time statuses, validation, authoritative read/write access and direct attendance UI",
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
