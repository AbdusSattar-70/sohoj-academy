"use server";
import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
import {runCommandAction} from "@/modules/platform/command-action";
const common={request_id:z.string().uuid(),reason:z.string().trim().min(5).max(1000)};
const schema=z.discriminatedUnion("action",[
 z.object({...common,action:z.literal("RECOVER_TERMS"),staff_id:z.string().uuid(),month:z.string().regex(/^\d{4}-\d{2}-01$/),effective_from:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),model:z.enum(["FIXED","HOURLY","HYBRID"]),monthly_base:z.coerce.number().finite().nonnegative(),hourly_rate:z.coerce.number().finite().nonnegative(),pay_day:z.coerce.number().int().min(1).max(28)}),
 z.object({...common,action:z.literal("ADJUST"),id:z.string().uuid(),amount:z.coerce.number().finite().refine(v=>v!==0,"Enter a nonzero adjustment.")})]);
export async function recoverPayroll(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"payroll_recovery_command",permission:"payroll.manage",revalidate:["/dashboard/finance/payroll","/dashboard/my-work","/dashboard/finance/accounting","/dashboard/finance/reports"],mapResult:()=>({message:"Payroll evidence saved. Original salary and settlements are preserved."})});}catch{return {ok:false as const,message:"Outcome uncertain. Inspect payroll before retrying; unchanged input keeps the same request ID."};}}
