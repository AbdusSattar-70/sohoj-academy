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
    if (
      name === "./actions" ||
      name === "@/modules/academics/operations/actions"
    )
      return {
        runTeacherClass: async () => ({ ok: true }),
        runAcademicCommand: async () => ({ ok: true }),
        runClassLogCommand: async () => ({ ok: true }),
        saveAcademicDocument: async () => ({ ok: true }),
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

const { TeacherClassroom } = load("modules/teacher/classroom/workspace.tsx");
const id = "98000000-0000-4000-8000-000000000001";
const date = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Dhaka",
}).format(new Date());
const session = {
  id,
  batch: "Morning A",
  subject: "Physics",
  teacher: "Teacher",
  teacherProfileId: id,
  room: "Room 1",
  date,
  canRecordNow: true,
  startsAt: date + "T08:00:00+06:00",
  endsAt: date + "T08:45:00+06:00",
  timezone: "Asia/Dhaka",
  status: "SCHEDULED",
  scope: "Chapter 3",
  cancellationReason: null,
  curriculumTitle: null,
  curriculumVersion: null,
  units: [],
};
const roster = [
  {
    enrollment_id: id,
    student_id: id,
    number: "SA-00001",
    name: "Student One",
  },
];
const base = { session, roster, submissions: [] };
let html = renderToStaticMarkup(
  React.createElement(TeacherClassroom, {
    data: base,
    logs: { logs: [], units: [] },
    flow: { clock: null, reminders: [] },
  }),
);
assert.ok(html.includes("Yes — start my class"));
assert.ok(!html.includes("Student One"), "Roster waits for start");
const clock = {
  session_id: id,
  teacher_id: id,
  started_at: date + "T08:05:00+06:00",
  ended_at: null,
};
html = renderToStaticMarkup(
  React.createElement(TeacherClassroom, {
    data: base,
    logs: { logs: [], units: [] },
    flow: { clock, reminders: [] },
  }),
);
assert.ok(
  html.includes("Student One") &&
    html.includes("Save attendance &amp; continue"),
);
assert.ok(html.includes('value="" selected=""'), "No automatic present");
const data = {
  ...base,
  submissions: [
    {
      id,
      status: "DRAFT",
      revision: 1,
      entries: [],
      recordedBy: id,
      reason: "Recorded class attendance",
      recorder: "Teacher",
      createdAt: clock.started_at,
      approvalId: null,
      decisionNote: null,
    },
  ],
};
html = renderToStaticMarkup(
  React.createElement(TeacherClassroom, {
    data,
    logs: { logs: [], units: [] },
    flow: {
      clock: { ...clock, ended_at: date + "T08:45:00+06:00" },
      reminders: [],
    },
  }),
);
assert.ok(
  html.includes("40") &&
    html.includes("teaching minutes") &&
    html.includes("Submit class report to admin"),
);
locale = "bn";
html = renderToStaticMarkup(
  React.createElement(TeacherClassroom, {
    data: base,
    logs: { logs: [], units: [] },
    flow: { clock: null, reminders: [] },
  }),
);
assert.ok(
  html.includes("ক্লাস শুরু করুন") && !html.includes("Yes — start my class"),
);
console.log(
  "PASS guided classroom: actual components render start gate, explicit roster attendance, forty-minute teaching, report submission and Bengali labels without Slot errors",
);
