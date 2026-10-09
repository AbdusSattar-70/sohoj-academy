import { redirect } from "next/navigation";
import { getPlanning, boundedPage } from "@/modules/academics/planning/queries";
import { sections } from "@/modules/academics/planning/schema";
import { PlanningWorkspace } from "@/modules/academics/planning/workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ section?: string; page?: string }>;
}) {
  const q = await searchParams,
    section = sections.find((s) => s === q.section) ?? "rooms";
  if (section === "routines")
    redirect(
      "/dashboard/academics/routine" +
        (q.page ? "?page=" + boundedPage(q.page) : ""),
    );
  return (
    <PlanningWorkspace
      key={section}
      data={await getPlanning(section, boundedPage(q.page))}
    />
  );
}
