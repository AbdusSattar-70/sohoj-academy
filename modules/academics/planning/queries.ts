import "server-only";
import { platformClient } from "@/modules/platform/rpc-client";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { planningSchema, calendarSchema, type PlanningSection } from "./schema";
export async function getPlanning(section: PlanningSection, page: number) {
  await requirePermission("academics.sessions.manage");
  const { data, error } = await (
    await platformClient()
  ).rpc("academic_planning_workspace", { p_section: section, p_page: page });
  if (error) throw Error(error.message);
  return planningSchema.parse(data);
}
export async function getCalendar(from: string, to: string, page: number) {
  await requirePermission("academics.view");
  const { data, error } = await (
    await platformClient()
  ).rpc("academic_calendar", { p_from: from, p_to: to, p_page: page });
  if (error) throw Error(error.message);
  return calendarSchema.parse(data);
}
export const bangladeshToday = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Dhaka" }).format(
    new Date(),
  );
export const boundedPage = (value?: string) =>
  Math.min(10000, Math.max(1, Number.parseInt(value ?? "1", 10) || 1));
