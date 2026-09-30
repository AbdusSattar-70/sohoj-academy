import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { AccessRequestRegister } from "@/modules/platform/access/request-register";
export default async function AccessRequestsPage() {
  await requirePermission("system.users.manage");
  const db = await platformClient();
  const { data, error } = await db
    .from("staff_access_requests")
    .select(
      "id,full_name,email,mobile,requested_role,purpose,status,assigned_role",
    )
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Staff access requests</h1>
        <p className="mt-2 text-muted-foreground">
          Verify identity and responsibilities, select a permitted role, then
          send the secure setup link. Requested roles never grant access
          automatically.
        </p>
      </header>
      <AccessRequestRegister rows={data ?? []} />
    </div>
  );
}
