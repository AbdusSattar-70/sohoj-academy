"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { academicClient } from "./queries";
import { academicCommandSchema, type AcademicCommand } from "./schema";
export async function runAcademicCommand(input: AcademicCommand) {
  const parsed = academicCommandSchema.safeParse(input);
  if (!parsed.success)
    return { ok: false, message: parsed.error.issues[0].message };
  const context = await getErpContext();
  if (!context?.permissions.includes("academics.view"))
    return { ok: false, message: "Academic access required." };
  const db = await academicClient();
  const { data, error } = await db.rpc("academic_command", {
    p_input: parsed.data,
  });
  if (error) return { ok: false, message: error.message };
  for (const path of [
    "/dashboard/academics/operations",
    "/dashboard/governance/approvals",
    "/dashboard/governance/audit",
    "/dashboard/action-center",
    "/dashboard",
  ])
    revalidatePath(path);
  revalidatePath("/dashboard/academics/sessions/[sessionId]", "page");
  const result = data as { id?: string; message: string };
  return { ok: true, message: result.message };
}
