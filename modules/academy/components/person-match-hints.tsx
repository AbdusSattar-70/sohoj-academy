'use client';
import {startTransition,useEffect,useRef,useState,type ReactNode} from 'react';
import {findPersonMatches} from '../actions';
import type {z} from 'zod';
import {personListRow} from '../schema';
import {useWords} from './common';
type Match=z.infer<typeof personListRow>;
export function PersonMatchHints({excludeId,onEdit,children}:{excludeId?:string;onEdit:(id:string)=>void;children:ReactNode}) {
 const t=useWords(),[input,setInput]=useState({full_name:'',mobile:'',email:''}),[matches,setMatches]=useState<Match[]>([]),[state,setState]=useState<'idle'|'loading'|'failed'>('idle'),generation=useRef(0);
 useEffect(()=>{
  const sequence=++generation.current;
  setMatches([]);setState('idle');
  if(input.full_name.length<2&&!input.mobile&&!input.email)return;
  const timer=setTimeout(()=>{
   setState('loading');
   startTransition(async()=>{try{const rows=await findPersonMatches({...input,exclude_id:excludeId});if(sequence===generation.current){setMatches(rows);setState('idle');}}catch{if(sequence===generation.current)setState('failed');}});
  },400);
  return ()=>{clearTimeout(timer);generation.current++;};
 },[input,excludeId]);
 return <div className="grid gap-4 sm:col-span-2 sm:grid-cols-2" onBlur={e=>{
  if(!(e.target instanceof HTMLInputElement)||!['full_name','mobile','email'].includes(e.target.name))return;
  const form=e.target.form;if(!form)return;
  const data=new FormData(form),next={full_name:String(data.get('full_name')??'').trim(),mobile:String(data.get('mobile')??'').trim(),email:String(data.get('email')??'').trim()};
  setInput(previous=>JSON.stringify(previous)===JSON.stringify(next)?previous:next);
 }}>
 {children}
 <p className="text-xs text-muted-foreground sm:col-span-2">{t('No personal mobile or email? Leave it blank. Shared family contacts are allowed. These details do not create a sign-in account.','নিজস্ব মোবাইল বা ইমেইল না থাকলে ফাঁকা রাখুন। পরিবারের একই যোগাযোগ ব্যবহার করা যায়। এগুলো দিয়ে login account তৈরি হয় না।')}</p>
 {state==='loading'&&<p role="status" className="text-sm sm:col-span-2">{t('Checking existing people…','আগের পরিচয় খোঁজা হচ্ছে…')}</p>}
 {state==='failed'&&<p role="status" className="text-sm sm:col-span-2">{t('Matching is unavailable. You can save; search the People list to check existing records.','মিল খোঁজা যায়নি। Save করা যাবে; আগের record দেখতে People তালিকায় খুঁজুন।')}</p>}
 {matches.length>0&&<aside className="rounded-lg border border-amber-500/50 p-3 sm:col-span-2" aria-live="polite"><p className="font-medium">{t('Possible existing people','আগের পরিচয়ের সঙ্গে মিল পাওয়া গেছে')}</p><p className="mt-1 text-sm">{t('A shared contact does not mean the same person. Continue saving for a different person, or edit an existing identity. Records are never merged automatically. Up to 10 matches shown.','একই যোগাযোগ মানেই একই ব্যক্তি নয়। আলাদা ব্যক্তি হলে Save করুন, অথবা আগের পরিচয় Edit করুন। স্বয়ংক্রিয়ভাবে record একত্র করা হয় না। সর্বোচ্চ ১০টি মিল দেখানো হচ্ছে।')}</p><ul className="mt-3 space-y-2">{matches.map(p=><li key={p.id} className="flex flex-wrap items-center justify-between gap-2 text-sm"><span>{p.full_name} · P-{p.person_no} · {p.mobile??'—'} · {p.email??'—'} · {p.is_active?t('Active','সক্রিয়'):t('Inactive','নিষ্ক্রিয়')}</span><button type="button" className="underline" onClick={()=>{if(window.confirm(t('Open this existing person instead? Unsaved changes in this form will be discarded.','আগের পরিচয় খুলবেন? এই form-এর অসংরক্ষিত তথ্য বাদ যাবে।')))onEdit(p.id);}}>{t('Edit this person','এই পরিচয় Edit করুন')}</button></li>)}</ul></aside>}
 </div>;
}
