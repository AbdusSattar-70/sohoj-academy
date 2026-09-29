"use server";

import { runCommandAction } from "@/modules/platform/command-action";
import { assessmentClient } from "./queries";
import { assessmentCommandSchema, type AssessmentCommand } from "./schema";

export async function runAssessmentCommand(input: AssessmentCommand) {
  return runCommandAction<AssessmentCommand, { message: string }>({
    schema: assessmentCommandSchema,
    input,
    client: assessmentClient,
    rpc: "assessment_command",
    permission: (value) =>
      value.action === "APPROVE_RESULTS" || value.action === "REJECT_RESULTS"
        ? "academics.assessments.approve"
        : "academics.assessments.record",
    revalidate: [
      "/dashboard/academics/assessments",
      "/dashboard/governance/approvals",
      "/dashboard/action-center",
      "/dashboard",
    ],
    revalidateExtra: undefined,
    emptyMessage: "Assessment command returned no response.",
  });
}
