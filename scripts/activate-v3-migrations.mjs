/**
 * Promote supabase/baseline_v3 into active supabase/migrations as 01_…07_.
 * Archives existing *.sql migrations into supabase/migrations_v2_archive/.
 *
 * Safe to re-run: re-copies baseline parts and refreshes the archive only when
 * non-V3 SQL is still present under migrations/.
 */
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const baselineDir = join(root, "supabase", "baseline_v3");
const migrationsDir = join(root, "supabase", "migrations");
const archiveDir = join(root, "supabase", "migrations_v2_archive");

const mapping = [
  ["0001_v3_platform_crm_admissions.sql", "01_platform_crm_admissions.sql"],
  ["0002_v3_admissions_finance_academics.sql", "02_admissions_finance_academics.sql"],
  ["0003_v3_academics_public.sql", "03_academics_public.sql"],
  ["0004_v3_finance_and_current_workflows.sql", "04_finance_and_current_workflows.sql"],
  ["0005_v3_direct_admin_finance.sql", "05_direct_admin_finance.sql"],
  ["0006_v3_direct_admin_accounting.sql", "06_direct_admin_accounting.sql"],
  ["0007_v3_attendance_command.sql", "07_attendance_command.sql"],
];

const activeNames = new Set(mapping.map(([, dst]) => dst));

mkdirSync(archiveDir, { recursive: true });
mkdirSync(migrationsDir, { recursive: true });

for (const name of readdirSync(migrationsDir)) {
  if (!name.endsWith(".sql") || activeNames.has(name)) continue;
  const from = join(migrationsDir, name);
  const to = join(archiveDir, name);
  if (existsSync(to)) {
    // Keep first archived copy; drop the duplicate active file.
    renameSync(from, join(archiveDir, `${Date.now()}_${name}`));
  } else {
    renameSync(from, to);
  }
  console.log(`archived ${name}`);
}

for (const [srcName, dstName] of mapping) {
  const src = join(baselineDir, srcName);
  if (!existsSync(src)) {
    throw new Error(`Missing baseline part: ${srcName}`);
  }
  let content = readFileSync(src, "utf8");
  if (!content.startsWith("-- ACTIVE V3 MIGRATION")) {
    content =
      `-- ACTIVE V3 MIGRATION · ${dstName}\n` +
      `-- Source: supabase/baseline_v3/${srcName}\n` +
      `-- Apply only on a clean database (no prior schema_migrations history).\n\n` +
      content;
  }
  writeFileSync(join(migrationsDir, dstName), content);
  console.log(`active ${dstName}`);
}

console.log(
  "V3 migrations activated. Next: pnpm run verify:v3-baseline && pnpm exec supabase db push",
);
