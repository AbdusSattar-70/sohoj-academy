import "server-only";
import { z } from "zod";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
const schema = z.object({
  page: z.number(),
  total: z.number(),
  accounts: z.array(z.object({ id: z.string(), name: z.string() })),
  rows: z.array(
    z.object({
      id: z.string(),
      run_no: z.string(),
      period_start: z.string(),
      period_end: z.string(),
      status: z.string(),
      total_amount: z.number(),
      people: z.array(
        z.object({
          teacherId: z.string(),
          teacher: z.string(),
          earned: z.number(),
          remaining: z.number(),
        }),
      ),
    }),
  ),
});
export type TeachingEarnings = z.infer<typeof schema>;
export async function getTeachingEarnings(page = 1) {
  await requirePermission("staff.compensation.manage");
  const { data, error } = await (
    await platformClient()
  ).rpc("simple_teaching_workspace", { p_page: page });
  if (error) throw Error(error.message);
  return schema.parse(data);
}
