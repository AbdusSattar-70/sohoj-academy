import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";
import { assessmentWorkspaceSchema } from "./schema";

type AssessmentDatabase = Database & {
  public: {
    Functions: {
      assessment_workspace: { Args: Record<string, never>; Returns: Json };
      assessment_command: { Args: { p_input: Json }; Returns: Json };
    };
  };
};

export async function assessmentClient() {
  return (await createClient()) as unknown as SupabaseClient<AssessmentDatabase>;
}

export async function getAssessmentWorkspace() {
  const db = await assessmentClient();
  const { data, error } = await db.rpc("assessment_workspace");
  if (error) throw new Error(error.message);
  return assessmentWorkspaceSchema.parse(data);
}
