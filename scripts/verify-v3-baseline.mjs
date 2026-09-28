import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const baselineDir = join(root, "supabase", "baseline_v3");
const expected = [
  "0001_v3_platform_crm_admissions.sql",
  "0002_v3_admissions_finance_academics.sql",
  "0003_v3_academics_public.sql",
  "0004_v3_finance_and_current_workflows.sql",
  "0005_v3_direct_admin_finance.sql",
];

const forbidden = [
  /insert\s+into\s+(?:public\.)?(?:students|admission_invoices|admission_payments|profiles)\b/i,
  /insert\s+into\s+auth\.users\b/i,
  /insert\s+into\s+(?:public\.)?organizations\b/i,
  /delete\s+from\s+(?:public\.)?(?:students|admission_invoices|admission_payments)\b/i,
  /truncate\s+/i,
  /pg_get_functiondef\s*\(/i,
];

const missing = expected.filter((name) => !existsSync(join(baselineDir, name)));
if (missing.length) {
  throw new Error(`Missing V3 baseline file(s): ${missing.join(", ")}`);
}

const violations = [];
for (const name of expected) {
  const content = readFileSync(join(baselineDir, name), "utf8");
  for (const pattern of forbidden) {
    if (pattern.test(content)) {
      violations.push(`${name}: ${pattern}`);
    }
  }
}

if (violations.length) {
  throw new Error(
    `V3 baseline integrity check failed:\n${violations.join("\n")}`,
  );
}

console.log(`V3 baseline integrity OK: ${expected.length} schema-only parts.`);
