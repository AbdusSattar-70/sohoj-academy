import 'server-only';
import { cache } from 'react';
import { cookies } from 'next/headers';
import { createServerClient } from '@supabase/ssr';
import { boundedFetch } from '@/lib/supabase/fetch';
import type { AcademyDatabase } from '@/types/academy-rpc';

/** Verified account adapter for the academy. */
export const academyClient = cache(async () => {
  const jar = await cookies();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Academy connection is not configured.');
  return createServerClient<AcademyDatabase>(url, key, {
    global: { fetch: boundedFetch, headers: { 'x-sohoj-workspace': jar.get('sohoj-workspace')?.value ?? '' } },
    cookies: {
      getAll: () => jar.getAll(),
      setAll(values) {
        try { values.forEach(({ name, value, options }) => jar.set(name, value, options)); }
        catch { /* Proxy refreshes cookies when rendering cannot write them. */ }
      },
    },
  });
});
export const verifiedAcademyUser = cache(async () => {
  const db = await academyClient();
  const { data, error } = await db.auth.getUser();
  if (error || !data.user) return null;
  return data.user;
});
