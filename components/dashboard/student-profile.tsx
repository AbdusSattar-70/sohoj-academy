import {Card,CardContent,CardHeader,CardTitle} from "@/components/ui/card";

type Student={id:string;student_no:string;name:string;name_bn:string|null;gender:string|null;date_of_birth:string|null;school_name:string|null;school_roll:string|null;status:string;created_at:string};
type Enrollment={id:string;admission_date:string;monthly_fee:number;discount:number;effective_fee:number|null;is_active:boolean;classes:{name:string}|null;batches:{name:string}|null;programs:{name:string}|null;academic_years:{name:string}|null};
type GuardianLink={relationship:string;is_primary:boolean;guardians:{name:string;mobile:string;alternate_mobile:string|null;address:string|null}|null};
type Attendance={status:string;marked_at:string;class_sessions:{session_date:string;subjects:{name:string}|null}|null};
type Result={marks:number;remarks:string|null;assessments:{title:string;total_marks:number;held_on:string;subjects:{name:string}|null}|null};
type Payment={receipt_no:string;amount:number;payment_date:string;method:string;status:string};

export function StudentProfile({student,enrollments,guardians,attendance,results,payments}:{student:Student;enrollments:Enrollment[];guardians:GuardianLink[];attendance:Attendance[];results:Result[];payments:Payment[]}) {
 const active=enrollments.find(x=>x.is_active)??enrollments[0];
 const present=attendance.filter(x=>x.status==="PRESENT"||x.status==="LATE").length;
 const attendanceRate=attendance.length?Math.round(present/attendance.length*100):null;
 const percentages=results.filter(x=>x.assessments?.total_marks).map(x=>x.marks/Number(x.assessments!.total_marks)*100);
 const academicAvg=percentages.length?Math.round(percentages.reduce((a,b)=>a+b,0)/percentages.length):null;
 const paid=payments.filter(x=>x.status==="POSTED").reduce((a,x)=>a+Number(x.amount),0);
 const effective=active?.effective_fee??Math.max(0,Number(active?.monthly_fee??0)-Number(active?.discount??0));
 const primary=guardians.find(x=>x.is_primary)??guardians[0];

 return <div className="space-y-6">
  <div className="flex flex-wrap items-start justify-between gap-4"><div><a href="/dashboard/students" className="text-sm text-muted-foreground hover:underline">← Student Master</a><h1 className="mt-2 text-2xl font-bold">{student.name}</h1><p className="text-muted-foreground">{student.student_no}{student.name_bn?` • ${student.name_bn}`:""}</p></div><span className="rounded-full border px-3 py-1 text-sm">{student.status}</span></div>
  <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
   <Metric label="Attendance" value={attendanceRate===null?"—":attendanceRate+"%"} note={attendance.length+` records`}/>
   <Metric label="Academic Average" value={academicAvg===null?"—":academicAvg+"%"} note={results.length+` results`}/>
   <Metric label="Effective Monthly Fee" value={`৳${Number(effective).toLocaleString()}`} note={active?.academic_years?.name??"No active enrollment"}/>
   <Metric label="Total Payments" value={`৳${paid.toLocaleString()}`} note={payments.filter(x=>x.status==="POSTED").length+` receipts`}/>
  </div>
  <div className="grid gap-6 xl:grid-cols-2">
   <Info title="Student & Enrollment">{[
    ["School",student.school_name??"—"],["School Roll",student.school_roll??"—"],["Gender",student.gender??"—"],["Date of Birth",student.date_of_birth??"—"],
    ["Class",active?.classes?.name??"—"],["Batch",active?.batches?.name??"—"],["Program",active?.programs?.name??"—"],["Admission Date",active?.admission_date??"—"]
   ]}</Info>
   <Info title="Primary Guardian">{[["Name",primary?.guardians?.name??"—"],["Relationship",primary?.relationship??"—"],["Mobile",primary?.guardians?.mobile??"—"],["Alternate",primary?.guardians?.alternate_mobile??"—"],["Address",primary?.guardians?.address??"—"]]}</Info>
  </div>
  <History title="Recent Attendance" headers={["Date","Subject","Status"]} rows={attendance.slice(0,20).map(x=>[x.class_sessions?.session_date??x.marked_at.slice(0,10),x.class_sessions?.subjects?.name??"Class",x.status])}/>
  <History title="Assessment Results" headers={["Date","Assessment","Subject","Marks"]} rows={results.map(x=>[x.assessments?.held_on??"—",x.assessments?.title??"—",x.assessments?.subjects?.name??"—",x.assessments?`${x.marks} / ${x.assessments.total_marks}`:String(x.marks)])}/>
  <History title="Payment History" headers={["Date","Receipt","Method","Amount","Status"]} rows={payments.map(x=>[x.payment_date,x.receipt_no,x.method,`৳${Number(x.amount).toLocaleString()}`,x.status])}/>
 </div>;
}
function Metric({label,value,note}:{label:string;value:string;note:string}){return <Card><CardHeader className="pb-2"><CardTitle className="text-sm">{label}</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">{value}</div><p className="text-xs text-muted-foreground">{note}</p></CardContent></Card>}
function Info({title,children}:{title:string;children:[string,string][]}){return <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent className="space-y-2">{children.map(([a,b])=><div key={a} className="flex justify-between gap-4 border-b py-2 text-sm"><span className="text-muted-foreground">{a}</span><span className="text-right font-medium">{b}</span></div>)}</CardContent></Card>}
function History({title,headers,rows}:{title:string;headers:string[];rows:string[][]}){return <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left">{headers.map(x=><th key={x} className="p-3">{x}</th>)}</tr></thead><tbody>{rows.map((r,i)=><tr key={i} className="border-b">{r.map((x,j)=><td key={j} className="p-3">{x}</td>)}</tr>)}</tbody></table>{!rows.length&&<p className="py-6 text-center text-sm text-muted-foreground">No records yet.</p>}</div></CardContent></Card>}
