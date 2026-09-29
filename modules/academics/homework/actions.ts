"use server";

import { runCommandAction, revalidateDashboard } from "@/modules/platform/command-action";
import { homeworkClient } from "./queries";
import { homeworkCommandSchema, type HomeworkCommand } from "./schema";

export async function recordHomeworkCheck(input: HomeworkCommand) {
  return runCommandAction<HomeworkCommand, { message: string }>({
    schema: homeworkCommandSchema,
    input,
    client: homeworkClient,
    rpc: "homework_command",
    permission: ["academics.attendance.record", "academics.sessions.manage"],
    revalidate: [
      "/dashboard/teacher",
      "/dashboard/academics/operations",
      "/dashboard/action-center",
    ],
    revalidateExtra: () =>
      revalidateDashboard("/dashboard/academics/sessions/[sessionId]"),
    emptyMessage: "Homework command returned no response.",
  });
}
