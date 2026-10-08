"use server";
import { z } from "zod";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { workforceAction } from "./actions";
import { attendanceStatuses, dailyAttendancePayload } from "./daily-attendance";
const lookupSchema = z.object({
  staff_id: z.string().uuid(),
  work_date: z.iso.date(),
});
const recordSchema = lookupSchema.extend({
  status: z.enum(attendanceStatuses),
  start_time: z.string(),
  end_time: z.string(),
  ends_next_day: z.boolean(),
  break_minutes: z.number().int().min(0).max(1440),
  reason: z.string().trim().min(5).max(1000),
  request_id: z.string().uuid(),
});
const rowSchema = z.object({
  id: z.string().uuid(),
  work_date: z.iso.date(),
  status: z.enum(attendanceStatuses),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  break_minutes: z.number(),
  reason: z.string(),
});
export async function readDailyAttendance(input: unknown) {
  try {
    const context = await getErpContext();
    if (
      context?.status !== "ACTIVE" ||
      !context.permissions.includes("workforce.manage")
    )
      return {
        ok: false as const,
        message: "Attendance management permission required.",
      };
    const { staff_id, work_date } = lookupSchema.parse(input);
    const db = await platformClient();
    const { data, error } = await db
      .from("staff_attendance_records")
      .select("id,work_date,status,started_at,ended_at,break_minutes,reason")
      .eq("staff_id", staff_id)
      .eq("work_date", work_date)
      .maybeSingle();
    if (error)
      return {
        ok: false as const,
        message: "Could not load this day's attendance. Retry before saving.",
      };
    return { ok: true as const, record: data ? rowSchema.parse(data) : null };
  } catch {
    return {
      ok: false as const,
      message: "Could not load this day's attendance. Retry before saving.",
    };
  }
}
export async function recordDailyAttendance(input: unknown) {
  const context = await getErpContext();
  if (
    context?.status !== "ACTIVE" ||
    !context.permissions.includes("workforce.manage")
  )
    return {
      ok: false as const,
      message: "Attendance management permission required.",
    };
  const parsed = recordSchema.safeParse(input);
  if (!parsed.success)
    return {
      ok: false as const,
      message: parsed.error.issues[0]?.message ?? "Check attendance details.",
    };
  try {
    return await workforceAction(dailyAttendancePayload(parsed.data));
  } catch (error) {
    return {
      ok: false as const,
      message:
        error instanceof Error
          ? error.message
          : "Could not confirm attendance. Check the record before retrying.",
    };
  }
}
