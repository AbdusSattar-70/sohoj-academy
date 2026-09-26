import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";
import { workspaceSchema } from "./schema";
// Narrow RPC contract until linked database types are regenerated.
type AdmissionDatabase = Database & {
  public: {
    Functions: {
      admission_workspace: { Args: Record<string, never>; Returns: Json };
      admission_command: { Args: { p_input: Json }; Returns: Json };
      post_admission_payment: { Args: { p_input: Json }; Returns: Json };
    };
  };
};
export async function admissionClient() {
  return (await createClient()) as unknown as SupabaseClient<AdmissionDatabase>;
}
export async function getAdmissionWorkspace() {
  const db = await admissionClient();
  const { data, error } = await db.rpc("admission_workspace", {});
  if (error) throw new Error(error.message);
  return workspaceSchema.parse(data);
}
