import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = fileURLToPath(new URL('../', import.meta.url));
const folder = path.join(root, 'supabase/refactor/migrations');
const types = { uuid: 'string', text: 'string', integer: 'number', boolean: 'boolean', jsonb: 'Json', void: 'undefined', trigger: 'unknown' };
const functions = new Map();
for (const name of (await readdir(folder)).filter(n => n.endsWith('.sql')).sort()) {
  const sql = await readFile(path.join(folder, name), 'utf8');
  for (const match of sql.matchAll(/create function public\.(\w+)\(([\s\S]*?)\)\s+returns\s+(\w+)/gi)) {
    const args = match[2].trim() ? match[2].split(',').map(arg => {
      const parsed = arg.trim().match(/^(\w+)\s+(\w+)(\s+default\s+.+)?$/i);
      if (!parsed || !types[parsed[2]]) throw Error(`Unsupported RPC argument: ${arg}`);
      return `${parsed[1]}${parsed[3] ? '?' : ''}: ${types[parsed[2]]}`;
    }).join('; ') : '';
    if (!types[match[3]]) throw Error(`Unsupported return: ${match[3]}`);
    functions.set(match[1], `      ${match[1]}: { Args: ${args ? `{ ${args} }` : 'Record<string, never>'}; Returns: ${types[match[3]]} };`);
  }
}
const generated = `// Generated from fresh SQL function signatures. Run pnpm db:rpc-types.\n// RPC-only client intentionally has no direct table-write contract.\nexport type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];\nexport type AcademyDatabase = {\n  public: {\n    Tables: Record<string, never>;\n    Views: Record<string, never>;\n    Functions: {\n${[...functions.values()].join('\n')}\n    };\n    Enums: Record<string, never>;\n    CompositeTypes: Record<string, never>;\n  };\n};\n`;
const target = path.join(root, 'types/academy-rpc.ts');
if (process.argv.includes('--check')) {
  if (await readFile(target, 'utf8') !== generated) throw Error('RPC signature drift');
} else { await mkdir(path.dirname(target), { recursive: true }); await writeFile(target, generated); }
console.log('Academy RPC signatures verified.');
