"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { studentClient } from "./queries";
import { studentCommandSchema, type StudentCommand } from "./schema";
export async function runStudentCommand(input: StudentCommand) {
  const parsed = studentCommandSchema.safeParse(input);
  if (!parsed.success)
    return { ok: false, message: parsed.error.issues[0].message };
  const context = await getErpContext();
  if (!context?.permissions.includes("students.view"))
    return { ok: false, message: "Student access required." };
  const db = await studentClient();
  const { data, error } = await db.rpc("student_command", {
    p_input: parsed.data,
  });
  if (error) return { ok: false, message: error.message };
  for (const path of [
    "/dashboard/students",
    "/dashboard/admissions",
    "/dashboard/academics/batches",
    "/dashboard/finance/billing",
    "/dashboard/governance/approvals",
    "/dashboard/governance/audit",
    "/dashboard/action-center",
    "/dashboard",
  ])
    revalidatePath(path);
  revalidatePath("/dashboard/students/[studentId]", "page");
  const result = data as { id: string; message: string };
  return {
    ok: true,
    message: result.message,
    admissionId: input.action === "CREATE_EXISTING" ? result.id : undefined,
  };
}
