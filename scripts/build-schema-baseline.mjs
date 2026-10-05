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
