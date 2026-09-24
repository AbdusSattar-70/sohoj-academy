"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { ROUTES } from "@/lib/constants";
import Logo from "@/components/shared/logo";

export default function SignInPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const signIn = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError("");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }

    router.replace(ROUTES.DASHBOARD);
    router.refresh();
  };

  return (
    <main className="min-h-screen bg-[#00002e] text-white flex items-center justify-center px-6">
      <div className="w-full max-w-md rounded-2xl border border-white/10 bg-black/40 p-8 shadow-2xl">
        <div className="mb-8 flex justify-center"><Logo /></div>
        <h1 className="text-2xl font-bold text-center">Digital Campus Sign In</h1>
        <p className="mt-2 text-center text-sm text-gray-400">Admin, Operator, Teacher, Guardian and Student access</p>

        <form onSubmit={signIn} className="mt-8 space-y-5">
          <div>
            <label className="mb-2 block text-sm">Email</label>
            <input className="w-full rounded-lg border border-white/15 bg-white/5 px-4 py-3 outline-none focus:border-blue-500" type="email" required value={email} onChange={(e)=>setEmail(e.target.value)} />
          </div>
          <div>
            <label className="mb-2 block text-sm">Password</label>
            <input className="w-full rounded-lg border border-white/15 bg-white/5 px-4 py-3 outline-none focus:border-blue-500" type="password" required value={password} onChange={(e)=>setPassword(e.target.value)} />
          </div>
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button disabled={loading} className="w-full rounded-lg bg-blue-700 px-4 py-3 font-semibold hover:bg-blue-600 disabled:opacity-50">
            {loading ? "Signing in..." : "Sign In"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-gray-400">
          <Link className="hover:text-white" href={ROUTES.AUTH}>Back</Link>
        </p>
      </div>
    </main>
  );
}
