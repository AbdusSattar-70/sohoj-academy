import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({month:z.string(),generatedAt:z.string(),opening:z.number(),closing:z.number(),movement:z.number(),difference:z.number(),total:z.number(),canManage:z.boolean(),summary:z.array(z.object({category:z.string(),inflow:z.number(),outflow:z.number(),net:z.number()})),rows:z.array(z.object({id:z.string(),journal_no:z.string(),journal_date:z.string(),description:z.string(),source_type:z.string(),amount:z.number(),category:z.string(),expected_order:z.number(),reason:z.string().nullable()}))});
export type CashFlowData=z.infer<typeof schema>;
export async function getCashFlow(month?:string,page=1){const db=await platformClient();const {data,error}=await db.rpc("classified_cash_flow",{p_month:month??null,p_page:page});if(error)throw Error(error.message);return schema.parse(data);}
