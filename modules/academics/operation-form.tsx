'use client';
import {useRef,useState,useTransition,type ReactNode} from 'react';
import {useWords,Reason} from '@/modules/academy/components/common';
export type OperationResult={ok:boolean;message:string};
export function OperationForm({title,children,reasonOptions,save,onSaved,onCancel,serialize,check}:{title:string;children:ReactNode;reasonOptions:string[];save:(input:{requestId:string;payload:Record<string,unknown>})=>Promise<OperationResult>;onSaved:()=>Promise<void>;onCancel:()=>void;serialize:(data:FormData)=>Record<string,unknown>;check?:(payload:Record<string,unknown>)=>Promise<OperationResult>}){
 const t=useWords(),[pending,startTransition]=useTransition(),[message,setMessage]=useState(''),[uncertain,setUncertain]=useState(false);
 const attempt=useRef<{requestId:string;payload:Record<string,unknown>}|null>(null);
 function send(input:{requestId:string;payload:Record<string,unknown>}){
  startTransition(async()=>{
   try{
    const result=await save(input);setMessage(result.message);setUncertain(false);
    if(!result.ok){attempt.current=null;return;}
    attempt.current=null;
    try{await onSaved();}catch{setMessage(t('Saved, but the list could not refresh. Reload the list before your next action.','সংরক্ষিত হয়েছে; তালিকা refresh হয়নি। পরের কাজের আগে তালিকা reload করুন।'));}
   }catch{setUncertain(true);setMessage(t('The result is unconfirmed. Confirm the same request before changing the input.','ফলাফল নিশ্চিত নয়। তথ্য পরিবর্তনের আগে একই অনুরোধের ফলাফল নিশ্চিত করুন।'));}
  });
 }
 return <form className="space-y-4 rounded-xl border p-5" data-editor data-dirty="true" data-busy={pending||uncertain} onSubmit={e=>{e.preventDefault();if(pending||uncertain)return;const data=new FormData(e.currentTarget);try{const input={requestId:crypto.randomUUID(),payload:{...serialize(data),reason:String(data.get('reason')??'')}};attempt.current=input;send(input);}catch(error){setMessage(error instanceof Error?error.message:t('Check the selected dates and times.','তারিখ ও সময় যাচাই করুন।'));}}}>
  <h3 className="text-lg font-semibold">{title}</h3>
  <fieldset disabled={pending||uncertain} className="grid gap-4 md:grid-cols-2">{children}<Reason value={reasonOptions[0]} options={reasonOptions}/></fieldset>
  {message&&<p role="status" className="whitespace-pre-line rounded-lg border p-3">{message}</p>}
  {check&&<button disabled={pending||uncertain} type="button" className="mr-3 cursor-pointer rounded-lg border px-4 py-2" onClick={e=>{const form=e.currentTarget.form;if(!form||!form.reportValidity())return;try{const payload=serialize(new FormData(form));startTransition(async()=>{try{const result=await check(payload);setMessage(result.message);}catch{setMessage(t('Preview failed. Input is retained; try again.','যাচাই হয়নি। তথ্য রাখা আছে; আবার চেষ্টা করুন।'));}});}catch(error){setMessage(error instanceof Error?error.message:'Check the input.');}}}>{pending?t('Checking…','যাচাই হচ্ছে…'):t('Check dates & availability','তারিখ ও availability যাচাই করুন')}</button>}
  {uncertain?<button disabled={pending} type="button" className="rounded-lg border px-4 py-2" onClick={()=>attempt.current&&send(attempt.current)}>{pending?t('Confirming…','নিশ্চিত করা হচ্ছে…'):t('Confirm previous request','আগের অনুরোধ নিশ্চিত করুন')}</button>:<button disabled={pending} className="rounded-lg bg-primary px-4 py-2 text-primary-foreground">{pending?t('Saving…','সংরক্ষণ হচ্ছে…'):t('Save','সংরক্ষণ করুন')}</button>}
  <button type="button" disabled={pending||uncertain} className="ml-3 rounded-lg border px-4 py-2" onClick={onCancel}>{t('Cancel','বাতিল')}</button>
 </form>;
}
