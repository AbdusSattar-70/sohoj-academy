"use client";

import { useMemo, useState, useTransition } from "react";
import { saveAttendance } from "@/app/actions/transactions";
import { Button } from "@/components/ui/button";

type Batch={id:string;name:string};
type Session={id:string;batch_id:string;session_date:string;starts_at:string;ends_at:string;subject_name:string|null};
type Student={id:string;student_no:string;name:string;batch_id:string|null};
type Existing={session_id:string;student_id:string;status:"PRESENT"|"ABSENT"|"LATE"|"EXCUSED";remarks:string|null};

export function AttendanceManager({batches,sessions,students,existing}:{batches:Batch[];sessions:Session[];students:Student[];existing:Existing[]}) {
 const [batchId,setBatchId]=useState(batches[0]?.id??"");
 const batchSessions=useMemo(()=>sessions.filter(x=>x.batch_id===batchId),[sessions,batchId]);
 const [sessionId,setSessionId]=useState("");
 const selectedSessionId=sessionId && batchSessions.some(x=>x.id===sessionId)?sessionId:(batchSessions[0]?.id??"");
 const roster=useMemo(()=>students.filter(x=>x.batch_id===batchId),[students,batchId]);
 const [changes,setChanges]=useState<Record<string,{status:Existing["status"];remarks:string}>>({});
 const [message,setMessage]=useState<string|null>(null);
 const [pending,startTransition]=useTransition();
 const existingMap=useMemo(()=>Object.fromEntries(existing.filter(x=>x.session_id===selectedSessionId).map(x=>[x.student_id,x])),[existing,selectedSessionId]);

 function current(studentId:string){
  return changes[studentId]??{status:existingMap[studentId]?.status??"PRESENT",remarks:existingMap[studentId]?.remarks??""};
 }
 function setStatus(studentId:string,status:Existing["status"]){setChanges(v=>({...v,[studentId]:{...current(studentId),status}}));}
 function setRemarks(studentId:string,remarks:string){setChanges(v=>({...v,[studentId]:{...current(studentId),remarks}}));}
 function submit(){
  if(!selectedSessionId)return;
  const fd=new FormData();
  fd.set("session_id",selectedSessionId);
  fd.set("entries",JSON.stringify(roster.map(s=>({student_id:s.id,...current(s.id)}))));
  startTransition(async()=>{
   const r=await saveAttendance(fd);
   setMessage(r.ok?`Attendance saved for ${r.count??roster.length} students.`:r.error??"Could not save attendance.");
  });
 }

 return <section className="rounded-xl border bg-card p-5">
  <div className="mb-5"><h2 className="text-lg font-semibold">Daily Attendance</h2><p className="text-sm text-muted-foreground">Choose a batch and class session, then mark every student.</p></div>
  <div className="mb-5 grid gap-3 md:grid-cols-2">
   <select value={batchId} onChange={e=>{setBatchId(e.target.value);setSessionId("");setChanges({});setMessage(null);}} className="h-9 rounded-md border bg-background px-3 text-sm">
    <option value="">Select batch</option>{batches.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}
   </select>
   <select value={selectedSessionId} onChange={e=>{setSessionId(e.target.value);setChanges({});setMessage(null);}} className="h-9 rounded-md border bg-background px-3 text-sm">
    <option value="">Select class session</option>{batchSessions.map(x=><option key={x.id} value={x.id}>{x.session_date} • {x.starts_at.slice(0,5)} • {x.subject_name??"Class"}</option>)}
   </select>
  </div>
  {!selectedSessionId?<p className="text-sm text-muted-foreground">No class session is available for this batch yet.</p>:
   <div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left"><th className="p-3">Student</th><th className="p-3">Status</th><th className="p-3">Remarks</th></tr></thead><tbody>
    {roster.map(s=>{const v=current(s.id);return <tr key={s.id} className="border-b"><td className="p-3"><div className="font-medium">{s.name}</div><div className="text-xs text-muted-foreground">{s.student_no}</div></td><td className="p-3"><select value={v.status} onChange={e=>setStatus(s.id,e.target.value as Existing["status"])} className="h-9 rounded-md border bg-background px-2 text-sm"><option value="PRESENT">Present</option><option value="ABSENT">Absent</option><option value="LATE">Late</option><option value="EXCUSED">Excused</option></select></td><td className="p-3"><input value={v.remarks} onChange={e=>setRemarks(s.id,e.target.value)} placeholder="Optional" className="h-9 w-full rounded-md border bg-background px-3 text-sm"/></td></tr>})}
   </tbody></table>{!roster.length&&<p className="py-8 text-center text-muted-foreground">No active students are enrolled in this batch.</p>}</div>}
  {message&&<div className="mt-4 rounded-md border p-3 text-sm">{message}</div>}
  <div className="mt-5 flex justify-end"><Button onClick={submit} disabled={pending||!selectedSessionId||!roster.length}>{pending?"Saving...":"Save Attendance"}</Button></div>
 </section>;
}
