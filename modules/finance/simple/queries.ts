import "server-only";
import { z } from "zod";
import { platformClient } from "@/modules/platform/rpc-client";
import { requirePermission } from "@/modules/platform/auth/erp-context";
export const workspaceSchema = z.object({
  month: z.string(),
  revenue: z.number(),
  reductions: z.number(),
  netIncome: z.number(),
  expenses: z.number(),
  profit: z.number(),
  collected: z.number(),
  paid: z.number(),
  cashResult: z.number(),
  studentDue: z.number(),
  costDue: z.number(),
  accounts: z.array(
    z.object({ id: z.string().uuid(), name: z.string(), balance: z.number() }),
  ),
  categories: z.array(z.object({ id: z.string().uuid(), name: z.string() })),
  expenseBreakdown: z.array(z.object({ kind: z.string(), amount: z.number() })),
  rows: z.array(
    z.object({
      id: z.string().uuid(),
      day: z.string(),
      kind: z.string(),
      description: z.string(),
      amount: z.number(),
      payable_id: z.string().uuid().nullable(),
      remaining: z.number(),
      category: z.string().nullable(),
    }),
  ),
  total: z.number(),
  page: z.number(),
  canExpense: z.boolean(),
  canPay: z.boolean(),
  canIncome: z.boolean(),
});
export type SimpleFinanceData = z.infer<typeof workspaceSchema> & {
  links: { billing: boolean; salary: boolean; referrals: boolean };
};
export function financeQuery(q: { month?: string; page?: string; q?: string }) {
  return {
    month:
      q.month && /^\d{4}-(0[1-9]|1[0-2])$/.test(q.month)
        ? q.month + "-01"
        : undefined,
    page: Math.min(10000, Math.max(1, Number.parseInt(q.page ?? "1", 10) || 1)),
    query: (q.q ?? "").slice(0, 160),
  };
}
export async function getSimpleFinance(q: {
  month?: string;
  page: number;
  query: string;
}) {
  const context = await requirePermission("accounting.view");
  const { data, error } = await (
    await platformClient()
  ).rpc("simple_finance_workspace", {
    p_month: q.month ?? null,
    p_page: q.page,
    p_query: q.query,
  });
  if (error) throw Error(error.message);
  return {
    ...workspaceSchema.parse(data),
    links: {
      billing: context.permissions.includes("finance.view"),
      salary: context.permissions.includes("workforce.self.view"),
      referrals: context.permissions.includes("referrals.portal.view"),
    },
  };
}
