const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");
const roots = ["app", "components", "modules", "lib", "types", "scripts"];
let count = 0;
const failures = [];
function visit(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      visit(file);
      continue;
    }
    if (!/\.(?:tsx?|jsx?|cjs|mjs)$/.test(file)) continue;
    const source = fs.readFileSync(file, "utf8");
    count++;
    // Tool truncation is corruption; ordinary UI ellipses are valid text.
    if (
      /…\d+ tokens truncated…|Warning: truncated output \(original token count:/.test(
        source,
      )
    )
      failures.push(`${file}: tool truncation marker`);
    const tree = ts.createSourceFile(
      file,
      source,
      ts.ScriptTarget.Latest,
      true,
    );
    for (const diagnostic of tree.parseDiagnostics) {
      const point = tree.getLineAndCharacterOfPosition(diagnostic.start ?? 0);
      failures.push(
        `${file}:${point.line + 1}:${point.character + 1}: ${ts.flattenDiagnosticMessageText(diagnostic.messageText, " ")}`,
      );
    }
  }
}
roots.forEach(visit);
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(
  `PASS: ${count} source files contain no truncation markers or syntax errors`,
);
