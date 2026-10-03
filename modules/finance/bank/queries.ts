import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({total:z.number(),accounts:z.array(z.object({id:z.string(),name:z.string()})),rows:z.array(z.object({id:z.string(),account_id:z.string(),account:z.string(),transaction_date:z.string(),reference:z.string(),description:z.string(),amount:z.number(),matched:z.boolean(),history:z.array(z.object({journal:z.string(),date:z.string(),amount:z.number(),matched_at:z.string(),reason:z.string(),released_at:z.string().nullable(),release_reason:z.string().nullable()}))}))});
export type BankData=z.infer<typeof schema>;
export async function getBankData(accountId?:string,page=1,search="",unmatched=true){const db=await platformClient();const {data,error}=await db.rpc("bank_reconciliation_workspace",{p_account_id:accountId??null,p_page:page,p_search:search,p_unmatched:unmatched});if(error)throw Error(error.message);return schema.parse(data);}
