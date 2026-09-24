import DashboardContent from "@/components/dashboard/dashboard-content";
import type { User } from "@/types/user";

const previewUser: User = {
  id: "preview",
  name: "Academy Admin",
  email: "admin@sohoj.academy",
  role: "ADMIN",
  avatar: null,
};

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ dashboard?: string[] }>;
}) {
  const { dashboard = [] } = await params;
  return <DashboardContent user={previewUser} section={dashboard[0] ?? "dashboard"} />;
}
