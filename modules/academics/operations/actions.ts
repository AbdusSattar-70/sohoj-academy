"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { academicClient } from "./queries";
import {
  academicCommandSchema,
  classLogCommandSchema,
  type AcademicCommand,
  type ClassLogCommand,
} from "./schema";
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
    "/dashboard/teacher",
  ])
    revalidatePath(path);
  revalidatePath("/dashboard/academics/sessions/[sessionId]", "page");
  const result = data as { id?: string; message: string };
  return { ok: true, message: result.message };
}

export async function runClassLogCommand(input: ClassLogCommand) {
  const parsed = classLogCommandSchema.safeParse(input);
  if (!parsed.success)
    return {
      ok: false,
      message: parsed.error.issues[0]?.message ?? "Check the class log.",
    };
  const context = await getErpContext();
  if (
    !context?.permissions.includes("academics.attendance.record") &&
    !context?.permissions.includes("academics.sessions.manage")
  )
    return { ok: false, message: "Class-log permission required." };
  const db = await academicClient();
  const { data, error } = await db.rpc("class_log_command", {
    p_input: parsed.data as import("@/types/database").Json,
  });
  if (error) return { ok: false, message: error.message };
  for (const path of [
    "/dashboard/teacher",
    "/dashboard/academics/operations",
    "/dashboard/action-center",
  ])
    revalidatePath(path);
  revalidatePath("/dashboard/academics/sessions/[sessionId]", "page");
  return { ok: true, message: (data as { message: string }).message };
}
