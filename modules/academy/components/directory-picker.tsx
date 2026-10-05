'use client';
import {useRef,useState} from 'react';
import {searchAcademy} from '../actions';
import {choiceSchema,pageSchema,directoryListRow,programmeRow,type Choice,kinds} from '../schema';
import {inputClass,useWords,useMutation} from './common';

export function DirectoryPicker({name,kind,initial=null,onSelect,canCreate=false}:{name:string;kind:typeof kinds[number]|'PROGRAMME';initial?:Choice|null;onSelect?:(choice:Choice)=>void;canCreate?:boolean}) {
 const t=useWords(),[selected,setSelected]=useState<Choice|null>(initial),[query,setQuery]=useState(''),[open,setOpen]=useState(false),[creating,setCreating]=useState(false);
 const [rows,setRows]=useState<Choice[]>([]),[total,setTotal]=useState(0),[page,setPage]=useState(1),[loading,setLoading]=useState(false),[error,setError]=useState('');
 const [newName,setNewName]=useState(''),[newBn,setNewBn]=useState(''),[locality,setLocality]=useState(''),[type,setType]=useState('SCHOOL'),[programmeType,setProgrammeType]=useState<Choice|null>(null);
 const generation=useRef(0);
 const choose=(choice:Choice)=>{setSelected(choice);onSelect?.(choice);setOpen(false);setCreating(false);};
 const mutation=useMutation(kind==='PROGRAMME'?'programme':'directory',data=>{choose(choiceSchema.parse(data));setNewName('');setNewBn('');});
 async function search(next=1){const sequence=++generation.current;setLoading(true);setError('');try{
  const result=await searchAcademy(kind==='PROGRAMME'?'programmes':'directory',{query,page:next,kind:kind==='PROGRAMME'?undefined:kind});
  const parsed=kind==='PROGRAMME'?pageSchema(programmeRow).parse(result):pageSchema(directoryListRow).parse(result);
  if(sequence===generation.current){setRows(parsed.rows.filter(r=>r.is_active).map(r=>choiceSchema.parse(r)));setTotal(parsed.total);setPage(next);}
 }catch{if(sequence===generation.current)setError(t('Search failed. Retry.','খোঁজা যায়নি। আবার চেষ্টা করুন।'));}finally{if(sequence===generation.current)setLoading(false);}}
 function create(){if(!newName.trim()){setError(t('Enter the name.','নাম লিখুন।'));return;}
  if(kind==='PROGRAMME'&&!programmeType){setError(t('Choose a programme type.','প্রোগ্রামের ধরন নির্বাচন করুন।'));return;}
  mutation.submit(kind==='PROGRAMME'?{name:newName,name_bn:newBn,programme_type_id:programmeType?.id,reason:'Created programme while setting up current offering'}:{kind,name:newName,name_bn:newBn,locality:kind==='INSTITUTION'?locality:'',institution_type:kind==='INSTITUTION'?type:'',reason:'Created missing directory choice during current workflow'});
 }
 return <div className="space-y-2"><input type="hidden" name={name} value={selected?.id??''}/><input type="hidden" name={`${name}_label`} value={selected?.name??''}/>
 <button type="button" className={`${inputClass} text-left`} aria-expanded={open} onClick={()=>{setOpen(!open);if(!open)void search();}}>{selected?(t(selected.name,selected.nameBn??selected.name_bn??selected.name)):t('Search or choose…','খুঁজুন বা নির্বাচন করুন…')}</button>
 {open&&<div className="space-y-3 rounded-xl border p-3"><div className="flex gap-2"><input aria-label={t('Search choices','তালিকা খুঁজুন')} className={inputClass} value={query} onChange={e=>setQuery(e.target.value)} maxLength={160} onKeyDown={e=>{if(e.key==='Enter'){e.preventDefault();void search();}}}/><button type="button" disabled={loading} onClick={()=>void search()}>{t('Search','খুঁজুন')}</button></div>
 {loading?<p role="status">{t('Loading…','লোড হচ্ছে…')}</p>:error?<p role="alert">{error}</p>:<ul className="max-h-48 overflow-auto">{rows.map(row=><li key={row.id}><button type="button" className="w-full rounded-lg px-2 py-2 text-left hover:bg-muted" onClick={()=>choose(row)}>{t(row.name,row.nameBn??row.name_bn??row.name)}</button></li>)}{!rows.length&&<li>{t('No matching choice.','মিল পাওয়া যায়নি।')}</li>}</ul>}
 <div className="flex gap-3 text-sm"><button type="button" disabled={page<=1||loading} onClick={()=>void search(page-1)}>{t('Previous','আগের')}</button><button type="button" disabled={page*25>=total||loading} onClick={()=>void search(page+1)}>{t('Next','পরের')}</button>{canCreate&&<button type="button" onClick={()=>{setCreating(!creating);setNewName(query);}}>{t('Add missing choice','না থাকলে নতুন যোগ করুন')}</button>}</div>
 {creating&&<fieldset disabled={mutation.pending||mutation.uncertain} className="space-y-3 rounded-lg bg-muted/40 p-3" onKeyDown={e=>{if(e.key==='Enter'){e.preventDefault();create();}}}>
 <label className="block text-sm">{t('Name','নাম')}<input className={inputClass} value={newName} onChange={e=>setNewName(e.target.value)} maxLength={160}/></label>
 <details><summary className="cursor-pointer text-sm">{t('Additional details (optional)','অতিরিক্ত তথ্য (ঐচ্ছিক)')}</summary><label className="block text-sm">{t('Bangla name (optional)','বাংলা নাম (ঐচ্ছিক)')}<input className={inputClass} value={newBn} onChange={e=>setNewBn(e.target.value)} maxLength={160}/></label>
 {kind==='INSTITUTION'&&<><label className="block text-sm">{t('Locality','এলাকা')}<input className={inputClass} value={locality} onChange={e=>setLocality(e.target.value)} maxLength={160}/></label><label>{t('Institution type','প্রতিষ্ঠানের ধরন')}<select className={inputClass} value={type} onChange={e=>setType(e.target.value)}>{[['SCHOOL','School','স্কুল'],['COLLEGE','College','কলেজ'],['MADRASA','Madrasa','মাদ্রাসা'],['UNIVERSITY','University','বিশ্ববিদ্যালয়'],['OTHER','Other','অন্যান্য']].map(([id,en,bn])=><option key={id} value={id}>{t(en,bn)}</option>)}</select></label></>}
 </details>
 {kind==='PROGRAMME'&&<><p>{t('Programme type','প্রোগ্রামের ধরন')}</p><DirectoryPicker name={`${name}_new_type`} kind="PROGRAMME_TYPE" onSelect={setProgrammeType} canCreate={canCreate}/></>}
 <button type="button" className="rounded-lg border px-3 py-2" onClick={create}>{mutation.pending?t('Saving…','সংরক্ষণ হচ্ছে…'):t('Save and select','সংরক্ষণ করে নির্বাচন')}</button></fieldset>}
 {mutation.error&&<p role="alert" className="text-sm text-red-600">{t(mutation.error.message,mutation.uncertain?'ফলাফল নিশ্চিত হয়নি। একই অনুরোধ আবার পাঠান।':'নাম ও নির্বাচন যাচাই করুন; একই নাম আগে থাকলে সেটি খুঁজে নির্বাচন করুন।')}</p>}
 {mutation.uncertain&&<button type="button" disabled={mutation.pending} onClick={mutation.retry}>{t('Retry unchanged request','একই অনুরোধ আবার পাঠান')}</button>}
 </div>}</div>;
}
