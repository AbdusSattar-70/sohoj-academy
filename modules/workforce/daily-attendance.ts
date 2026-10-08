export const attendanceStatuses = [
  "PRESENT",
  "ABSENT",
  "LEAVE",
  "HOLIDAY",
] as const;
export type AttendanceStatus = (typeof attendanceStatuses)[number];
export type DailyAttendanceInput = {
  staff_id: string;
  work_date: string;
  status: AttendanceStatus;
  start_time: string;
  end_time: string;
  ends_next_day: boolean;
  break_minutes: number;
  reason: string;
  request_id: string;
};
export function bangladeshDate(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Dhaka" }).format(
    now,
  );
}
export function bangladeshClock(value: string | null) {
  return value
    ? new Date(new Date(value).getTime() + 6 * 3600000)
        .toISOString()
        .slice(11, 16)
    : "";
}
export function dailyAttendancePayload(
  input: DailyAttendanceInput,
  now = new Date(),
) {
  const day = new Date(`${input.work_date}T00:00:00Z`);
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(input.work_date) ||
    Number.isNaN(day.getTime()) ||
    day.toISOString().slice(0, 10) !== input.work_date
  )
    throw Error("Choose a valid attendance date.");
  if (input.work_date > bangladeshDate(now))
    throw Error("Actual attendance cannot be recorded for a future date.");
  const base = {
    action: "RECORD_ATTENDANCE" as const,
    staff_id: input.staff_id,
    work_date: input.work_date,
    status: input.status,
    request_id: input.request_id,
    reason: input.reason,
  };
  if (input.status !== "PRESENT") return { ...base, break_minutes: 0 };
  if (
    ![input.start_time, input.end_time].every((clock) =>
      /^([01]\d|2[0-3]):[0-5]\d$/.test(clock),
    )
  )
    throw Error("Choose the actual start and end times.");
  if (input.ends_next_day) day.setUTCDate(day.getUTCDate() + 1);
  const started_at = `${input.work_date}T${input.start_time}:00+06:00`,
    ended_at = `${day.toISOString().slice(0, 10)}T${input.end_time}:00+06:00`;
  const minutes = (Date.parse(ended_at) - Date.parse(started_at)) / 60000;
  if (minutes <= 0 || minutes > 1440)
    throw Error(
      "End time must be after start time, within 24 hours. For an overnight shift, select Ends next day.",
    );
  if (Date.parse(ended_at) > now.getTime())
    throw Error(
      "End time is in the future. Record attendance after the work has finished.",
    );
  if (
    !Number.isInteger(input.break_minutes) ||
    input.break_minutes < 0 ||
    input.break_minutes >= minutes
  )
    throw Error("Break must be shorter than the recorded work time.");
  return { ...base, started_at, ended_at, break_minutes: input.break_minutes };
}
