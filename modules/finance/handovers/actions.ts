"use server";
import {z} from "zod";
import {runCommandAction} from "@/modules/platform/command-action";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({request_id:z.string().uuid(),close_id:z.string().uuid(),outcome:z.enum(["RECEIVED","DISPUTED"]),counted_amount:z.coerce.number().finite().nonnegative().max(999999999999.99),reason:z.string().trim().min(5).max(1000)});
export async function confirmHandover(input:unknown){try{return await runCommandAction({schema,input,client:platformClient,rpc:"cash_handover_command",permission:"workforce.self.view",revalidate:["/dashboard/finance/handovers"],mapResult:()=>({message:"Receipt evidence saved."})});}catch{return {ok:false,message:"Could not confirm receipt. Check the register; an unchanged retry is safe."};}}
