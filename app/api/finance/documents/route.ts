import {createHash} from "node:crypto";
import {z} from "zod";
import {getErpContext} from "@/modules/platform/auth/erp-context";
import {platformClient} from "@/modules/platform/rpc-client";
export const runtime="nodejs";
const schema=z.object({request_id:z.string().uuid(),entity_type:z.enum(["PURCHASE","EXPENSE","REIMBURSEMENT","ASSET"]),entity_id:z.string().uuid(),note:z.string().trim().min(5).max(1000)});
const reply=(message:string,status:number)=>Response.json({ok:false,message},{status,headers:{"Cache-Control":"no-store"}});
export async function POST(request:Request){
 try{
  if(request.headers.get("origin")!==new URL(request.url).origin)return reply("Invalid request origin.",403);
  const context=await getErpContext();if(!context||context.status!=="ACTIVE"||!context.permissions.includes("accounting.expense.manage"))return reply("Expense document access required.",403);
  const length=Number(request.headers.get("content-length")??0);if(length>6*1024*1024)return reply("File must be at most 5 MB.",413);
  const body=await request.formData();const file=body.get("file");const parsed=schema.safeParse(Object.fromEntries(body));
  if(!parsed.success||!(file instanceof File))return reply("Choose a document and enter a clear evidence note.",400);
  if(file.size===0||file.size>5*1024*1024)return reply("File must be between 1 byte and 5 MB.",413);
  const bytes=Buffer.from(await file.arrayBuffer());const mime=bytes.subarray(0,5).toString()==="%PDF-"?"application/pdf":bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))?"image/png":bytes[0]===255&&bytes[1]===216&&bytes[2]===255?"image/jpeg":null;
  if(!mime||mime!==file.type)return reply("Upload a valid PDF, JPEG or PNG matching its file type.",400);
  const db=await platformClient();const payload={...parsed.data,original_name:file.name.slice(0,200),mime_type:mime,byte_size:file.size,sha256:createHash("sha256").update(bytes).digest("hex")};
  const prepared=await db.rpc("finance_document_prepare",{p_input:payload});if(prepared.error)return reply(prepared.error.message,400);
  const ticket=z.object({id:z.string().uuid(),path:z.string(),status:z.enum(["PENDING","READY"])}).parse(prepared.data);
  if(ticket.status!=="READY"){
   const uploaded=await db.storage.from("finance-evidence").upload(ticket.path,bytes,{contentType:mime,upsert:false});
   if(uploaded.error){
    // A lost completion response may leave the same immutable object already uploaded.
    const prior=await db.storage.from("finance-evidence").download(ticket.path);if(prior.error||!prior.data)return reply("Upload could not be confirmed. Keep this file and retry unchanged.",503);
    const hash=createHash("sha256").update(Buffer.from(await prior.data.arrayBuffer())).digest("hex");if(hash!==payload.sha256)return reply("Upload identity already has different file content. Choose a new upload.",409);
   }
  }
  const completed=await db.rpc("finance_document_complete",{p_id:ticket.id});if(completed.error)return reply(completed.error.message,400);
  return Response.json({ok:true,message:"Private document evidence recorded."},{headers:{"Cache-Control":"no-store"}});
 }catch{return reply("Could not confirm document upload. Your file can be retried unchanged.",503);}
}
