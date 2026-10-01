import { createServerClient } from "@supabase/ssr";
import { cache } from "react";
import { boundedFetch } from "./fetch";
import { cookies } from "next/headers";
import type { Database } from "@/types/database";

export const createClient = cache(async () => {
  const cookieStore = await cookies();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) {
    throw new Error("Missing Supabase environment variables");
  }

  return createServerClient<Database>(url, key, {
    global: { fetch: boundedFetch },
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        } catch {
          // Server Components cannot always write cookies.
        }
      },
    },
  });
});
