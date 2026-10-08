import { requirePermission } from "@/modules/platform/auth/erp-context";
import {
  getProgressReports,
  statuses,
} from "@/modules/academics/documents/queries";
import { ProgressReports } from "@/modules/academics/documents/progress";
import { boundedPage } from "@/modules/academics/planning/queries";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; status?: string }>;
}) {
  const c = await requirePermission("academics.view"),
    q = await searchParams;
  return (
    <ProgressReports
      actorId={c.profileId}
      data={await getProgressReports(
        boundedPage(q.page),
        statuses.includes(q.status ?? "") ? q.status! : "ALL",
      )}
    />
  );
}
