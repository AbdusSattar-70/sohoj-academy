"use server";
import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
import {runCommandAction} from "@/modules/platform/command-action";
const schema=z.object({request_id:z.string().uuid(),id:z.string().uuid(),expected_order:z.number().int().nonnegative(),category:z.enum(["OPERATING","INVESTING","FINANCING","UNCLASSIFIED"]),reason:z.string().trim().min(5).max(1000)});
export async function cashFlowAction(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"cash_classification_command",permission:"accounting.period.manage",revalidate:["/dashboard/finance/cash-flow"],mapResult:data=>({message:String((data as {message:string}).message)})});}catch{return {ok:false as const,message:"Outcome uncertain. Inspect current classification before retrying unchanged."};}}
