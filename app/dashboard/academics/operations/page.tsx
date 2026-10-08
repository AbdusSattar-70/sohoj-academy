import { requirePermission } from "@/modules/platform/auth/erp-context";
import {
  getCalendar,
  getPlanning,
  bangladeshToday,
  boundedPage,
} from "@/modules/academics/planning/queries";
import { ClassCalendar } from "@/modules/academics/planning/calendar";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string; page?: string }>;
}) {
  const context = await requirePermission("academics.view"),
    q = await searchParams,
    today = bangladeshToday(),
    from = q.from && /^\d{4}-\d{2}-\d{2}$/.test(q.from) ? q.from : today,
    to = q.to && /^\d{4}-\d{2}-\d{2}$/.test(q.to) ? q.to : from;
  const [data, planning] = await Promise.all([
    getCalendar(from, to, boundedPage(q.page)),
    context.permissions.includes("academics.sessions.manage")
      ? getPlanning("routines", 1)
      : Promise.resolve(undefined),
  ]);
  return <ClassCalendar data={data} planning={planning} from={from} to={to} />;
}
