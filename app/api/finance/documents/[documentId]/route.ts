import {z} from "zod";
import {getErpContext} from "@/modules/platform/auth/erp-context";
import {platformClient} from "@/modules/platform/rpc-client";
export async function GET(_request:Request,{params}:{params:Promise<{documentId:string}>}){
 const context=await getErpContext();if(!context||context.status!=="ACTIVE"||!context.permissions.some(p=>["accounting.expense.manage","workforce.self.view","assets.manage"].includes(p)))return new Response("Access denied",{status:403});
 const {documentId}=await params;if(!z.uuid().safeParse(documentId).success)return new Response("Invalid document",{status:400});
 const db=await platformClient();const record=await db.from("finance_documents").select("object_path,original_name").eq("id",documentId).eq("status","READY").maybeSingle();
 if(record.error||!record.data)return new Response("Document unavailable",{status:404});
 const link=await db.storage.from("finance-evidence").createSignedUrl(record.data.object_path,60,{download:record.data.original_name});if(link.error)return new Response("Document unavailable. Try again.",{status:503});
 return new Response(null,{status:303,headers:{Location:link.data.signedUrl,"Cache-Control":"private, no-store"}});
}
