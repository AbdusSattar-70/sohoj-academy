const assert = require("node:assert/strict");
const fs = require("node:fs");
const Module = require("node:module");
const path = require("node:path");
const ts = require("typescript");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
function loadTs(file) {
  const filename = path.resolve(file);
  const mod = new Module(filename, module);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(path.dirname(filename));
  const baseRequire = mod.require.bind(mod);
  mod.require = (name) =>
    name === "@/lib/utils" ? loadTs("lib/utils.ts") : baseRequire(name);
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
  return mod.exports;
}
const { Button } = loadTs("components/ui/button.tsx");
for (const loading of [false, true]) {
  const html = renderToStaticMarkup(
    React.createElement(
      Button,
      { asChild: true, variant: "outline", loading },
      React.createElement(
        "a",
        { href: "/dashboard/academics/batches" },
        "Continue",
        React.createElement("svg", { "aria-hidden": true }),
      ),
    ),
  );
  assert.match(html, /^<a /);
  assert.match(html, /href="\/dashboard\/academics\/batches"/);
  assert.match(html, /Continue/);
  assert.match(html, /<svg/);
  assert.doesNotMatch(html, /<button|animate-spin/);
}
const normal = renderToStaticMarkup(
  React.createElement(Button, { loading: true }, "Saving"),
);
assert.match(normal, /^<button /);
assert.match(normal, /disabled=""/);
assert.match(normal, /aria-busy="true"/);
assert.match(normal, /animate-spin/);
console.log(
  "PASS: single slotted link child, nested icon, loading branch and normal pending button",
);
