import { getPlanning, boundedPage } from "@/modules/academics/planning/queries";
import { PlanningWorkspace } from "@/modules/academics/planning/workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const q = await searchParams;
  return (
    <PlanningWorkspace
      data={await getPlanning("routines", boundedPage(q.page))}
    />
  );
}
