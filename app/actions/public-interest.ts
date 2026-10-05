'use server';
import {academyClient} from '@/modules/academy/client';
import {publicInterestSchema,type PublicInterestInput} from '@/lib/academy/public-interest-schema';
import type {Json} from '@/types/academy-rpc';
export type PublicInterestResult={ok:true;prospectNo:string|null}|{ok:false;error:string;field?:string|null};
export async function submitPublicInterest(input:PublicInterestInput):Promise<PublicInterestResult>{
 const parsed=publicInterestSchema.safeParse(input);
 if(!parsed.success)return {ok:false,error:parsed.error.issues[0]?.message??'Check your details.',field:String(parsed.error.issues[0]?.path[0]??'')};
 if(parsed.data.website)return {ok:true,prospectNo:null};
 const {requestId,website,...payload}=parsed.data;
 const {data,error}=await(await academyClient()).rpc('receive_public_enquiry',{p_request_id:requestId,p_payload:payload as Json});
 if(error)return {ok:false,error:error.code==='P0001'?error.message:'Submission could not be confirmed. Retry the same form.'};
 return {ok:true,prospectNo:data&&typeof data==='object'&&!Array.isArray(data)&&typeof data.reference==='string'?data.reference:null};
}
