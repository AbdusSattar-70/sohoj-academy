import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const option=z.object({id:z.string().uuid(),name:z.string()});
const schema=z.object({manager:z.boolean(),total:z.number(),accounts:z.array(option.extend({kind:z.string(),registered:z.boolean()})),people:z.array(option),records:z.array(z.object({id:z.string().uuid(),name:z.string(),account_id:z.string().uuid(),account:z.string(),is_active:z.boolean(),revision:z.number(),counts:z.array(option),shifts:z.array(z.object({id:z.string().uuid(),work_date:z.string(),opening_balance:z.number(),float_amount:z.number(),closed_at:z.string().nullable(),staff_id:z.string().uuid(),cashier:z.string(),outcome:z.string().nullable(),can_receive:z.boolean(),receipts:z.array(z.object({outcome:z.string(),amount:z.number(),note:z.string(),at:z.string()}))}))}))});
export type CounterData=z.infer<typeof schema>;
export async function getCounters(page:number){const db=await platformClient();const {data,error}=await db.rpc("cash_counter_workspace",{p_page:page});if(error)throw Error(error.message);return schema.parse(data);}
