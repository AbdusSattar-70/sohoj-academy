/* eslint-disable @typescript-eslint/no-require-imports -- CommonJS VM harness loads the actual TSX editor. */
const fs = require("node:fs"),
  vm = require("node:vm"),
  ts = require("typescript"),
  assert = require("node:assert/strict"),
  crypto = require("node:crypto");
let states = [],
  cursor = 0,
  posted = [],
  mode = "preview-fail";
function load(path, require) {
  const m = {
    exports: {},
    require,
    crypto: crypto.webcrypto,
    window: { confirm: () => true },
  };
  vm.runInNewContext(
    ts.transpileModule(fs.readFileSync(path, "utf8"), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        jsx: ts.JsxEmit.ReactJSX,
      },
    }).outputText,
    m,
  );
  return m.exports;
}
const dates = load("modules/academics/timetable/dates.ts", require),
  marker = () => null;
const editor = load("modules/academics/timetable/editor.tsx", (name) => {
  if (name === "react")
    return {
      useState(initial) {
        const i = cursor++;
        if (!(i in states)) states[i] = initial;
        return [
          states[i],
          (v) => (states[i] = typeof v === "function" ? v(states[i]) : v),
        ];
      },
    };
  if (name === "react/jsx-runtime") return require(name);
  if (name === "next/navigation")
    return { useRouter: () => ({ refresh() {} }) };
  if (name === "next/link") return { default: marker, __esModule: true };
  if (name.includes("navigation-guard"))
    return { guardWorkspaceNavigation() {} };
  if (name.includes("language-provider"))
    return { useLanguage: () => ({ locale: "en" }) };
  if (name.endsWith("ui/button")) return { Button: marker };
  if (name === "../planning/form") return { PlanningForm: marker };
  if (name === "./rows") return { TimetableRows: marker };
  if (name === "./preview") return { TimetablePreviewPanel: marker };
  if (name === "./dates") return dates;
  if (name === "./groups")
    return load("modules/academics/timetable/groups.ts", require);
  if (name === "./teaching-plan") return { InlineTeachingPlan: marker };
  if (name === "./actions")
    return {
      previewTimetable: async () => ({ ok: false, message: "Row conflict" }),
      saveTimetable: async (p) => {
        posted.push(p);
        return mode === "uncertain"
          ? { ok: false, uncertain: true, message: "Unconfirmed" }
          : {
              ok: true,
              class_count: 8,
              from: "2026-10-09",
              through: "2026-11-05",
            };
      },
    };
  throw Error(name);
});
const data = {
  choices: {
    batches: [
      {
        id: "batch",
        offering_id: "offering",
        windows: [{ weekday: 2, start_time: "08:00", end_time: "09:00" }],
      },
    ],
    offerings: [
      { id: "offering", starts_on: "2026-01-01", ends_on: "2026-12-31" },
    ],
    rooms: [],
    teachers: [],
    subjects: [],
    curricula: [],
  },
};
const walk = (n) =>
  Array.isArray(n)
    ? n.flatMap(walk)
    : n && n.props
      ? [n, ...walk(n.props.children)]
      : [];
const render = () => {
  cursor = 0;
  return editor.TimetableEditor({ data, today: "2026-10-09" });
};
const button = (tree, text) =>
  walk(tree).find((n) => n.type === marker && n.props.children === text);
const rowTable = (tree) => walk(tree).find((n) => n.props.onCopy);
const select = (tree) =>
  walk(tree).find((n) => n.type === "select" && n.props.value === "");
