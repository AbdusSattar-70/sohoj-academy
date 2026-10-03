import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({total:z.number(),accounts:z.array(z.object({id:z.string(),name:z.string()})),owners:z.array(z.object({id:z.string(),name:z.string(),contact:z.string(),is_active:z.boolean(),revision:z.number(),capital_balance:z.number()})),rows:z.array(z.object({id:z.string(),owner:z.string(),kind:z.string(),amount:z.number(),account:z.string(),reference:z.string(),reason:z.string(),actor:z.string(),created_at:z.string()}))});
export type CapitalData=z.infer<typeof schema>;
export async function getCapital(page=1,ownerId?:string){const db=await platformClient();const {data,error}=await db.rpc("owner_capital_workspace",{p_page:page,p_owner_id:ownerId??null});if(error)throw Error(error.message);return schema.parse(data);}
