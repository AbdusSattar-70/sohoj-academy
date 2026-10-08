import "server-only";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { classFlowSchema } from "./schema";
export async function getClassFlow(sessionId?: string) {
  await requirePermission("academics.view");
  const { data, error } = await (
    await platformClient()
  ).rpc("teacher_class_workspace", { p_session_id: sessionId ?? null });
  if (error) throw new Error(error.message);
  return classFlowSchema.parse(data);
}
