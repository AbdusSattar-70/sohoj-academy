"use server";

import { runCommandAction } from "@/modules/platform/command-action";
import { questionClient } from "./queries";
import { questionCommandSchema, type QuestionCommand } from "./schema";

export async function runQuestionCommand(input: QuestionCommand) {
  return runCommandAction<QuestionCommand, { message: string }>({
    schema: questionCommandSchema,
    input,
    client: questionClient,
    rpc: "question_bank_command",
    permission: (value) =>
      value.action === "APPROVE" || value.action === "REJECT"
        ? "academics.assessments.approve"
        : ["academics.assessments.record", "academics.sessions.manage"],
    revalidate: [
      "/dashboard/academics/questions",
      "/dashboard/governance/approvals",
      "/dashboard/action-center",
    ],
    emptyMessage: "Question-bank command returned no response.",
  });
}
