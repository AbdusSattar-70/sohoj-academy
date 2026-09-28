import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

export type FinanceAccountingWorkspaceData = {
  accounts: Array<{ id: string; code: string; name: string; accountType: string; subtype: string; balance: number }>;
  payables: Array<{ id: string; number: string; type: string; beneficiary: string; amount: number; status: string; dueOn: string | null }>;
  advances: Array<{ id: string; number: string; beneficiary: string; purpose: string; requestedAmount: number; balance: number; status: string; expectedDate: string | null }>;
  expenses: Array<{ id: string; number: string; date: string; description: string; amount: number; status: string }>;
  compensation: Array<{ id: string; runNo: string; from: string; to: string; total: number; status: string }>;
};

export async function getFinanceAccountingWorkspace(): Promise<FinanceAccountingWorkspaceData> {
  const supabase = (await createClient()) as unknown as SupabaseClient;
  const [
    accountsResult,
    payablesResult,
    advancesResult,
    expensesResult,
    compensationResult,
    movementsResult,
  ] = await Promise.all([
    supabase.from("finance_accounts").select("id,code,name,account_type,account_subtype").eq("is_active", true).order("code"),
    supabase.from("finance_payables").select("id,payable_no,payable_type,original_amount,status,due_on,staff:staff_id(full_name),vendor:vendor_id(name)").neq("status", "VOIDED").order("due_on"),
    supabase.from("finance_advances").select("id,advance_no,beneficiary_type,purpose,requested_amount,status,expected_settlement_date,staff:staff_id(full_name),vendor:vendor_id(name)").order("created_at", { ascending: false }),
    supabase.from("finance_expenses").select("id,expense_no,expense_date,description,amount,status").order("expense_date", { ascending: false }),
    supabase.from("teacher_compensation_runs").select("id,run_no,period_start,period_end,total_amount,status").order("period_end", { ascending: false }),
    supabase.from("finance_advance_movements").select("advance_id,movement_type,amount"),
  ]);

  for (const result of [accountsResult, payablesResult, advancesResult, expensesResult, compensationResult, movementsResult]) {
    if (result.error) throw new Error(result.error.message);
  }

  const accounts = await Promise.all((accountsResult.data ?? []).map(async (account) => {
    const { data, error } = await supabase.rpc("finance_read_account_balance", {
      p_account_id: account.id,
      p_as_of: new Date().toISOString().slice(0, 10),
    });
    if (error) throw new Error(error.message);
    return {
      id: account.id,
      code: account.code,
      name: account.name,
      accountType: account.account_type,
      subtype: account.account_subtype,
      balance: Number(data ?? 0),
    };
  }));

  const advanceBalances = new Map<string, number>();
  for (const movement of movementsResult.data ?? []) {
    const signed = movement.movement_type === "PAYMENT"
      ? Number(movement.amount) : -Number(movement.amount);
    advanceBalances.set(movement.advance_id,
      (advanceBalances.get(movement.advance_id) ?? 0) + signed);
  }

  return {
    accounts,
    payables: (payablesResult.data ?? []).map((row) => ({
      id: row.id,
      number: row.payable_no,
      type: row.payable_type,
      beneficiary: row.staff?.[0]?.full_name ?? row.vendor?.[0]?.name ?? "Other",
      amount: Number(row.original_amount),
      status: row.status,
      dueOn: row.due_on,
    })),
    advances: (advancesResult.data ?? []).map((row) => ({
      id: row.id,
      number: row.advance_no,
      beneficiary: row.staff?.[0]?.full_name ?? row.vendor?.[0]?.name ?? row.beneficiary_type,
      purpose: row.purpose,
      requestedAmount: Number(row.requested_amount),
      balance: advanceBalances.get(row.id) ?? 0,
      status: row.status,
      expectedDate: row.expected_settlement_date,
    })),
    expenses: (expensesResult.data ?? []).map((row) => ({
      id: row.id,
      number: row.expense_no,
      date: row.expense_date,
      description: row.description,
      amount: Number(row.amount),
      status: row.status,
    })),
    compensation: (compensationResult.data ?? []).map((row) => ({
      id: row.id,
      runNo: row.run_no,
      from: row.period_start,
      to: row.period_end,
      total: Number(row.total_amount),
      status: row.status,
    })),
  };
}
