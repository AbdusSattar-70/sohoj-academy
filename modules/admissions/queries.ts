import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";
import { admissionCaseDetailSchema, workspaceSchema } from "./schema";
// Narrow RPC contract until linked database types are regenerated.
type AdmissionDatabase = Database & {
  public: {
    Functions: {
      admission_workspace: { Args: Record<string, never>; Returns: Json };
      admission_command: { Args: { p_input: Json }; Returns: Json };
      create_prospect_admission: { Args: { p_input: Json }; Returns: Json };
      batch_command: { Args: { p_input: Json }; Returns: Json };
      post_admission_payment: { Args: { p_input: Json }; Returns: Json };
      admission_case_detail: { Args: { p_admission_id: string }; Returns: Json };
    };
  };
};
export async function admissionClient() {
  return (await createClient()) as unknown as SupabaseClient<AdmissionDatabase>;
}
export async function getAdmissionWorkspace() {
  const db = await admissionClient();
  const { data, error } = await db.rpc("admission_workspace");
  if (error) throw new Error(error.message);
  return workspaceSchema.parse(data);
}


export async function getAdmissionCase(admissionId: string) {
  const db = await admissionClient();
  const { data, error } = await db.rpc("admission_case_detail", {
    p_admission_id: admissionId,
  });
  if (error) throw new Error(error.message);
  return admissionCaseDetailSchema.parse(data);
}
