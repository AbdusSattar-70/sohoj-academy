import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const option=z.object({id:z.string(),name:z.string()});
const schema=z.object({manager:z.boolean(),canPay:z.boolean(),page:z.number(),total:z.number(),staff:z.array(option),categories:z.array(option),accounts:z.array(option),rows:z.array(z.object({id:z.string(),claim_no:z.string(),staff_id:z.string(),staff_name:z.string(),category_id:z.string(),category_name:z.string(),expense_date:z.string(),amount:z.number(),description:z.string(),receipt_reference:z.string(),status:z.enum(["DRAFT","SUBMITTED","POSTED","CANCELLED"]),revision:z.number(),review_note:z.string().nullable(),remaining:z.number(),documents:z.array(z.object({id:z.string(),name:z.string(),size:z.number(),note:z.string(),date:z.string(),actor:z.string().nullable()}))}))});
export type ClaimData=z.infer<typeof schema>;
export async function getClaims(page:number,status:string){const db=await platformClient();const {data,error}=await db.rpc("reimbursement_workspace",{p_page:page,p_status:status});if(error)throw Error(error.message);return schema.parse(data);}
