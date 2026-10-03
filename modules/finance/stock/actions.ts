"use server";
import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
import {runCommandAction} from "@/modules/platform/command-action";
const common={request_id:z.string().uuid(),reason:z.string().trim().min(5).max(1000)};
const schema=z.discriminatedUnion("action",[z.object({...common,action:z.literal("SAVE"),id:z.string().uuid().optional(),revision:z.number().int().positive().optional(),name:z.string().trim().min(2).max(150),unit:z.enum(["PIECE","PACK","REAM","BOX","LITRE","KG"]),reorder_level:z.number().finite().nonnegative().max(99999999),is_active:z.boolean()}),...(["RECEIPT","ISSUE","COUNT"] as const).map(action=>z.object({...common,action:z.literal(action),id:z.string().uuid(),expected_order:z.number().int().nonnegative(),quantity:z.number().finite().nonnegative().max(99999999),reference:z.string().trim().min(2).max(200),confirmed:z.literal(true)}))]);
export async function stockAction(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"consumable_command",permission:"accounting.expense.manage",revalidate:["/dashboard/finance/stock"],mapResult:data=>({message:String((data as {message:string}).message)})});}catch{return {ok:false as const,message:"Outcome uncertain. Review stock history before retrying unchanged."};}}
