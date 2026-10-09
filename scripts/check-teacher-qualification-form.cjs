const assert = require("node:assert/strict"),
  fs = require("node:fs"),
  vm = require("node:vm"),
  ts = require("typescript"),
  crypto = require("node:crypto");
let states = [],
  cursor = 0,
  posted,
  transitions = [];
const react = {
  useState(initial) {
    const index = cursor++;
    if (!(index in states)) states[index] = initial;
    return [
      states[index],
      (value) => {
        states[index] =
          typeof value === "function" ? value(states[index]) : value;
      },
    ];
  },
  useTransition() {
    return [
      false,
      (callback) => {
        transitions.push(callback());
      },
    ];
  },
};
const mod = {
  exports: {},
  crypto: crypto.webcrypto,
  require(name) {
    if (name === "react") return react;
    if (name === "react/jsx-runtime") return require(name);
    if (name === "next/navigation")
      return { useRouter: () => ({ refresh() {} }) };
    if (name.includes("language-provider"))
      return { useLanguage: () => ({ locale: "en" }) };
    if (name.includes("navigation-guard"))
      return { guardWorkspaceNavigation() {} };
    if (name.includes("/ui/button")) return { Button: () => null };
    if (name === "./actions")
      return {
        saveAcademicPlan: async (payload) => {
          posted = payload;
          return { ok: true, message: "Saved" };
        },
      };
    throw Error(name);
  },
};
vm.runInNewContext(
  ts.transpileModule(
    fs.readFileSync("modules/academics/planning/form.tsx", "utf8"),
    {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        jsx: ts.JsxEmit.ReactJSX,
      },
    },
  ).outputText,
  mod,
);
const data = {
  choices: {
    teachers: [
      { id: "teacher-a", name: "Teacher A", subjects: ["physics", "math"] },
    ],
    subjects: [
      { id: "physics", name: "Physics" },
      { id: "math", name: "Math" },
    ],
    batches: [],
    offerings: [],
    rooms: [],
    curricula: [],
    branches: [],
  },
};
const render = (action = "QUALIFICATION", initial = {}) => {
  cursor = 0;
  return mod.exports.PlanningForm({ action, data, initial, onDone() {} });
};
const walk = (node) =>
  Array.isArray(node)
    ? node.flatMap(walk)
    : node && typeof node === "object" && node.props
      ? [node, ...walk(node.props.children)]
      : [];
const choice = (tree, id) =>
  walk(tree).find(
    (node) =>
      node.type === "select" &&
      walk(node.props.children).some(
        (option) => option.type === "option" && option.props.value === id,
      ),
  );
const today = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Dhaka",
}).format(new Date());
(async () => {
  let tree = render();
  assert.equal(
    walk(tree).find((n) => n.type === "input" && n.props.name === "starts_on")
      .props.value,
    today,
  );
  assert.equal(walk(tree).find((n) => n.type === "details").props.open, false);
  choice(tree, "teacher-a").props.onChange({ target: { value: "teacher-a" } });
  tree = render();
  choice(tree, "physics").props.onChange({ target: { value: "physics" } });
  tree = render();
  assert.equal(choice(tree, "teacher-a").props.value, "teacher-a");
  assert.equal(choice(tree, "physics").props.value, "physics");
  choice(tree, "math").props.onChange({ target: { value: "math" } });
  tree = render();
  assert.equal(choice(tree, "teacher-a").props.value, "teacher-a");
  tree.props.onSubmit({ preventDefault() {} });
  await Promise.all(transitions);
  assert.equal(posted.teacher_id, "teacher-a");
  assert.equal(posted.subject_id, "math");
  assert.equal(posted.starts_on, today);
  assert.equal(posted.ends_on, "");
  states = [];
  tree = render("QUALIFICATION", {
    id: "assignment",
    teacher_id: "teacher-a",
    subject_id: "physics",
    starts_on: "2025-01-01",
    ends_on: "2027-12-31",
  });
  assert.equal(
    walk(tree).find((n) => n.type === "input" && n.props.name === "starts_on")
      .props.value,
    "2025-01-01",
  );
  assert.equal(walk(tree).find((n) => n.type === "details").props.open, true);
  states = [];
  tree = render("ROUTINE", { subject_id: "physics", teacher_id: "teacher-a" });
  choice(tree, "math").props.onChange({ target: { value: "math" } });
  tree = render("ROUTINE");
  assert.equal(choice(tree, "teacher-a").props.value, "teacher-a");
  console.log(
    "PASS: actual qualification form retains teacher when subject changes, submits default dates, preserves edited dates and retains routine teacher when subject changes",
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
