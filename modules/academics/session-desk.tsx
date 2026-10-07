'use client';
import Link from 'next/link';
import {useState,useTransition} from 'react';
import {z} from 'zod';
import {inputClass,useWords} from '@/modules/academy/components/common';
import {loadAcademicChoices,loadAcademicDesk,saveAcademicOperation} from './actions';
import {OperationForm} from './operation-form';
const choice=z.object({id:z.string(),name:z.string()});
const sessionSchema=z.object({id:z.string(),batch_id:z.string(),subject_id:z.string(),teacher_id:z.string(),room_id:z.string(),starts_at:z.string(),ends_at:z.string(),status:z.string(),revision:z.number(),batch_name:z.string(),subject_name:z.string(),teacher_name:z.string(),room_name:z.string(),report:z.string().nullable(),actual_start:z.string().nullable(),actual_end:z.string().nullable()});
const listSchema=z.object({manage:z.boolean(),sessions:z.array(sessionSchema),total:z.number()});
const choicesSchema=z.object({rooms:z.array(choice),batches:z.array(choice.extend({subjectIds:z.array(z.string())})),teachers:z.array(choice),subjects:z.array(choice),qualifications:z.array(z.object({teacherId:z.string(),subjectId:z.string()}))});
type Session=z.infer<typeof sessionSchema>;
type Action='CREATE'|'CHANGE'|'MAKEUP'|'ROUTINE'|'SUBMIT'|'APPROVE'|'RETURN'|'CANCEL';
function local(value:string){return new Date(new Date(value).getTime()+6*3600000).toISOString().slice(0,16);}
export function SessionDesk({initial}:{initial:unknown}){
 const t=useWords(),[data,setData]=useState(()=>listSchema.parse(initial)),[page,setPage]=useState(1),[form,setForm]=useState<{action:Action;item?:Session}|null>(null),[choices,setChoices]=useState<z.infer<typeof choicesSchema>|null>(null),[batch,setBatch]=useState(''),[subject,setSubject]=useState(''),[message,setMessage]=useState(''),[nextHref,setNextHref]=useState(''),[pending,startTransition]=useTransition();
 const days=[t('Sunday','রবিবার'),t('Monday','সোমবার'),t('Tuesday','মঙ্গলবার'),t('Wednesday','বুধবার'),t('Thursday','বৃহস্পতিবার'),t('Friday','শুক্রবার'),t('Saturday','শনিবার')];
 const labels:Record<Action,string>={CREATE:t('Schedule class','ক্লাসের সময় দিন'),CHANGE:t('Change teacher / room / time','শিক্ষক / শ্রেণিকক্ষ / সময় বদলান'),MAKEUP:t('Arrange makeup class','অতিরিক্ত ক্লাস দিন'),ROUTINE:t('Create weekly classes','সাপ্তাহিক ক্লাস তৈরি'),SUBMIT:t('Submit teaching report','পাঠদানের প্রতিবেদন জমা'),APPROVE:t('Approve report','প্রতিবেদন অনুমোদন'),RETURN:t('Return for correction','সংশোধনের জন্য ফেরত'),CANCEL:t('Cancel class','ক্লাস বাতিল')};
 const reasons:Record<Action,string[]>={CREATE:['Scheduled agreed class'],CHANGE:['Teacher unavailable; substitute confirmed','Room unavailable; replacement confirmed','Rescheduled with affected participants'],MAKEUP:['Makeup arranged for cancelled class'],ROUTINE:['Created agreed weekly timetable'],SUBMIT:['Teaching report completed'],APPROVE:['Verified completed teaching report'],RETURN:['Return report for correction'],CANCEL:['Class cancelled due to absence','Class cancelled due to unexpected closure']};
 async function reload(next=page){setData(listSchema.parse(await loadAcademicDesk(next)));setPage(next);}
 function open(action:Action,item?:Session){
  if(form||pending)return;setMessage('');setNextHref('');
  if(['CREATE','CHANGE','MAKEUP','ROUTINE'].includes(action))startTransition(async()=>{
   try{
    const options=choicesSchema.parse(await loadAcademicChoices('SESSION'));
    const missing=!options.batches.length?{message:t('Prepare an active programme and batch first.','আগে সক্রিয় প্রোগ্রাম ও ব্যাচ প্রস্তুত করুন।'),href:'/dashboard/academics/programmes'}:!options.rooms.length?{message:t('Create an active classroom first.','আগে সক্রিয় শ্রেণিকক্ষ তৈরি করুন।'),href:'/dashboard/academics/settings?section=rooms'}:!options.teachers.length||!options.qualifications.length?{message:t('Verify a teacher and subject qualification first.','আগে শিক্ষক ও বিষয়ের যোগ্যতা যাচাই করুন।'),href:'/dashboard/academics/settings?section=teachers'}:null;
    if(missing){setMessage(missing.message);setNextHref(missing.href);return;}
    setChoices(options);setBatch(item?.batch_id??'');setSubject(item?.subject_id??'');setForm({action,item});
   }catch{setMessage(t('Could not load class choices. Retry.','ক্লাসের তালিকা আসেনি। আবার চেষ্টা করুন।'));}
  });else setForm({action,item});
 }
 function field(name:string,label:string,type='text',value?:string){return <label>{label}<input className={inputClass} name={name} type={type} required defaultValue={value}/></label>;}
 function picker(name:string,label:string,options:z.infer<typeof choice>[],value?:string){return <label>{label}<select key={name==='teacherId'?subject:name} required name={name} className={inputClass} defaultValue={value??''}><option value="">{t('Select…','নির্বাচন করুন…')}</option>{options.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>;}
 function status(value:string){return({SCHEDULED:t('Scheduled','সময় নির্ধারিত'),CANCELLED:t('Cancelled','বাতিল'),SUBMITTED:t('Awaiting review','যাচাই বাকি'),RETURNED:t('Correction needed','সংশোধন প্রয়োজন'),APPROVED:t('Approved','অনুমোদিত')} as Record<string,string>)[value]??value;}
 return <section className="space-y-5"><header><h1 className="text-3xl font-semibold">{t('Class operation','ক্লাস পরিচালনা')}</h1><p className="mt-2 text-sm text-muted-foreground">{t('Today and reports needing review appear first. Choose an action on the class you need. All times are Bangladesh time.','আজকের ক্লাস ও যাচাই বাকি প্রতিবেদন আগে দেখাবে। প্রয়োজনীয় ক্লাসে পদক্ষেপ নিন। সব সময় বাংলাদেশ সময়।')}</p></header>
 {data.manage&&<div className="flex flex-wrap gap-3">{(['CREATE','ROUTINE'] as const).map(action=><button key={action} disabled={pending||!!form} className="rounded-lg border px-4 py-2" onClick={()=>open(action)}>{labels[action]}</button>)}</div>}
 {message&&<p role="status" className="rounded-lg border p-3">{message}{nextHref&&<Link prefetch={false} href={nextHref} className="ml-3 underline">{t('Next: open the required setup →','পরের কাজ: প্রয়োজনীয় প্রস্তুতি খুলুন →')}</Link>}</p>}
 {pending&&<p role="status">{t('Loading…','তথ্য আসছে…')}</p>}
 {form&&<OperationForm key={form.action+(form.item?.id??'NEW')} title={labels[form.action]} reasonOptions={reasons[form.action]} save={saveAcademicOperation} onSaved={async()=>{setForm(null);try{await reload();setMessage(t('Saved. The class list shows your next available action.','সংরক্ষিত। ক্লাসের তালিকায় পরের পদক্ষেপ দেখুন।'));}catch{setMessage(t('Saved, but the list could not refresh. Use Refresh before the next action.','সংরক্ষিত; তালিকা refresh হয়নি। পরের কাজের আগে আবার দেখুন বোতাম ব্যবহার করুন।'));}}} onCancel={()=>setForm(null)} serialize={fd=>{
  const payload:Record<string,unknown>={...Object.fromEntries(fd),action:form.action};
  if(form.item){payload.id=form.item.id;payload.revision=form.item.revision;}
  if(['CREATE','CHANGE','MAKEUP','ROUTINE'].includes(form.action)){payload.batchId=batch;payload.subjectId=subject;}
  if(form.action==='ROUTINE')payload.weekdays=fd.getAll('weekdays').map(Number);
  for(const key of ['start','end','actualStart','actualEnd'])if(fd.get(key))payload[key]=new Date(String(fd.get(key))+'+06:00').toISOString();
  return payload;
 }}>
 {['CREATE','CHANGE','MAKEUP','ROUTINE'].includes(form.action)&&choices&&<>
  {form.item?<p>{form.item.batch_name} · {form.item.subject_name}</p>:<><label>{t('Batch','ব্যাচ')}<select required className={inputClass} value={batch} onChange={e=>{setBatch(e.target.value);setSubject('');}}><option value="">{t('Select…','নির্বাচন করুন…')}</option>{choices.batches.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>{t('Subject','বিষয়')}<select required className={inputClass} value={subject} onChange={e=>setSubject(e.target.value)}><option value="">{t('Select…','নির্বাচন করুন…')}</option>{choices.subjects.filter(x=>choices.batches.find(b=>b.id===batch)?.subjectIds.includes(x.id)).map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label></>}
  {picker('teacherId',t('Qualified teacher / substitute','যোগ্য শিক্ষক / বিকল্প শিক্ষক'),choices.teachers.filter(x=>choices.qualifications.some(q=>q.teacherId===x.id&&q.subjectId===subject)),form.item?.teacher_id)}
  {picker('roomId',t('Classroom','শ্রেণিকক্ষ'),choices.rooms,form.item?.room_id)}
  {subject&&!choices.qualifications.some(x=>x.subjectId===subject)&&<p role="status">{t('No qualified teacher for this subject. Verify its qualification under Academic settings first.','এই বিষয়ের যোগ্য শিক্ষক নেই। আগে শিক্ষা সেটিংসে যোগ্যতা যাচাই করুন।')}</p>}
  {form.action==='ROUTINE'?<>{field('startsOn',t('From date','শুরুর তারিখ'),'date')}{field('endsOn',t('Through date · maximum 32 days','শেষ তারিখ · সর্বোচ্চ ৩২ দিন'),'date')}{field('startTime',t('Starts','শুরু'),'time')}{field('endTime',t('Ends','শেষ'),'time')}<div className="flex flex-wrap gap-3">{days.map((day,index)=><label key={day}><input type="checkbox" name="weekdays" value={index}/> {day}</label>)}</div></>:<>{field('start',t('Starts','শুরু'),'datetime-local',form.item?local(form.item.starts_at):undefined)}{field('end',t('Ends','শেষ'),'datetime-local',form.item?local(form.item.ends_at):undefined)}</>}
 </>}
 {form.action==='SUBMIT'&&<>{field('actualStart',t('Actual start','প্রকৃত শুরুর সময়'),'datetime-local',local(form.item!.starts_at))}{field('actualEnd',t('Actual end','প্রকৃত শেষ সময়'),'datetime-local',local(form.item!.ends_at))}<label>{t('What was taught','কী পড়ানো হয়েছে')}<textarea name="report" required className={inputClass} defaultValue={form.item?.report??''}/></label></>}
 {form.item&&['APPROVE','RETURN','CANCEL'].includes(form.action)&&<p>{form.item.batch_name} · {form.item.teacher_name} · {form.item.report??t('No teaching report yet.','এখনো পাঠদানের প্রতিবেদন নেই।')}</p>}
 </OperationForm>}
 <div className="overflow-auto rounded-xl border"><table className="w-full text-sm"><thead><tr>{[t('Class / time','ক্লাস / সময়'),t('Teacher / room','শিক্ষক / শ্রেণিকক্ষ'),t('Status','অবস্থা'),t('Next action','পরের পদক্ষেপ')].map(label=><th key={label} className="p-3 text-left">{label}</th>)}</tr></thead><tbody>{data.sessions.map(item=>{
  const actions:Action[]=data.manage?(item.status==='SUBMITTED'?['APPROVE','RETURN']:item.status==='CANCELLED'?['MAKEUP']:['SCHEDULED','RETURNED'].includes(item.status)?['CHANGE','CANCEL']:[]):['SCHEDULED','RETURNED'].includes(item.status)?['SUBMIT']:[];
  return <tr key={item.id} className="border-t"><td className="p-3">{item.batch_name} · {item.subject_name}<p className="text-xs">{new Date(item.starts_at).toLocaleString(t('en-GB','bn-BD'),{timeZone:'Asia/Dhaka'})} – {new Date(item.ends_at).toLocaleTimeString(t('en-GB','bn-BD'),{timeZone:'Asia/Dhaka'})}</p>{item.report&&<details><summary>{t('Teaching report','পাঠদানের প্রতিবেদন')}</summary><p>{item.report}</p></details>}</td><td>{item.teacher_name}<br/>{item.room_name}</td><td>{status(item.status)}</td><td className="space-x-3 p-3">{actions.map(action=><button disabled={pending||!!form} key={action} className="underline" onClick={()=>open(action,item)}>{labels[action]}</button>)}</td></tr>;
 })}</tbody></table>{!data.sessions.length&&<p className="p-4">{data.manage?t('No classes yet. Complete setup, then schedule your first class.','এখনো ক্লাস নেই। প্রস্তুতি শেষ করে প্রথম ক্লাসের সময় দিন।'):t('No classes assigned to you yet. Ask your administrator to assign your teaching sessions.','আপনার জন্য এখনো ক্লাস নির্ধারিত নেই। প্রশাসককে ক্লাসের দায়িত্ব দিতে বলুন।')}</p>}</div>
 <div className="flex flex-wrap gap-4"><button disabled={pending||!!form||page===1} onClick={()=>startTransition(async()=>{try{await reload(page-1);}catch{setMessage(t('Could not load the page.','পাতাটি লোড হয়নি।'));}})}>{t('Previous','আগের পাতা')}</button><span>{t('Page','পাতা')} {page} · {data.total} {t('classes','ক্লাস')}</span><button disabled={pending||!!form||page*25>=data.total} onClick={()=>startTransition(async()=>{try{await reload(page+1);}catch{setMessage(t('Could not load the page.','পাতাটি লোড হয়নি।'));}})}>{t('Next','পরের পাতা')}</button><button disabled={pending||!!form} onClick={()=>startTransition(async()=>{try{await reload();}catch{setMessage(t('Could not refresh. Retry.','তালিকা আসেনি। আবার চেষ্টা করুন।'));}})}>{t('Refresh','আবার দেখুন')}</button></div>
 </section>;
}