(async () => {
  let tree = render();
  button(tree, "Create weekly timetable").props.onClick();
  tree = render();
  select(tree).props.onChange({ target: { value: "batch" } });
  tree = render();
  assert.equal(
    walk(tree).find((n) => n.type === "input" && n.props.type === "date").props
      .value,
    "2026-10-09",
  );
  let row = rowTable(tree).props.rows[0];
  assert.equal(row.weekday, 2);
  assert.equal(row.start_time, "08:00");
  rowTable(tree).props.onChange(row.key, "days", [0, 1, 2, 3, 4, 6]);
  tree = render();
  assert.equal(rowTable(tree).props.rows[0].days.length, 6);
  rowTable(tree).props.onChange(row.key, "teacher_id", "teacher");
  tree = render();
  rowTable(tree).props.onChange(row.key, "subject_id", "physics");
  tree = render();
  assert.equal(rowTable(tree).props.rows[0].teacher_id, "teacher");
  rowTable(tree).props.onCopy(row.key, 4);
  tree = render();
  assert.equal(rowTable(tree).props.rows.length, 2);
  assert.equal(rowTable(tree).props.rows[1].teacher_id, "teacher");
  assert.notEqual(
    rowTable(tree).props.rows[0].key,
    rowTable(tree).props.rows[1].key,
  );
  await walk(tree)
    .find((n) => n.type === "form")
    .props.onSubmit({ preventDefault() {} });
  tree = render();
  assert.equal(rowTable(tree).props.rows.length, 2);
  assert(
    walk(tree).some(
      (n) => n.props.role === "status" && n.props.children === "Row conflict",
    ),
  );
  const previewIndex = 6;
  states[previewIndex] = {
    ready: true,
    classes: [],
    issues: [],
    count: 8,
    from: "2026-10-09",
    through: "2026-11-05",
  };
  tree = render();
  mode = "uncertain";
  await button(tree, "Activate timetable").props.onClick();
  tree = render();
  assert(walk(tree).find((n) => n.type === "fieldset").props.disabled);
  assert.equal(
    walk(tree).find((n) => n.type === "form").props["data-busy"],
    true,
  );
  mode = "success";
  await button(tree, "Confirm same request").props.onClick();
  tree = render();
  assert.deepEqual(posted[0], posted[1]);
  assert.equal(posted[0].slots.length, 12);
  assert.equal(
    JSON.stringify(posted[0].slots.slice(0, 6).map((s) => s.weekday)),
    JSON.stringify([0, 1, 2, 3, 4, 6]),
  );
  assert(!walk(tree).some((n) => n.type === "form"));
  assert(
    walk(tree).some(
      (n) =>
        n.props.role === "status" &&
        n.props.children.includes("8 classes created"),
    ),
  );
  assert.equal(
    dates.timetableDates(
      {
        ...data,
        choices: {
          ...data.choices,
          offerings: [
            { id: "offering", starts_on: "2026-11-01", ends_on: "2026-12-31" },
          ],
        },
      },
      "batch",
      "2026-10-09",
    ).from,
    "2026-11-01",
  );
  assert.equal(
    dates.nextClassDates(
      {
        starts_on: "2026-01-01",
        ends_on: "2026-12-31",
        last_generated_on: "2026-11-05",
      },
      "2026-10-09",
    ).from,
    "2026-11-06",
  );
  const React = require("react"),
    { renderToStaticMarkup } = require("react-dom/server");
  const actualRequire = (name) => {
    if (name === "react/jsx-runtime") return require(name);
    if (name.includes("language-provider"))
      return { useLanguage: () => ({ locale: "en" }) };
    if (name.includes("ui/button")) return { Button: marker };
    if (name.includes("status-badge"))
      return {
        StatusBadge: ({ label }) => React.createElement("span", {}, label),
      };
    if (name === "../planning/form")
      return {
        weekdays: [
          "Sunday",
          "Monday",
          "Tuesday",
          "Wednesday",
          "Thursday",
          "Friday",
          "Saturday",
        ],
        weekdaysBn: ["রবি", "সোম", "মঙ্গল", "বুধ", "বৃহস্পতি", "শুক্র", "শনি"],
      };
    throw Error(name);
  };
  const actualRows = load(
      "modules/academics/timetable/rows.tsx",
      actualRequire,
    ),
    actualPreview = load(
      "modules/academics/timetable/preview.tsx",
      actualRequire,
    );
  const html = renderToStaticMarkup(
    React.createElement(actualRows.TimetableRows, {
      rows: [
        {
          key: "row",
          days: [0, 1, 2, 3, 4, 6],
          weekday: 0,
          subject_id: "",
          teacher_id: "",
          room_id: "",
          start_time: "07:00",
          end_time: "09:00",
          planned_scope: "",
        },
      ],
      data,
      batchId: "batch",
      onChange() {},
      onCopy() {},
      onRemove() {},
      onCreatePlan() {},
    }),
  );
  assert.equal((html.match(/type="checkbox"/g) || []).length, 7);
  assert.equal((html.match(/checked=""/g) || []).length, 6);
  const view = renderToStaticMarkup(
    React.createElement(actualPreview.TimetablePreviewPanel, {
      preview: {
        from: "2026-10-09",
        through: "2026-11-05",
        count: 24,
        ready: true,
        issues: [],
        classes: [],
        warnings: Array.from({ length: 6 }, (_, i) => ({
          row: i + 1,
          message:
            "Room-01: outside saved preferred hours. This is a preference, not a booking conflict; you may save this routine.",
        })),
      },
      slots: posted[0].slots,
      data,
    }),
  );
  assert.equal((view.match(/outside saved preferred hours/g) || []).length, 1);
  assert(view.includes("View dated classes"));
  assert(!view.includes("<details open"));
  console.log(
    "PASS: actual timetable editor defaults today, copies rows, retains teacher and failed input, freezes uncertain saves, retries identical payload and closes with success; date extension respects last generated session",
  );
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
