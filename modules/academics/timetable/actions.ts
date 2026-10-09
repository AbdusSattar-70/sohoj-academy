"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { timetableSchema, timetableSaveSchema, previewSchema } from "./schema";
export async function previewTimetable(input: unknown) {
  const p = timetableSchema.safeParse(input);
  if (!p.success)
    return {
      ok: false as const,
      message: p.error.issues[0]?.message ?? "Check the selected details.",
    };
  const ctx = await getErpContext();
  if (
    ctx?.status !== "ACTIVE" ||
    !ctx.permissions.includes("academics.sessions.manage")
  )
    return {
      ok: false as const,
      message: "Active academic planning access required.",
    };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc("weekly_timetable_preview", { p_input: p.data });
    if (error) return { ok: false as const, message: error.message };
    return { ok: true as const, preview: previewSchema.parse(data) };
  } catch {
    return {
      ok: false as const,
      message:
        p.data.locale === "bn"
          ? "Preview পাওয়া যায়নি। তথ্য রেখে আবার চেষ্টা করুন।"
          : "Could not load preview. Your input is retained; retry.",
    };
  }
}
export async function saveTimetable(input: unknown) {
  const p = timetableSaveSchema.safeParse(input);
  if (!p.success)
    return {
      ok: false as const,
      uncertain: false,
      message: p.error.issues[0]?.message ?? "Check the selected details.",
    };
  const ctx = await getErpContext();
  if (
    ctx?.status !== "ACTIVE" ||
    !ctx.permissions.includes("academics.sessions.manage")
  )
    return {
      ok: false as const,
      uncertain: false,
      message: "Active academic planning access required.",
    };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc("weekly_timetable_save", { p_input: p.data });
    if (error)
      return {
        ok: false as const,
        uncertain: !error.code,
        message: error.message,
      };
    const result = z
      .object({
        id: z.string().uuid(),
        class_count: z.number(),
        from: z.string(),
        through: z.string(),
      })
      .parse(data);
    for (const path of [
      "/dashboard/academics/routine",
      "/dashboard/academics/planning",
      "/dashboard/academics/operations",
      "/dashboard/teacher",
    ])
      revalidatePath(path);
    return { ok: true as const, ...result };
  } catch {
    return {
      ok: false as const,
      uncertain: true,
      message: "Result unconfirmed. Confirm the same unchanged request.",
    };
  }
}

export async function createTimetableTeachingPlan(input: unknown) {
  const p = z
    .object({
      request_id: z.string().uuid(),
      batch_id: z.string().uuid(),
      subject_id: z.string().uuid(),
      title: z.string().trim().min(2).max(200),
      units: z
        .array(
          z.object({
            title: z.string().trim().min(2).max(200),
            target_date: z.iso.date(),
          }),
        )
        .min(1)
        .max(200),
      locale: z.enum(["en", "bn"]),
    })
    .safeParse(input);
  if (!p.success)
    return {
      ok: false as const,
      uncertain: false,
      message: p.error.issues[0]?.message ?? "Check the topics.",
    };
  const ctx = await getErpContext();
  if (
    ctx?.status !== "ACTIVE" ||
    !ctx.permissions.includes("academics.curriculum.manage")
  )
    return {
      ok: false as const,
      uncertain: false,
      message:
        p.data.locale === "bn"
          ? "পাঠ পরিকল্পনা তৈরির অনুমতি নেই।"
          : "Teaching-plan permission required.",
    };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc("academic_command", {
      p_input: {
        ...p.data,
        action: "PUBLISH_CURRICULUM",
        reason: "Prepared dated teaching topics from timetable",
      },
    });
    if (error)
      return {
        ok: false as const,
        uncertain: !error.code,
        message: error.message,
      };
    const result = z.object({ id: z.string().uuid() }).parse(data);
    revalidatePath("/dashboard/academics/routine");
    revalidatePath("/dashboard/academics/curriculum");
    return { ok: true as const, id: result.id };
  } catch {
    return {
      ok: false as const,
      uncertain: true,
      message:
        p.data.locale === "bn"
          ? "ফল নিশ্চিত নয়। একই তথ্য আবার নিশ্চিত করুন।"
          : "Result unconfirmed. Retry the same request.",
    };
  }
}
