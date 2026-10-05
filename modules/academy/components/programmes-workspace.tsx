'use client';
import {useState} from 'react';
import {programmeRow,pageSchema} from '../schema';
import {useRegister} from './register';
import {DirectoryPicker} from './directory-picker';
import {Editor,ValueField,ActiveCheck,Reason,text,inputClass,useWords,PageControls} from './common';
import {z} from 'zod';
const pages=pageSchema(programmeRow);
type Programme=z.infer<typeof programmeRow>;
export function ProgrammesWorkspace({canManage,canCreateDirectory}:{canManage:boolean;canCreateDirectory:boolean}) {
 const t=useWords(),list=useRegister('programmes',pages),[editor,setEditor]=useState<Programme|'NEW'|null>(null),[notice,setNotice]=useState('');
 const record=editor&&editor!=='NEW'?editor:null;
 return <div className="space-y-5"><header className="flex flex-wrap justify-between gap-3"><div><h1 className="text-2xl font-semibold">{t('Programme definitions','প্রোগ্রামের পরিচয়')}</h1><p className="text-sm text-muted-foreground">{t('Define the course once. Teaching dates, fees and batches belong to a programme offering.','কোর্সের পরিচয় একবার তৈরি করুন। তারিখ, ফি ও ব্যাচ programme offering-এর অংশ।')}</p></div>{canManage&&!editor&&<button className="rounded-lg border px-4 py-2" onClick={()=>setEditor('NEW')}>{t('Create programme','প্রোগ্রাম তৈরি')}</button>}</header>
 {notice&&<p role="status">{notice}</p>}
 {editor&&<Editor key={record?.id??'NEW'} title={t(record?'Edit programme':'Create programme',record?'প্রোগ্রাম সংশোধন':'প্রোগ্রাম তৈরি')} command="programme" onCancel={()=>setEditor(null)} onDone={()=>{setEditor(null);setNotice(t('Programme saved.','প্রোগ্রাম সংরক্ষিত।'));void list.load();}} read={f=>({...(record?{id:record.id,revision:record.revision}:{}),name:text(f,'name'),name_bn:text(f,'name_bn'),programme_type_id:text(f,'programme_type_id'),is_active:f.has('is_active'),reason:text(f,'reason')})}>
 <ValueField name="name" label={t('Programme name','প্রোগ্রামের নাম')} value={record?.name} required maxLength={160}/><ValueField name="name_bn" label={t('Bangla name (optional)','বাংলা নাম (ঐচ্ছিক)')} value={record?.name_bn} maxLength={160}/>
 <DirectoryPicker name="programme_type_id" kind="PROGRAMME_TYPE" canCreate={canCreateDirectory} initial={record?{id:record.programme_type_id,name:t('Current programme type — search to change','বর্তমান ধরন — পরিবর্তন করতে খুঁজুন')}:undefined}/><ActiveCheck value={record?.is_active??true}/><Reason/>
 </Editor>}
 <form className="flex gap-3" onSubmit={e=>{e.preventDefault();void list.load(1,list.query);}}><input aria-label={t('Search programmes','প্রোগ্রাম খুঁজুন')} className={inputClass} value={list.query} onChange={e=>list.setQuery(e.target.value)} maxLength={160}/><button disabled={list.loading} className="rounded-lg border px-4">{t('Search','খুঁজুন')}</button></form>
 {list.loading?<p role="status">{t('Loading…','লোড হচ্ছে…')}</p>:list.error?<p role="alert">{t('Could not load programmes.','প্রোগ্রাম লোড হয়নি।')} <button onClick={()=>void list.load()}>{t('Retry','আবার চেষ্টা')}</button></p>:<div className="overflow-x-auto rounded-xl border"><table className="w-full text-sm"><thead><tr className="text-left border-b"><th className="p-3">{t('Programme','প্রোগ্রাম')}</th><th>{t('Status','অবস্থা')}</th><th>{t('Actions','পদক্ষেপ')}</th></tr></thead><tbody>{list.data.rows.map(row=><tr key={row.id} className="border-b"><td className="p-3">{t(row.name,row.name_bn??row.name)}</td><td>{row.is_active?t('Active','সক্রিয়'):t('Inactive','নিষ্ক্রিয়')}</td><td>{canManage&&<button className="underline" onClick={()=>setEditor(row)}>{t('Edit / change status','সংশোধন / অবস্থা পরিবর্তন')}</button>}</td></tr>)}</tbody></table>{!list.data.rows.length&&<p className="p-4">{t('No matching programmes.','মিল পাওয়া যায়নি।')}</p>}</div>}
 <PageControls page={list.data.page} total={list.data.total} onPage={p=>void list.load(p)}/>
 </div>;
}
