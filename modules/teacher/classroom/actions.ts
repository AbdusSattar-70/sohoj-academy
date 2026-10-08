"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { classCommandSchema, classFlowSchema } from "./schema";
export async function runTeacherClass(input: unknown) {
  const parsed = classCommandSchema.safeParse(input);
  if (!parsed.success)
    return {
      ok: false,
      message:
        parsed.error.issues[0]?.message ?? "Check the highlighted details.",
      uncertain: false,
    };
  const context = await getErpContext();
  if (
    context?.status !== "ACTIVE" ||
    !context.permissions.includes("academics.attendance.record")
  )
    return {
      ok: false,
      message: "Active attendance recording permission required.",
      uncertain: false,
    };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc("teacher_class_command", { p_input: parsed.data });
    if (error)
      return { ok: false, message: error.message, uncertain: !error.code };
    if (data?.id !== parsed.data.session_id)
      return {
        ok: false,
        message: "Result unconfirmed. Retry the same request.",
        uncertain: true,
      };
    revalidatePath("/dashboard/teacher");
    revalidatePath("/dashboard/academics/sessions/" + parsed.data.session_id);
    revalidatePath("/dashboard/academics/operations");
    revalidatePath("/dashboard/action-center");
    const clock = classFlowSchema.shape.clock.parse(data.clock);
    return { ok: true, message: String(data.message), uncertain: false, clock };
  } catch {
    return {
      ok: false,
      message: "Result unconfirmed. Retry the same unchanged request.",
      uncertain: true,
    };
  }
}
