"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { platformClient } from "@/modules/platform/rpc-client";
import { getErpContext } from "@/modules/platform/auth/erp-context";
const common = {
  request_id: z.string().uuid(),
  reason: z.string().trim().min(5).max(1000),
  locale: z.enum(["en", "bn"]).default("en"),
};
const amount = z.coerce
  .number()
  .finite()
  .positive()
  .max(999999999999.99)
  .refine(
    (n) => Math.abs(n * 100 - Math.round(n * 100)) < 0.0001,
    "Use at most two decimal places.",
  );
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const schema = z.discriminatedUnion("action", [
  z.object({
    ...common,
    action: z.literal("EXPENSE"),
    date,
    amount,
    category_id: z.string().uuid(),
    description: z.string().trim().max(300),
    payment_mode: z.enum(["PAID_NOW", "ON_ACCOUNT"]),
    account_id: z.string().uuid().optional(),
    reference: z.string().trim().max(160),
  }),
  z.object({
    ...common,
    action: z.literal("PAY_COST"),
    payable_id: z.string().uuid(),
    amount,
    account_id: z.string().uuid(),
    reference: z.string().trim().max(160),
  }),
  z.object({
    ...common,
    action: z.enum(["OTHER_INCOME", "OWNER_FUNDS"]),
    date,
    amount,
    description: z.string().trim().min(3).max(300),
    account_id: z.string().uuid(),
    reference: z.string().trim().max(160),
  }),
  z.object({
    ...common,
    action: z.literal("CATEGORY"),
    description: z.string().trim().min(2).max(120),
  }),
]);
export async function saveSimpleFinance(input: unknown) {
  const parsed = schema.safeParse(input),
    bn =
      !!input &&
      typeof input === "object" &&
      "locale" in input &&
      input.locale === "bn";
  if (!parsed.success)
    return {
      ok: false,
      message: bn
        ? "প্রয়োজনীয় তথ্য, টাকার পরিমাণ ও তারিখ যাচাই করুন। আগের তথ্য রাখা আছে।"
        : parsed.error.issues[0].message,
    };
  const context = await getErpContext(),
    permission =
      parsed.data.action === "PAY_COST"
        ? "finance.payments.post"
        : "accounting.expense.manage";
  if (!context?.permissions.includes(permission))
    return {
      ok: false,
      message: bn
        ? "এই কাজের অনুমতি নেই।"
        : "You do not have permission for this action.",
    };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc("simple_finance_command", { p_input: parsed.data });
    if (error) {
      if (!error.code)
        return {
          ok: false,
          uncertain: true,
          message: bn
            ? "ফল নিশ্চিত নয়। একই অনুরোধ আবার নিশ্চিত করুন।"
            : "Result unconfirmed. Confirm the same request.",
        };
      return { ok: false, message: error.message };
    }
    const result = z.object({ id: z.string().uuid() }).parse(data);
    revalidatePath("/dashboard/finance");
    revalidatePath("/dashboard/finance/operations");
    return {
      ok: true,
      id: result.id,
      message: bn ? "সফলভাবে সংরক্ষিত হয়েছে।" : "Saved successfully.",
    };
  } catch {
    return {
      ok: false,
      uncertain: true,
      message: bn
        ? "ফল নিশ্চিত নয়। একই অনুরোধ আবার নিশ্চিত করুন।"
        : "Result unconfirmed. Confirm the same request before changing input.",
    };
  }
}
