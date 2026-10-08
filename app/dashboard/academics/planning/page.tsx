import { getPlanning, boundedPage } from "@/modules/academics/planning/queries";
import { sections } from "@/modules/academics/planning/schema";
import { PlanningWorkspace } from "@/modules/academics/planning/workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ section?: string; page?: string }>;
}) {
  const q = await searchParams,
    section = sections.find((s) => s === q.section) ?? "offerings";
  return (
    <PlanningWorkspace
      key={section}
      data={await getPlanning(section, boundedPage(q.page))}
    />
  );
}
