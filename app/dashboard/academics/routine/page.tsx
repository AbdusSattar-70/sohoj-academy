import { getPlanning, boundedPage } from "@/modules/academics/planning/queries";
import { TimetableWorkspace } from "@/modules/academics/timetable/workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const q = await searchParams;
  return (
    <TimetableWorkspace
      today={new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Dhaka",
      }).format(new Date())}
      data={await getPlanning("routines", boundedPage(q.page))}
    />
  );
}
