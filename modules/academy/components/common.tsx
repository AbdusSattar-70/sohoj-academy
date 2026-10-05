'use client';
import { createContext,useContext,useRef,useState,useTransition,type ReactNode } from 'react';
import { useLanguage } from '@/components/providers/language-provider';
import { mutateAcademy,type MutationResult } from '../actions';
import type { Command } from '../schema';
import type { Json } from '@/types/academy-rpc';
export function useWords() { const {locale}=useLanguage();return (en:string,bn:string)=>locale==='bn'?bn:en; }
export const inputClass='mt-1 w-full rounded-lg border bg-background px-3 py-2.5 text-sm';
const errorsContext=createContext<Record<string,string>>({});
export function Field({label,name,children}:{label:string;name:string;children:ReactNode}) {
 const errors=useContext(errorsContext),t=useWords();
 return <div><label className="block text-sm font-medium" htmlFor={name}>{label}</label>{children}{errors[name]&&<p id={`${name}-error`} className="mt-1 text-sm text-red-600" role="alert">{t(errors[name],'এই তথ্যটি যাচাই করে আবার নির্বাচন/লিখুন।')}</p>}</div>;
}
export function useMutation(command:Command,onSuccess:(data:Json)=>void) {
 const [pending,start]=useTransition();const [error,setError]=useState<Extract<MutationResult,{ok:false}>|null>(null);
 const previous=useRef<{signature:string;payload:Record<string,unknown>}|null>(null);
 const execute=(payload:Record<string,unknown>)=>start(async()=>{
  try {
   const result=await mutateAcademy(command,payload);
   if(result.ok){setError(null);previous.current=null;onSuccess(result.data);}
   else setError(result);
  } catch {setError({ok:false,code:'unavailable',message:'The result could not be confirmed. Retry the unchanged request.'});}
 });
 const submit=(input:Record<string,unknown>)=>{
  if(pending||error?.code==='unavailable')return;
  const signature=JSON.stringify(input);
  if(previous.current?.signature!==signature)previous.current={signature,payload:{...input,request_id:crypto.randomUUID()}};
  setError(null);execute(previous.current.payload);
 };
 const retry=()=>{if(!pending&&previous.current)execute(previous.current.payload);};
 return {submit,retry,pending,error,uncertain:error?.code==='unavailable',fields:error?.fields??{}};
}
export function Editor({title,command,read,onDone,onCancel,children}:{title:string;command:Command;read:(f:FormData)=>Record<string,unknown>;onDone:(data:Json)=>void;onCancel:()=>void;children:ReactNode}) {
 const t=useWords(),mutation=useMutation(command,onDone),[dirty,setDirty]=useState(false);
 return <section className="scroll-mt-24 rounded-2xl border bg-card p-5 shadow-sm"><h2 className="mb-5 text-xl font-semibold">{title}</h2>
 <errorsContext.Provider value={mutation.fields}><form onChange={()=>setDirty(true)} onSubmit={e=>{e.preventDefault();mutation.submit(read(new FormData(e.currentTarget)));}}>
 <fieldset disabled={mutation.pending||mutation.uncertain} className="grid gap-4 sm:grid-cols-2">{children}</fieldset>
 {mutation.error&&<p className="mt-4 rounded-lg border border-red-500/40 p-3 text-sm" role="alert">{t(mutation.error.message,mutation.uncertain?'ফলাফল নিশ্চিত হয়নি। তথ্য পরিবর্তন না করে একই অনুরোধ আবার পাঠান।':mutation.error.code==='conflict'?'একই তথ্যের record আছে। তালিকা থেকে সেটি নির্বাচন বা সংশোধন করুন।':'প্রয়োজনীয় তথ্য, তারিখ ও নির্বাচন যাচাই করুন। আপনার input রাখা হয়েছে।')}</p>}
 <div className="mt-5 flex flex-wrap gap-3">{mutation.uncertain?<button type="button" disabled={mutation.pending} onClick={mutation.retry} className="rounded-lg border px-4 py-2.5">{t('Retry unchanged request','একই অনুরোধ আবার পাঠান')}</button>:<button disabled={mutation.pending} className="rounded-lg bg-primary px-4 py-2.5 text-primary-foreground">{mutation.pending?t('Saving…','সংরক্ষণ হচ্ছে…'):t('Save','সংরক্ষণ')}</button>}
 <button type="button" disabled={mutation.pending||mutation.uncertain} className="rounded-lg border px-4 py-2.5" onClick={()=>{if(!dirty||window.confirm(t('Discard these unsaved changes?','অসংরক্ষিত পরিবর্তন বাদ দেবেন?')))onCancel();}}>{t('Cancel','বাতিল')}</button></div>
 </form></errorsContext.Provider></section>;
}
export function Reason({value='Verified the selected details with the person'}:{value?:string}) {
 const t=useWords();return <Field label={t('Change reason','পরিবর্তনের কারণ')} name="reason"><select id="reason" name="reason" className={inputClass} defaultValue={value} required>
 <option value={value}>{t('Confirmed the selected details','নির্বাচিত তথ্য নিশ্চিত করেছি')}</option>
 <option value="Corrected details after checking the original record">{t('Corrected the original record','মূল record যাচাই করে সংশোধন')}</option>
 <option value="Updated setup for current academy operations">{t('Updated operational setup','বর্তমান পরিচালনার জন্য হালনাগাদ')}</option>
 </select></Field>;
}
export function ValueField({name,label,value='',type='text',required=false,...rest}:{name:string;label:string;value?:string|number|null;type?:string;required?:boolean;min?:number;max?:number;step?:string;maxLength?:number}) {
 return <Field name={name} label={label}><input id={name} name={name} className={inputClass} type={type} defaultValue={value??''} required={required} {...rest}/></Field>;
}
export function ActiveCheck({value=true}:{value?:boolean}) {const t=useWords();return <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="is_active" defaultChecked={value}/>{t('Active for new use','নতুন ব্যবহারের জন্য সক্রিয়')}</label>;}
export function text(f:FormData,key:string) {return String(f.get(key)??'').trim();}
export function PageControls({page,total,onPage}:{page:number;total:number;onPage:(page:number)=>void}) {const t=useWords();return <nav className="flex items-center gap-4 text-sm" aria-label={t('Pagination','পাতা পরিবর্তন')}><button type="button" disabled={page<=1} onClick={()=>onPage(page-1)}>{t('Previous','আগের')}</button><span>{t('Page','পাতা')} {page} · {t('Total','মোট')} {total}</span><button type="button" disabled={page*25>=total} onClick={()=>onPage(page+1)}>{t('Next','পরের')}</button></nav>;}
