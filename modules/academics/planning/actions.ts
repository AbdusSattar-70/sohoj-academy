"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
const envelope = z
  .object({
    request_id: z.string().uuid(),
    action: z.enum([
      "OFFERING_PLAN",
      "BATCH_PLAN",
      "ROOM",
      "AVAILABILITY",
      "CLOSURE",
      "ROUTINE",
      "GENERATE",
      "RETIRE",
      "CREATE_SESSION",
      "CANCEL",
      "RESCHEDULE",
      "SUBSTITUTE",
      "ROOM_CHANGE",
      "MAKEUP",
    ]),
    reason: z.string().trim().min(5).max(500),
    locale: z.enum(["en", "bn"]),
  })
  .passthrough();
export async function saveAcademicPlan(input: unknown) {
  const p = envelope.safeParse(input);
  if (!p.success)
    return {
      ok: false,
      message: "Check the selected action and required details.",
    };
  const bn = p.data.locale === "bn",
    context = await getErpContext();
  if (!context?.permissions.includes("academics.sessions.manage"))
    return {
      ok: false,
      message: bn
        ? "এই কাজের অনুমতি নেই।"
        : "Academic planning permission required.",
    };
  try {
    const planning = [
      "OFFERING_PLAN",
      "BATCH_PLAN",
      "ROOM",
      "AVAILABILITY",
      "CLOSURE",
    ].includes(p.data.action);
    const { data, error } = await (
      await platformClient()
    ).rpc(
      planning ? "academic_planning_command" : "academic_schedule_command",
      { p_input: p.data },
    );
    if (error)
      return { ok: false, uncertain: !error.code, message: error.message };
    z.object({ id: z.string().uuid() }).parse(data);
    for (const path of [
      "/dashboard/academics/planning",
      "/dashboard/academics/operations",
      "/dashboard/academics/routine",
      "/dashboard/teacher",
      "/dashboard/admissions",
      "/dashboard/academics/batches",
    ])
      revalidatePath(path);
    revalidatePath("/dashboard/academics/sessions/[sessionId]", "page");
    return {
      ok: true,
      message: bn ? "সফলভাবে সংরক্ষিত হয়েছে।" : "Saved successfully.",
    };
  } catch {
    return {
      ok: false,
      uncertain: true,
      message: bn
        ? "ফল নিশ্চিত নয়। একই তথ্য আবার নিশ্চিত করুন।"
        : "Result unconfirmed. Confirm the same unchanged request.",
    };
  }
}
