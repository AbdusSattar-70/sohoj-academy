import "server-only";
import { z } from "zod";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { getWorkData } from "./queries";
import { attendanceStatuses } from "./daily-attendance";
const recordSchema = z.object({
  staff_id: z.string().uuid(),
  status: z.enum(attendanceStatuses),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  break_minutes: z.number(),
});
export type RegisterRecord = z.infer<typeof recordSchema>;
export type AttendanceRegisterData = {
  date: string;
  page: number;
  total: number;
  selected: string | null;
  rows: {
    id: string;
    name: string;
    number: string;
    record: RegisterRecord | null;
  }[];
};
export async function getAttendanceRegister(
  date: string,
  requestedPage?: string,
  person?: string,
): Promise<AttendanceRegisterData> {
  await requirePermission("workforce.manage");
  const day = z.iso.date().parse(date),
    workspace = await getWorkData(day);
  // Use the existing permission-scoped staff directory contract. Only one page is sent to the browser.
  const index = workspace.people.findIndex((p) => p.id === person),
    total = workspace.people.length,
    last = Math.max(1, Math.ceil(total / 25));
  const page = Math.min(
    last,
    Math.max(
      1,
      requestedPage
        ? Number.parseInt(requestedPage, 10) || 1
        : index >= 0
          ? Math.floor(index / 25) + 1
          : 1,
    ),
  );
  const people = workspace.people.slice((page - 1) * 25, page * 25);
  const records: RegisterRecord[] = [];
  if (people.length) {
    const db = await platformClient();
    const { data, error } = await db
      .from("staff_attendance_records")
      .select("staff_id,status,started_at,ended_at,break_minutes")
      .eq("work_date", day)
      .in(
        "staff_id",
        people.map((p) => p.id),
      )
      .limit(25);
    if (error)
      throw Error(
        "Could not load the attendance register. Retry before recording attendance.",
      );
    records.push(...z.array(recordSchema).parse(data ?? []));
  }
  return {
    date: day,
    page,
    total,
    selected: people.some((p) => p.id === person) ? person! : null,
    rows: people.map((p) => ({
      ...p,
      record: records.find((r) => r.staff_id === p.id) ?? null,
    })),
  };
}
