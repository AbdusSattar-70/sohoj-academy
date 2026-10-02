"use server";
import { z } from "zod";
import { platformClient } from "@/modules/platform/rpc-client";
import { runCommandAction } from "@/modules/platform/command-action";
const schema = z.object({ action: z.enum(["SAVE", "ACQUIRE", "DETAILS", "TRANSFER", "MARK_INACTIVE", "ACTIVATE", "CANCEL", "ACKNOWLEDGE", "DEPRECIATE", "PAY", "DISPOSE", "MAINTENANCE"]), request_id: z.string().uuid(), id: z.string().uuid().optional(), revision: z.number().int().positive().optional(), reason: z.string().trim().min(5).max(1000), name: z.string().max(200).optional(), serial_no: z.string().max(200).optional(), location: z.string().max(200).optional(), vendor_id: z.string().uuid().optional(), source_purchase_id: z.string().uuid().optional(), asset_account_id: z.string().uuid().optional(), cost: z.number().positive().optional(), residual: z.number().nonnegative().optional(), life_months: z.number().int().min(1).max(600).optional(), acquired_on: z.string().optional(), in_service_on: z.string().optional(), depreciation_start: z.string().optional(), invoice_reference: z.string().max(200).optional(), date: z.string().optional(), month: z.string().optional(), payment_mode: z.enum(["PAID_NOW", "ON_ACCOUNT"]).optional(), payment_account_id: z.string().uuid().optional(), custodian_id: z.string().uuid().optional(), transfer_id: z.string().uuid().optional(), confirmed: z.boolean().optional(), amount: z.number().positive().optional(), proceeds: z.number().nonnegative().optional(), reference: z.string().max(200).optional(), details: z.string().max(1000).optional(), expense_id: z.string().uuid().optional() });
export async function assetAction(input: unknown) { try {
    return await runCommandAction({ schema, input, client: platformClient, rpc: "asset_command", permission: ["assets.manage", "workforce.self.view"], revalidate: ["/dashboard/finance/assets", "/dashboard/finance/accounting", "/dashboard/finance/reports", "/dashboard/my-work"], mapResult: data => ({ message: (data as {
                message: string;
            }).message }) });
}
catch {
    return { ok: false as const, message: "Could not confirm asset action. Inspect its history before changing inputs; unchanged retries reuse the same identity." };
} }
