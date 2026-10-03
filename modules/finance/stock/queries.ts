import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({total:z.number(),canManage:z.boolean(),rows:z.array(z.object({id:z.string(),name:z.string(),unit:z.string(),reorder_level:z.number(),is_active:z.boolean(),revision:z.number(),stock:z.number(),expected_order:z.number(),history:z.array(z.object({id:z.string(),kind:z.string(),quantity:z.number(),physical_quantity:z.number().nullable(),reference:z.string(),created_at:z.string(),reason:z.string(),actor:z.string().nullable()}))}))});
export type StockData=z.infer<typeof schema>;
export async function getStock(page:number,q:string){const db=await platformClient();const {data,error}=await db.rpc("consumable_workspace",{p_page:page,p_search:q});if(error)throw Error(error.message);return schema.parse(data);}
