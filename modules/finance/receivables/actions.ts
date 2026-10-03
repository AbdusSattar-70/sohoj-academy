"use server";
import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
import {runCommandAction} from "@/modules/platform/command-action";
const schema=z.object({action:z.enum(["PROMISE","COMPLETE","CANCEL","CONTACT"]),request_id:z.string().uuid(),invoice_id:z.string().uuid(),id:z.string().uuid().optional(),revision:z.number().int().positive().optional(),amount:z.coerce.number().finite().positive().optional(),due_on:z.string().optional(),reason:z.string().trim().min(5).max(1000)});
export async function collectionFollowup(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"collection_followup_command",permission:"finance.payments.post",revalidate:["/dashboard/finance/receivables"],mapResult:data=>({message:String((data as {message:string}).message)})});}catch{return {ok:false as const,message:"Outcome uncertain. Check current commitments before retrying unchanged."};}}
