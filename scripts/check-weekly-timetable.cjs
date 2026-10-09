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
  await button(tree, "Save routine and create next four weeks").props.onClick();
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
  console.log(
    "PASS: actual timetable editor defaults today, copies rows, retains teacher and failed input, freezes uncertain saves, retries identical payload and closes with success; date extension respects last generated session",
  );
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
