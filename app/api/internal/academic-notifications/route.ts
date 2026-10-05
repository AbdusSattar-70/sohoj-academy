import {timingSafeEqual} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {AcademyDatabase} from '@/types/academy-rpc';
export const runtime='nodejs';
const rows=z.array(z.object({id:z.string(),lease_id:z.string(),recipient:z.string(),subject:z.string(),body:z.string()}));
export async function POST(request:Request){
 const secret=process.env.ACADEMIC_NOTIFICATION_SECRET;
 const auth=request.headers.get('authorization')??'';
 const expected='Bearer '+secret;
 if(!secret||secret.length<32||auth.length!==expected.length||!timingSafeEqual(Buffer.from(auth),Buffer.from(expected)))return Response.json({error:'Unauthorized'},{status:401});
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY,api=process.env.RESEND_API_KEY,from=process.env.ACADEMIC_EMAIL_FROM;
 if(!url||!key||!api||!from)return Response.json({error:'Email delivery is not configured.'},{status:503});
 const db=createClient<AcademyDatabase>(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input,init)=>fetch(input,{...init,signal:AbortSignal.timeout(20000)})}});
 const claim=await db.rpc('claim_academic_emails');if(claim.error)return Response.json({error:'Queue unavailable.'},{status:503});
 let accepted=0;
 for(const item of rows.parse(claim.data)){
  let provider:string|null=null,error:string|null=null;
  try{const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+api,'Content-Type':'application/json','Idempotency-Key':'academic/'+item.id},body:JSON.stringify({from,to:[item.recipient],subject:item.subject,text:item.body}),signal:AbortSignal.timeout(15000)});const body=await response.json();if(!response.ok||typeof body.id!=='string')error='Provider rejected the request ('+response.status+').';else provider=body.id;}catch{error='Delivery could not be confirmed; retry uses the same provider idempotency key.';}
  const saved=await db.rpc('finish_academic_email',{p_id:item.id,p_lease:item.lease_id,p_provider_id:provider as unknown as string,p_error:error as unknown as string});
  if(saved.error)return Response.json({error:'Queue update could not be confirmed.'},{status:503});if(!error)accepted++;
 }
 return Response.json({accepted});
}
