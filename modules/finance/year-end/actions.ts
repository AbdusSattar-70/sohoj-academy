"use server";
import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
import {runCommandAction} from "@/modules/platform/command-action";
const schema=z.object({request_id:z.string().uuid(),action:z.enum(["CLOSE","REOPEN"]),start:z.string().regex(/^\d{4}-\d{2}-01$/),preview_token:z.string().length(32),confirmed:z.literal(true),reason:z.string().trim().min(10).max(1000)});
export async function yearEndAction(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"fiscal_year_command",permission:"accounting.period.manage",revalidate:["/dashboard/finance/year-end","/dashboard/finance/planning","/dashboard/finance/accounting"],mapResult:data=>({message:String((data as {message:string}).message)})});}catch{return {ok:false as const,message:"Outcome uncertain. Review the year history before retrying unchanged."};}}
