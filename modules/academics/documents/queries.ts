import "server-only";
import { z } from "zod";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { questionWorkspace, progressWorkspace } from "./schema";
export async function getQuestionDocuments(
  page: number,
  status: string,
  session?: string,
) {
  await requirePermission("academics.view");
  const { data, error } = await (
    await platformClient()
  ).rpc("class_question_documents_workspace", {
    p_page: page,
    p_status: status,
    p_session_id:
      session && z.string().uuid().safeParse(session).success ? session : null,
  });
  if (error) throw Error(error.message);
  return questionWorkspace.parse(data);
}
export async function getProgressReports(
  page: number,
  status: string,
  report?: string,
) {
  await requirePermission("academics.view");
  const { data, error } = await (
    await platformClient()
  ).rpc("student_progress_workspace", {
    p_page: page,
    p_status: status,
    p_report_id:
      report && z.string().uuid().safeParse(report).success ? report : null,
  });
  if (error) throw Error(error.message);
  return progressWorkspace.parse(data);
}
export const statuses = ["ALL", "DRAFT", "SUBMITTED", "RETURNED", "FINAL"];
