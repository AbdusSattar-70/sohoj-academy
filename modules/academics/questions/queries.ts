import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";
import { questionWorkspaceSchema } from "./schema";

type QuestionDatabase = Database & {
  public: {
    Functions: {
      question_bank_workspace: { Args: Record<string, never>; Returns: Json };
      question_bank_command: { Args: { p_input: Json }; Returns: Json };
    };
  };
};

export async function questionClient() {
  return (await createClient()) as unknown as SupabaseClient<QuestionDatabase>;
}

export async function getQuestionWorkspace() {
  const db = await questionClient();
  const { data, error } = await db.rpc("question_bank_workspace");
  if (error) throw new Error(error.message);
  return questionWorkspaceSchema.parse(data);
}
