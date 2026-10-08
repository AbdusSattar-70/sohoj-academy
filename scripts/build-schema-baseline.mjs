import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = path.join(root, 'supabase/migrations');
const sources = [
  ['01_academy_divisions_and_access.sql', 'platform/01_academy_divisions_and_access.sql'],
  ['02_people_and_relationships.sql', 'people/02_people_and_relationships.sql'],
  ['03_academic_directory.sql', 'academics/03_academic_directory.sql'],
  ['04_foundation_seed.sql', 'academics/04_foundation_seed.sql'],
  ['05_programmes_offerings_and_batches.sql', 'academics/05_programmes_offerings_and_batches.sql'],
  ['06_workspace_contracts.sql', 'platform/06_workspace_contracts.sql'],
  ['07_public_enquiries.sql', 'crm/07_public_enquiries.sql'],
  ['08_persistent_starter_setup.sql', 'setup/08_persistent_starter_setup.sql'],
  ['09_people_identity_matching.sql', 'people/09_people_identity_matching.sql'],
  ['10_access_requests_and_identity_entry.sql', 'people/10_access_requests_and_identity_entry.sql'],
  ['11_offering_setup_and_history_guards.sql', 'academics/11_offering_setup_and_history_guards.sql'],
  ['12_class_sessions_and_notifications.sql', 'academics/12_class_sessions_and_notifications.sql'],
  ['13_weekly_availability_and_routines.sql', 'academics/13_weekly_availability_and_routines.sql'],
  ['14_teacher_qualifications_and_blockouts.sql', 'academics/14_teacher_qualifications_and_blockouts.sql'],
  ['15_qualification_query_scope.sql', 'academics/15_qualification_query_scope.sql'],
  ['16_focused_academic_reads.sql', 'academics/16_focused_academic_reads.sql'],
  ['17_staff_identity.sql', 'people/17_staff_identity.sql'],
  ['18_role_identity_display.sql', 'people/18_role_identity_display.sql'],
  ['19_inline_schedule_availability.sql', 'academics/19_inline_schedule_availability.sql'],
  ['20_schedule_checks.sql', 'academics/20_schedule_checks.sql'],
  ['21_routine_calendar.sql', 'academics/21_routine_calendar.sql'],
  ['22_enrollment_session_work.sql', 'academics/22_enrollment_session_work.sql'],
  ['23_default_plans_and_availability.sql', 'academics/23_default_plans_and_availability.sql'],
  ['24_future_routine_changes.sql', 'academics/24_future_routine_changes.sql'],
  ['25_resource_identity_diagnostics.sql', 'academics/25_resource_identity_diagnostics.sql'],
  ['26_account_permissions_and_workspaces.sql', 'access/26_account_permissions_and_workspaces.sql'],
  ['27_scoped_academic_workspaces.sql', 'access/27_scoped_academic_workspaces.sql'],
  ['28_admission_drafts.sql', 'admissions/28_admission_drafts.sql'],
  ['29_admission_confirmation_and_invoices.sql', 'admissions/29_admission_confirmation_and_invoices.sql'],
  ['30_student_payments_and_adjustments.sql', 'billing/30_student_payments_and_adjustments.sql'],
  ['31_admission_draft_cancellation.sql', 'admissions/31_admission_draft_cancellation.sql'],
];
const check = process.argv.includes('--check');
if (process.argv.some(arg => arg.startsWith('--') && arg !== '--check')) throw Error('Unknown option');
if (!check) await mkdir(target, { recursive: true });
const existing = await readdir(target).catch(() => []);
const expected = new Set(sources.map(([name]) => name));
const extra = existing.filter(name => name.endsWith('.sql') && !expected.has(name));
if (extra.length) throw Error(`Unexpected generated migrations: ${extra.join(', ')}`);
for (const [name, source] of sources) {
  const sql = await readFile(path.join(root, 'supabase/schema', source), 'utf8');
  const generated = `-- Generated from supabase/schema/${source}; edit the source, then run pnpm db:baseline.\n${sql}`;
  const destination = path.join(target, name);
  if (check) {
    if (await readFile(destination, 'utf8') !== generated) throw Error(`Baseline source drift: ${name}`);
  } else await writeFile(destination, generated);
}
console.log(check ? 'Academy source/migration parity verified.' : 'Academy baseline migrations generated.');
