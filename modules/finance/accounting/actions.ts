"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireErpContext } from "@/modules/platform/auth/erp-context";
import { createClient } from "@/lib/supabase/server";

const commands = {
  CREATE_ACCOUNT: "accounting.manage",
  CREATE_VENDOR: "finance.advances.manage",
  REQUEST_ADVANCE: "finance.advances.manage",
  DECIDE_ADVANCE: "finance.advances.approve",
  PAY_ADVANCE: "finance.advances.manage",
  REQUEST_ADVANCE_SETTLEMENT: "finance.advances.manage",
  DECIDE_ADVANCE_SETTLEMENT: "finance.advances.approve",
  REFUND_ADVANCE: "finance.advances.manage",
  CREATE_EXPENSE: "accounting.expense.manage",
  DECIDE_EXPENSE: "accounting.expense.approve",
  POST_EXPENSE: "accounting.expense.manage",
  SETTLE_PAYABLE: "finance.payments.post",
  RECONCILE_EXPENSE: "accounting.reconcile",
  RECONCILE_ACCOUNT: "accounting.reconcile",
  REQUEST_COMPENSATION: "staff.compensation.manage",
  DECIDE_COMPENSATION: "staff.compensation.approve",
  SETTLE_COMPENSATION: "staff.compensation.manage",
  REQUEST_COMP_ADJUSTMENT: "staff.compensation.manage",
  DECIDE_COMP_ADJUSTMENT: "staff.compensation.approve",
} as const;

type Command = keyof typeof commands;
const inputSchema = z.object({
  action: z.enum(Object.keys(commands) as [Command, ...Command[]]),
  reason: z.string().trim().min(5).max(1000),
  values: z.record(z.string(), z.union([z.string(), z.number()])).default({}),
});

export async function submitAccountingCommand(input: unknown): Promise<{ ok: boolean; message: string }> {
  const parsed = inputSchema.safeParse(input);
  if (!parsed.success) return { ok: false, message: "Enter the required details and a reason of at least five characters." };
  const context = await requireErpContext();
  const permission = commands[parsed.data.action];
  if (!context.permissions.includes(permission)) return { ok: false, message: "You do not have permission for this action." };
  const supabase = (await createClient()) as unknown as SupabaseClient;
  const { data, error } = await supabase.rpc("finance_accounting_command", {
    p_input: {
      ...parsed.data.values,
      action: parsed.data.action,
      reason: parsed.data.reason,
      request_id: crypto.randomUUID(),
    },
  });
  if (error) return { ok: false, message: error.message };
  revalidatePath("/dashboard/finance/accounting");
  return { ok: true, message: (data as { message?: string } | null)?.message ?? "Finance action completed." };
}
