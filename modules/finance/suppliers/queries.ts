import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const vendor=z.object({id:z.string(),name:z.string(),vendor_no:z.string(),mobile:z.string().nullable(),email:z.string().nullable(),is_active:z.boolean()});
const schema=z.object({generatedAt:z.string(),total:z.number(),vendors:z.array(vendor),vendor:vendor.nullable(),summary:z.object({charges:z.number(),cashPaid:z.number(),advanceOffset:z.number(),creditNotes:z.number(),payableDue:z.number(),advanceHeld:z.number(),supplierRefundDue:z.number()}).nullable(),rows:z.array(z.object({id:z.string(),payable_no:z.string(),source_type:z.string(),source_id:z.string(),created_at:z.string(),due_on:z.string().nullable(),original_amount:z.number(),cash_paid:z.number(),advance_offset:z.number(),credit_notes:z.number(),remaining:z.number()}))});
export type SupplierStatement=z.infer<typeof schema>;
export async function getSupplierStatement(id?:string,search="",page=1){const db=await platformClient();const {data,error}=await db.rpc("supplier_account_statement",{p_vendor:id??null,p_search:search,p_page:page});if(error)throw Error(error.message);return schema.parse(data);}
