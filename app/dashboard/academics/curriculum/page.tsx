import { z } from "zod";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { boundedPage } from "@/modules/academics/planning/queries";
import { academicWorkspaceSchema } from "@/modules/academics/operations/schema";
import { CurriculumWorkspace } from "@/modules/academics/planning/curriculum";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  await requirePermission("academics.curriculum.manage");
  const q = await searchParams;
  const { data, error } = await (
    await platformClient()
  ).rpc("academic_curriculum_workspace", { p_page: boundedPage(q.page) });
  if (error) throw Error(error.message);
  const result = z
    .object({
      page: z.number(),
      total: z.number(),
      workspace: academicWorkspaceSchema,
    })
    .parse(data);
  return <CurriculumWorkspace {...result} />;
}
