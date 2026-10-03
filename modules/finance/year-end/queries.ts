import {z} from "zod";
import {platformClient} from "@/modules/platform/rpc-client";
const schema=z.object({start:z.string(),through:z.string(),status:z.string(),token:z.string(),transferResult:z.number(),earlierUnclosedLines:z.number(),canClose:z.boolean(),canManage:z.boolean(),accounts:z.array(z.object({id:z.string(),code:z.string(),name:z.string(),balance:z.number(),is_active:z.boolean()})),months:z.array(z.object({month:z.string(),status:z.string()})),events:z.array(z.object({action:z.string(),date:z.string(),reason:z.string(),actor:z.string().nullable(),journal:z.string().nullable()}))});
export type YearEndData=z.infer<typeof schema>;
export async function getYearEnd(start:string){const db=await platformClient();const {data,error}=await db.rpc("fiscal_year_preview",{p_start:start});if(error)throw Error(error.message);return schema.parse(data);}
