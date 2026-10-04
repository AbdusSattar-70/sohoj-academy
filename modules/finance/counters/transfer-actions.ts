"use server";
import {z} from "zod";
import {runCommandAction} from "@/modules/platform/command-action";
import {platformClient} from "@/modules/platform/rpc-client";
const id=z.string().uuid();
const schema=z.discriminatedUnion("action",[
 z.object({action:z.literal("RECEIVE"),request_id:id,transfer_id:id,amount:z.coerce.number().finite().nonnegative().max(999999999999.99),outcome:z.enum(["RECEIVED","DISPUTED"]),reason:z.string().trim().min(5).max(1000)}),
 z.object({action:z.enum(["TOPUP","RETURN"]),request_id:id,counter_id:id,other_account_id:id,amount:z.coerce.number().finite().positive().max(999999999999.99),close_id:id.optional(),actual_confirmed:z.literal(true),reference:z.string().trim().min(3).max(120),reason:z.string().trim().min(5).max(1000)})
]);
export async function counterTransferAction(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"counter_transfer_command",permission:["accounting.reconcile","workforce.self.view"],revalidate:["/dashboard/finance/counters","/dashboard/finance/billing","/dashboard/finance/daily-close","/dashboard/finance/reports"],mapResult:()=>({message:"Transfer evidence saved."})});}catch{return {ok:false,message:"Could not confirm save. Inspect the register before retrying; unchanged retries retain their request identity."};}}
