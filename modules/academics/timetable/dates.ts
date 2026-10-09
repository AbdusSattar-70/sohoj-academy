import type { PlanningData } from "../planning/schema";
export function addDays(date: string, days: number) {
  const d = new Date(date + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
export function timetableDates(
  data: PlanningData,
  batchId: string,
  today: string,
) {
  const batch = data.choices.batches.find((b) => b.id === batchId),
    offering = data.choices.offerings.find((o) => o.id === batch?.offering_id);
  const from =
    offering?.starts_on && offering.starts_on > today
      ? offering.starts_on
      : today;
  return { from, through: offering?.ends_on ?? addDays(from, 365) };
}
export function nextClassDates(row: Record<string, unknown>, today: string) {
  const after =
    typeof row.last_generated_on === "string"
      ? addDays(row.last_generated_on, 1)
      : today;
  const from = [today, String(row.starts_on), after].sort().at(-1)!;
  return { from, through: [String(row.ends_on), addDays(from, 27)].sort()[0] };
}
