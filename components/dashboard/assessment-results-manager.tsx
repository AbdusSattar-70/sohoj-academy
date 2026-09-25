"use client";
import {useMemo,useState,useTransition} from "react";
import {saveAssessmentResults} from "@/app/actions/transactions";
import {Button} from "@/components/ui/button";

type Assessment={id:string;title:string;batch_id:string;total_marks:number;held_on:string};
type Student={id:string;student_no:string;name:string;batch_id:string|null};
type Result={assessment_id:string;student_id:string;marks:number;remarks:string|null};

export function AssessmentResultsManager({assessments,students,results}:{assessments:Assessment[];students:Student[];results:Result[]}) {
 const [assessmentId,setAssessmentId]=useState(assessments[0]?.id??"");
 const assessment=assessments.find(x=>x.id===assessmentId);
 const roster=useMemo(()=>students.filter(x=>x.batch_id===assessment?.batch_id),[students,assessment]);
 const existing=useMemo(()=>Object.fromEntries(results.filter(x=>x.assessment_id===assessmentId).map(x=>[x.student_id,x])),[results,assessmentId]);
 const [changes,setChanges]=useState<Record<string,{marks:string;remarks:string}>>({});
 const [message,setMessage]=useState<string|null>(null); const [pending,startTransition]=useTransition();
 function current(id:string){return changes[id]??{marks:existing[id]?.marks?.toString()??"",remarks:existing[id]?.remarks??""};}
 function update(id:string,key:"marks"|"remarks",value:string){setChanges(v=>({...v,[id]:{...current(id),[key]:value}}));}
 function submit(){
  if(!assessment)return;
  const incomplete=roster.some(s=>current(s.id).marks===""); if(incomplete){setMessage("Enter marks for every student before saving.");return;}
  const fd=new FormData();fd.set("assessment_id",assessment.id);fd.set("entries",JSON.stringify(roster.map(s=>({student_id:s.id,marks:Number(current(s.id).marks),remarks:current(s.id).remarks}))));
  startTransition(async()=>{const r=await saveAssessmentResults(fd);setMessage(r.ok?`Results saved for ${r.count??roster.length} students.`:r.error??"Could not save results.");});
 }
 return <section className="mt-6 rounded-xl border bg-card p-5"><div className="mb-4"><h2 className="text-lg font-semibold">Enter Results</h2><p className="text-sm text-muted-foreground">Select an assessment and enter marks for its batch.</p></div>
  <select value={assessmentId} onChange={e=>{setAssessmentId(e.target.value);setChanges({});setMessage(null);}} className="mb-5 h-9 w-full rounded-md border bg-background px-3 text-sm md:w-96"><option value="">Select assessment</option>{assessments.map(x=><option key={x.id} value={x.id}>{x.held_on} • {x.title} • {x.total_marks}</option>)}</select>
  {assessment&&<div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left"><th className="p-3">Student</th><th className="p-3">Marks / {assessment.total_marks}</th><th className="p-3">Remarks</th></tr></thead><tbody>{roster.map(s=>{const v=current(s.id);return <tr key={s.id} className="border-b"><td className="p-3"><b>{s.name}</b><div className="text-xs text-muted-foreground">{s.student_no}</div></td><td className="p-3"><input type="number" min="0" max={assessment.total_marks} step="0.01" value={v.marks} onChange={e=>update(s.id,"marks",e.target.value)} className="h-9 w-28 rounded-md border bg-background px-3"/></td><td className="p-3"><input value={v.remarks} onChange={e=>update(s.id,"remarks",e.target.value)} className="h-9 w-full rounded-md border bg-background px-3" placeholder="Optional"/></td></tr>})}</tbody></table>{!roster.length&&<p className="py-8 text-center text-muted-foreground">No active students in this assessment batch.</p>}</div>}
  {message&&<div className="mt-4 rounded-md border p-3 text-sm">{message}</div>}<div className="mt-5 flex justify-end"><Button onClick={submit} disabled={pending||!assessment||!roster.length}>{pending?"Saving...":"Save Results"}</Button></div>
 </section>;
}
