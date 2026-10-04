import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({total:z.number(),records:z.array(z.object({id:z.string().uuid(),close_no:z.string(),close_date:z.string(),account:z.string(),amount:z.number(),sender:z.string(),recipient:z.string(),outcome:z.string().nullable(),counted_amount:z.number().nullable(),reason:z.string().nullable(),received_at:z.string().nullable(),can_confirm:z.boolean()}))});
export type HandoverData=z.infer<typeof schema>;
export async function getHandovers(page:number){const db=await platformClient();const {data,error}=await db.rpc("cash_handover_workspace",{p_page:page});if(error)throw Error(error.message);return schema.parse(data);}
