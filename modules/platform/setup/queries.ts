import { cache } from "react";
import { z } from "zod";
import { platformClient } from "../rpc-client";
const schema = z.object({
  completed: z.boolean(),
  ready: z.boolean(),
  academyName: z.string(),
  steps: z.array(
    z.object({
      id: z.string(),
      title: z.string(),
      href: z.string(),
      done: z.boolean(),
    }),
  ),
});
export const getAcademySetup = cache(async () => {
  const db = await platformClient();
  const { data, error } = await db.rpc("academy_setup_status");
  if (error) throw new Error(`Academy setup unavailable: ${error.message}`);
  const result = schema.parse(data);
  return {
    ...result,
    steps: result.steps.map((step) => ({
      ...step,
      href:
        step.href === "/dashboard/crm/manage"
          ? "/dashboard/academics/settings"
          : step.href,
    })),
  };
});
