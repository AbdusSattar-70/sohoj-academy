import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const baselineDir = join(root, "supabase", "baseline_v3");
const migrationsDir = join(root, "supabase", "migrations");

const expectedBaseline = [
  "0001_v3_platform_crm_admissions.sql",
  "0002_v3_admissions_finance_academics.sql",
  "0003_v3_academics_public.sql",
  "0004_v3_finance_and_current_workflows.sql",
  "0005_v3_direct_admin_finance.sql",
  "0006_v3_direct_admin_accounting.sql",
  "0007_v3_attendance_command.sql",
];

const expectedActive = [
  "01_platform_crm_admissions.sql",
  "02_admissions_finance_academics.sql",
  "03_academics_public.sql",
  "04_finance_and_current_workflows.sql",
  "05_direct_admin_finance.sql",
  "06_direct_admin_accounting.sql",
  "07_attendance_command.sql",
  "08_current_state_architecture.sql",
];

// Hard stops only. Function bodies legitimately insert into operational tables.
const forbidden = [
  /insert\s+into\s+auth\.users\b/i,
  /^\s*truncate\s+/im,
];

function checkSet(dir, names, label) {
  const missing = names.filter((name) => !existsSync(join(dir, name)));
  if (missing.length) {
    throw new Error(`Missing ${label} file(s): ${missing.join(", ")}`);
  }
  const violations = [];
  for (const name of names) {
    const content = readFileSync(join(dir, name), "utf8");
    for (const pattern of forbidden) {
      if (pattern.test(content)) {
        violations.push(`${name}: ${pattern}`);
      }
    }
  }
  if (violations.length) {
    throw new Error(
      `${label} integrity check failed:\n${violations.join("\n")}`,
    );
  }
}

checkSet(baselineDir, expectedBaseline, "V3 baseline");
checkSet(migrationsDir, expectedActive, "active V3 migrations");

const extra = readdirSync(migrationsDir)
  .filter((name) => name.endsWith(".sql") && !expectedActive.includes(name));
if (extra.length) {
  throw new Error(
    `Unexpected SQL files in supabase/migrations (archive V2 files first): ${extra.join(", ")}`,
  );
}

const archived = existsSync(join(root, "supabase", "migrations_v2_archive"));
console.log(
  `V3 baseline integrity OK: ${expectedBaseline.length} baseline parts + ${expectedActive.length} active migrations` +
    (archived ? " (V2 archive present)." : "."),
);
