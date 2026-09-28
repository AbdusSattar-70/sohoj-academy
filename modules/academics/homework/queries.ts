import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";
import { homeworkWorkspaceSchema } from "./schema";

type HomeworkDatabase = Database & {
  public: {
    Functions: {
      homework_workspace: { Args: { p_session_id: string }; Returns: Json };
      homework_command: { Args: { p_input: Json }; Returns: Json };
    };
  };
};

export async function homeworkClient() {
  return (await createClient()) as unknown as SupabaseClient<HomeworkDatabase>;
}

export async function getHomeworkWorkspace(sessionId: string) {
  const db = await homeworkClient();
  const { data, error } = await db.rpc("homework_workspace", {
    p_session_id: sessionId,
  });
  if (error) throw new Error(error.message);
  return homeworkWorkspaceSchema.parse(data);
}
