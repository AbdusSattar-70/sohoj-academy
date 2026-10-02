import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({kind:z.enum(["VENDOR","CATEGORY"]),page:z.number(),total:z.number(),accounts:z.array(z.object({id:z.string(),name:z.string(),active:z.boolean()})),rows:z.array(z.object({id:z.string(),code:z.string(),name:z.string(),mobile:z.string().nullable(),email:z.string().nullable(),address:z.string().nullable(),service_category:z.string().nullable(),is_active:z.boolean(),token:z.string(),expense_account_id:z.string().nullable()}))});
export type DirectoryData=z.infer<typeof schema>;
export async function getPurchaseDirectory(kind:string,page:number,search:string){const db=await platformClient();const {data,error}=await db.rpc("purchase_directory_workspace",{p_kind:kind,p_page:page,p_search:search});if(error)throw Error(error.message);return schema.parse(data);}
