'use client';
import {useState,useTransition} from 'react';
import {admissionPeople} from './actions';
import type {AdmissionPerson} from './contracts';
import {inputClass,useWords} from '@/modules/academy/components/common';
export function AdmissionPersonPicker({onSelect}:{onSelect:(p:AdmissionPerson)=>void}){
 const t=useWords(),[query,setQuery]=useState(''),[page,setPage]=useState(1),[rows,setRows]=useState<AdmissionPerson[]>([]),[pending,start]=useTransition(),[message,setMessage]=useState('');
 function search(next=1){start(async()=>{try{setRows(await admissionPeople(query,next));setPage(next);setMessage('');}catch{setMessage(t('Enter two characters or more, then retry.','অন্তত দুই অক্ষর লিখে আবার খুঁজুন।'));}});}
 return <div className="space-y-2 rounded-xl border p-3"><div className="flex gap-2"><input className={inputClass} maxLength={160} value={query} onChange={e=>setQuery(e.target.value)} aria-label={t('Existing person name or mobile','আগের ব্যক্তির নাম বা মোবাইল')} onKeyDown={e=>{if(e.key==='Enter'){e.preventDefault();search();}}}/><button type="button" disabled={pending||query.trim().length<2} onClick={()=>search()} className="cursor-pointer rounded-lg border px-3">{pending?t('Searching…','খুঁজছে…'):t('Search existing','আগের পরিচয় খুঁজুন')}</button></div>{message&&<p role="alert">{message}</p>}<ul className="max-h-52 overflow-auto">{rows.map(p=><li key={p.id}><button type="button" disabled={pending} className="w-full cursor-pointer rounded-lg p-2 text-left hover:bg-muted" onClick={()=>onSelect(p)}>{p.full_name} · {p.student_no?'SA-'+String(p.student_no).padStart(6,'0'):t('Existing identity','আগের পরিচয়')} · {p.mobile??'—'}</button></li>)}</ul>{rows.length>0&&<div className="flex gap-3"><button type="button" disabled={pending||page===1} onClick={()=>search(page-1)}>{t('Previous','আগের')}</button><button type="button" disabled={pending||rows.length<25} onClick={()=>search(page+1)}>{t('Next','পরের')}</button></div>}</div>;
}
