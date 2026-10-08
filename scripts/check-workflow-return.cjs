const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const ts = require("typescript");
const code = ts.transpileModule(
  fs.readFileSync("modules/platform/navigation/workflow-return.ts", "utf8"),
  { compilerOptions: { module: ts.ModuleKind.CommonJS } },
).outputText;
const feedbackCode = ts.transpileModule(
  fs.readFileSync("modules/platform/navigation/feedback-message.ts", "utf8"),
  { compilerOptions: { module: ts.ModuleKind.CommonJS } },
).outputText;
const feedback = { exports: {} };
vm.runInNewContext(feedbackCode, feedback);
for (const locale of ["bn", "bn-BD", "BN-bd"])
  assert.match(feedback.exports.savedFeedbackMessage(locale), /সংরক্ষিত/);
assert.equal(
  feedback.exports.savedFeedbackMessage("en"),
  "Saved successfully.",
);
const context = {
  exports: {},
  require: (name) => {
    assert.equal(name, "./feedback-message");
    return feedback.exports;
  },
};
vm.runInNewContext(code, context);
const safe = context.exports.workflowReturnPath;
for (const path of [
  "/dashboard/setup",
  "/dashboard/admissions/8bfa88cf-55ca-41d6-867e-5e452a41bb18",
  "/dashboard/finance/recurring?month=2026-10",
  "/dashboard/finance/receivables?q=student",
])
  assert.equal(safe(path), path);
for (const path of [
  null,
  "https://evil.example",
  "//evil.example",
  "/dashboard\\evil",
  "/dashboard/admissions?x=%0a",
  "/dashboard/finance/recurring?month=2026-13",
  "/dashboard/settings",
  "/dashboard/admissions#fragment",
])
  assert.equal(safe(path), null);
console.log(
  "PASS: known contextual returns and external/control-character rejection",
);
