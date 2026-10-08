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
    if (name === "next/navigation") return { usePathname: () => pathname };
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
const { workflowGuides } = load(
  "modules/platform/navigation/workflow-guides.ts",
);
const { erpRouteRegistry } = load(
  "modules/platform/navigation/erp-route-registry.ts",
);
const { PageWorkflowGuide } = load("components/erp/page-workflow-guide.tsx");
for (const [id, guide] of Object.entries(workflowGuides)) {
  assert.ok(guide.en.trim() && guide.bn.trim(), id + ": title");
  assert.ok(guide.steps.length, id + ": steps");
  for (const pair of guide.steps)
    assert.ok(
      pair.length === 2 && pair.every((s) => typeof s === "string" && s.trim()),
      id + ": bilingual instruction",
    );
}
for (const id of [
  "my-work",
  "referrals",
  "weekly-routines",
  "assessments",
  "academic-directory",
]) {
  const route = erpRouteRegistry.find((r) => r.id === id);
  pathname = route.href;
  for (locale of ["en", "bn"]) {
    const guide = workflowGuides[id];
    const html = renderToStaticMarkup(
      React.createElement(PageWorkflowGuide, {
        permissions: erpRouteRegistry.map((r) => r.permission),
      }),
    );
    const escape = (text) =>
      renderToStaticMarkup(React.createElement("span", null, text)).slice(
        6,
        -7,
      );
    assert.ok(
      html.includes(escape(guide[locale])),
      id + ": visible title " + locale,
    );
    guide.steps.forEach((pair) =>
      assert.ok(
        html.includes(escape(pair[locale === "bn" ? 1 : 0])),
        id + ": visible step " + locale,
      ),
    );
  }
}
console.log(
  "PASS: nonempty bilingual catalog and real guide render for reported work areas",
);

const { ErpFormField } = load("components/erp/form-field.tsx");
for (locale of ["en", "bn"]) {
  const html = renderToStaticMarkup(
    React.createElement(ErpFormField, {
      id: "class-code",
      label: "Code",
      required: true,
      hint: "Stable identifier",
      children: (props) =>
        React.createElement("input", {
          id: props.id,
          "aria-describedby": props.describedBy,
        }),
    }),
  );
  assert.ok(
    html.includes('for="class-code"') && html.includes('id="class-code"'),
  );
  assert.ok(html.includes("Code") && html.includes("কোড"));
  assert.ok(html.includes("Stable identifier"));
}
console.log(
  "PASS: native associated field labels, bilingual label content and visible hints",
);
