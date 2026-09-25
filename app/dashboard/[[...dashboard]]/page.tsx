import { redirect } from "next/navigation";
import DashboardContent from "@/components/dashboard/dashboard-content";
import { createClient } from "@/lib/supabase/server";
import type { User } from "@/types/user";

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ dashboard?: string[] }>;
}) {
  const { dashboard = [] } = await params;
  const supabase = await createClient();

  const { data: authData, error: authError } = await supabase.auth.getUser();

  if (authError || !authData.user) {
    console.error("[dashboard] auth failed", authError?.message ?? "No user");
    redirect("/auth/sign-in");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, full_name, role")
    .eq("id", authData.user.id)
    .maybeSingle();

  if (profileError) {
    console.error("[dashboard] profile query failed", {
      message: profileError.message,
      code: profileError.code,
      details: profileError.details,
    });
    throw new Error("Unable to load the signed-in user profile.");
  }

  if (!profile) {
    console.error("[dashboard] profile missing for authenticated user", authData.user.id);
    throw new Error("The signed-in account does not have a profile.");
  }

  const user: User = {
    id: profile.id,
    name: profile.full_name,
    email: authData.user.email ?? "",
    role: profile.role,
    avatar: null,
  };

  return (
    <DashboardContent
      user={user}
      section={dashboard[0] ?? "dashboard"}
      studentId={dashboard[0] === "students" ? dashboard[1] : undefined}
    />
  );
}
