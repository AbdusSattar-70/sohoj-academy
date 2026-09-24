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

  const { data: authData } = await supabase.auth.getUser();
  if (!authData.user) redirect("/auth/sign-in");

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, role")
    .eq("id", authData.user.id)
    .single();

  if (!profile) redirect("/auth/sign-in");

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
    />
  );
}
