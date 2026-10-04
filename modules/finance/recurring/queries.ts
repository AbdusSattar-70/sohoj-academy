import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const choice=z.object({id:z.string().uuid(),name:z.string()});
const schema=z.object({month:z.string(),total:z.number(),vendors:z.array(choice),categories:z.array(choice),rows:z.array(z.object({id:z.string().uuid(),name:z.string(),vendor_id:z.string(),category_id:z.string(),supplier:z.string(),category:z.string(),amount:z.number(),first_month:z.string(),due_day:z.number(),due_on:z.string(),is_active:z.boolean(),revision:z.number(),purchase_id:z.string().nullable(),purchase_no:z.string().nullable(),purchase_status:z.string().nullable()}))});
export type RecurringData=z.infer<typeof schema>;
export async function getRecurringExpenses(month?:string,page=1){const db=await platformClient();const {data,error}=await db.rpc("recurring_expense_workspace",{p_month:month??null,p_page:page});if(error)throw Error(error.message);return schema.parse(data);}
