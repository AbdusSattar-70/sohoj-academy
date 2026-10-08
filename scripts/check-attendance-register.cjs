const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const Module = require("node:module");
const ts = require("typescript");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
let locale = "en",
  pathname = "/dashboard/my-work";
const cache = new Map();
function load(file) {
  const filename = path.resolve(file);
  if (cache.has(filename)) return cache.get(filename);
  const mod = new Module(filename, module);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(path.dirname(filename));
  const base = mod.require.bind(mod);
  mod.require = (name) => {
    if (name === "@/components/providers/language-provider")
      return { useLanguage: () => ({ locale }) };
    if (name === "next/navigation")
      return {
        usePathname: () => pathname,
        useRouter: () => ({ refresh() {} }),
      };
    if (name === "./daily-attendance-form")
      return {
        DailyAttendanceForm: () =>
          React.createElement("div", null, "INLINE_EDITOR"),
      };
    if (name === "next/link")
      return {
        __esModule: true,
        default: ({ prefetch, children, ...props }) =>
          React.createElement("a", props, children),
      };
    if (name.startsWith("@/")) {
      const stem = name.slice(2);
      return load(fs.existsSync(stem + ".tsx") ? stem + ".tsx" : stem + ".ts");
    }
    if (name.startsWith(".")) {
      const stem = path.resolve(path.dirname(filename), name);
      if (fs.existsSync(stem + ".tsx")) return load(stem + ".tsx");
      if (fs.existsSync(stem + ".ts")) return load(stem + ".ts");
    }
    return base(name);
  };
  mod._compile(
    ts.transpileModule(fs.readFileSync(filename, "utf8"), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        jsx: ts.JsxEmit.ReactJSX,
        esModuleInterop: true,
      },
    }).outputText,
    filename,
  );
  cache.set(filename, mod.exports);
  return mod.exports;
}

const { AttendanceRegister } = load(
  "modules/workforce/attendance-register.tsx",
);
const rows = ["PRESENT", "ABSENT", "LEAVE", "HOLIDAY", null].map(
  (status, i) => ({
    id: `97000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
    name: `Staff ${i + 1}`,
    number: `SA-STF-0000${i + 1}`,
    record: status
      ? {
          staff_id: `97000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
          status,
          started_at: status === "PRESENT" ? "2020-01-02T08:00:00+06:00" : null,
          ended_at: status === "PRESENT" ? "2020-01-02T10:00:00+06:00" : null,
          break_minutes: 0,
        }
      : null,
  }),
);
const data = { date: "2020-01-02", page: 1, total: 26, selected: null, rows };
let html = renderToStaticMarkup(
  React.createElement(AttendanceRegister, {
    data,
    today: "2020-01-03",
    ownStaffId: rows[0].id,
  }),
);
for (const text of [
  "Present",
  "Absent",
  "On leave",
  "Academy holiday",
  "Not recorded",
  "SA-STF-00001",
  "page=2",
  "bg-emerald-",
  "bg-red-",
  "bg-amber-",
  "bg-blue-",
])
  assert.ok(html.includes(text), text);
assert.ok(!html.includes("INLINE_EDITOR"), "Editors closed by default");
html = renderToStaticMarkup(
  React.createElement(AttendanceRegister, {
    data: { ...data, selected: rows[0].id },
    today: "2020-01-03",
    ownStaffId: null,
  }),
);
assert.ok(html.includes("INLINE_EDITOR"), "Selected row opens inline editor");
locale = "bn";
html = renderToStaticMarkup(
  React.createElement(AttendanceRegister, {
    data,
    today: "2020-01-03",
    ownStaffId: null,
  }),
);
assert.ok(html.includes("উপস্থিত") && html.includes("অনুপস্থিত"));
console.log(
  "PASS: daily register renders distinct statuses, neutral missing records, paging, bilingual labels and inline editor without Slot errors",
);
