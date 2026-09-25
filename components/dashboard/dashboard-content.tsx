import Link from "next/link";
import { AppSidebar } from "@/components/dashboard/app-sidebar";
import { DashboardHeader } from "@/components/dashboard/dashboard-header";
import { AdmissionForm } from "@/components/dashboard/admission-form";
import { SettingsManager } from "@/components/dashboard/settings-manager";
import { AssessmentManager, FeeManager, NoticeManager, PaymentManager, TeacherManager } from "@/components/dashboard/operation-managers";
import { AttendanceManager } from "@/components/dashboard/attendance-manager";
import { AssessmentResultsManager } from "@/components/dashboard/assessment-results-manager";
import { StudentProfile } from "@/components/dashboard/student-profile";
import { ParentCommunicationManager, ProgressManager } from "@/components/dashboard/progress-parent-managers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { createClient } from "@/lib/supabase/server";
import type { AppRole } from "@/lib/constants";
import { LocalizedText } from "@/components/shared/localized-text";
import type { User } from "@/types/user";

const modules:Record<string,string>={admissions:"Admission Entry",students:"Student Master",guardians:"Guardians",attendance:"Attendance",assessments:"Assessments & Results",progress:"Progress Reports",fees:"Fee Structure",payments:"Fee Collection",parents:"Parent Communication",notices:"Notices",teachers:"Teachers",settings:"Settings"};
const modulesBn:Record<string,string>={admissions:"ভর্তি",students:"শিক্ষার্থী মাস্টার",guardians:"অভিভাবক",attendance:"উপস্থিতি",assessments:"মূল্যায়ন ও ফলাফল",progress:"অগ্রগতি প্রতিবেদন",fees:"ফি কাঠামো",payments:"ফি সংগ্রহ",parents:"অভিভাবক যোগাযোগ",notices:"নোটিশ",teachers:"শিক্ষক",settings:"সেটিংস"};
const moduleRoles:Record<string,AppRole[]>={
 admissions:["ADMIN","OPERATOR"],
 students:["ADMIN","OPERATOR","TEACHER"],
 guardians:["ADMIN","OPERATOR","TEACHER"],
 attendance:["ADMIN","OPERATOR","TEACHER"],
 assessments:["ADMIN","OPERATOR","TEACHER"],
 progress:["ADMIN","OPERATOR","TEACHER"],
 fees:["ADMIN","OPERATOR"],
 payments:["ADMIN","OPERATOR"],
 parents:["ADMIN","OPERATOR","TEACHER"],
 notices:["ADMIN","OPERATOR"],
 teachers:["ADMIN","OPERATOR","TEACHER"],
 settings:["ADMIN"]
};

export default async function DashboardContent({user,section="dashboard",studentId}:{user:User;section?:string;studentId?:string}){
 const title=section==="dashboard"?"Dashboard":modules[section]??"Dashboard"; const s=await createClient();
 const [yearsQ,classesQ,programsQ,batchesQ,subjectsQ]=await Promise.all([
  s.from("academic_years").select("id,name,starts_on,ends_on,is_active").order("starts_on",{ascending:false}),
  s.from("classes").select("id,name,sort_order").order("sort_order"),
  s.from("programs").select("id,name,code").eq("is_active",true).order("name"),
  s.from("batches").select("id,name,class_id,program_id,academic_year_id,capacity").eq("is_active",true).order("name"),
  s.from("subjects").select("id,name,code").eq("is_active",true).order("name")
 ]);
 const years=yearsQ.data??[], classes=classesQ.data??[], programs=programsQ.data??[], batches=batchesQ.data??[], subjects=subjectsQ.data??[];
 let body:React.ReactNode;

 if(section==="dashboard"){
  const [studentCount,todayAttendance,paymentSum,testCount]=await Promise.all([
   s.from("students").select("*",{count:"exact",head:true}).eq("status","ACTIVE"),
   s.from("attendance").select("*",{count:"exact",head:true}).gte("marked_at",new Date().toISOString().slice(0,10)),
   s.from("payments").select("amount").eq("status","POSTED"),
   s.from("assessments").select("*",{count:"exact",head:true}).gte("held_on",new Date().toISOString().slice(0,10))
  ]);
  const total=(paymentSum.data??[]).reduce((a,x)=>a+Number(x.amount),0);
  const stats=[
   [<LocalizedText key="active" en="Active Students" bn="সক্রিয় শিক্ষার্থী"/>,studentCount.count??0],
   [<LocalizedText key="attendance" en="Attendance Marked Today" bn="আজ উপস্থিতি নেয়া হয়েছে"/>,todayAttendance.count??0],
   [<LocalizedText key="fees" en="Fees Collected" bn="সংগৃহীত ফি"/>,`৳${total.toLocaleString()}`],
   [<LocalizedText key="tests" en="Upcoming Tests" bn="আসন্ন পরীক্ষা"/>,testCount.count??0]
  ];
  body=<><div><h1 className="text-2xl font-bold"><LocalizedText en="Digital Campus" bn="ডিজিটাল ক্যাম্পাস"/></h1><p className="text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p></div><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{stats.map(([a,b],i)=><Card key={i}><CardHeader className="pb-2"><CardTitle className="text-sm">{a}</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">{b}</div></CardContent></Card>)}</div><Card><CardHeader><CardTitle><LocalizedText en="Operations" bn="অপারেশনসমূহ"/></CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-3">{Object.entries(modules).filter(([k])=>moduleRoles[k]?.includes(user.role)).map(([k,v])=><Link key={k} href={"/dashboard/"+k} className="rounded-lg border p-4 hover:bg-muted"><p className="font-medium"><LocalizedText en={v} bn={modulesBn[k]??v}/></p><p className="text-sm text-muted-foreground"><LocalizedText en="Open module" bn="মডিউল খুলুন"/></p></Link>)}</CardContent></Card></>;
 } else if(section==="admissions"&&(user.role==="ADMIN"||user.role==="OPERATOR")){
  const [activeEnrollmentsQ,schoolsQ]=await Promise.all([
   s.from("enrollments").select("batch_id").eq("is_active",true).not("batch_id","is",null),
   s.from("schools").select("id,name").eq("is_active",true).order("name").limit(1000)
  ]);
  const enrolledByBatch=new Map<string,number>();
  for(const row of activeEnrollmentsQ.data??[]){
   if(row.batch_id) enrolledByBatch.set(row.batch_id,(enrolledByBatch.get(row.batch_id)??0)+1);
  }
  const admissionBatches=batches.map(batch=>({...batch,enrolled:enrolledByBatch.get(batch.id)??0}));
  const schools=(schoolsQ.data??[]).map(school=>({id:school.id,label:school.name}));
  body=<Card><CardHeader><CardTitle>New Student Admission</CardTitle></CardHeader><CardContent><AdmissionForm academicYears={years} classes={classes} programs={programs} batches={admissionBatches} schools={schools}/></CardContent></Card>;
 } else if(section==="settings"&&user.role==="ADMIN"){
  body=<SettingsManager years={years} classes={classes} programs={programs} subjects={subjects} batches={batches}/>;
 } else if(section==="students"){
  if(studentId){
   const [studentQ,enrollmentsQ,guardiansQ,attendanceQ,resultsQ,paymentsQ]=await Promise.all([
    s.from("students").select("id,student_no,name,name_bn,gender,date_of_birth,school_name,school_roll,status,created_at").eq("id",studentId).maybeSingle(),
    s.from("enrollments").select("id,admission_date,monthly_fee,discount,effective_fee,is_active,classes(name),batches(name),programs(name),academic_years(name)").eq("student_id",studentId).order("admission_date",{ascending:false}),
    s.from("student_guardians").select("relationship,is_primary,guardians(name,mobile,alternate_mobile,address)").eq("student_id",studentId),
    s.from("attendance").select("status,marked_at,class_sessions(session_date,subjects(name))").eq("student_id",studentId).order("marked_at",{ascending:false}).limit(100),
    s.from("assessment_results").select("marks,remarks,assessments(title,total_marks,held_on,subjects(name))").eq("student_id",studentId).limit(100),
    s.from("payments").select("receipt_no,amount,payment_date,method,status").eq("student_id",studentId).order("payment_date",{ascending:false}).limit(100)
   ]);
   body=studentQ.data?<StudentProfile student={studentQ.data} enrollments={enrollmentsQ.data??[]} guardians={guardiansQ.data??[]} attendance={attendanceQ.data??[]} results={resultsQ.data??[]} payments={paymentsQ.data??[]}/>:<Card><CardContent className="p-6">Student not found.</CardContent></Card>;
  }else{
   const {data}=await s.from("students").select("id,student_no,name,status,school_name,enrollments(class_id,batch_id,monthly_fee,discount)").order("created_at",{ascending:false}).limit(200);
   body=<StudentDirectory rows={(data??[]).map(x=>({id:x.id,student_no:x.student_no,name:x.name,school:x.school_name??"—",status:x.status}))}/>;
  }
 } else if(section==="guardians"){
  const {data}=await s.from("guardians").select("id,name,mobile,alternate_mobile,address").order("created_at",{ascending:false}).limit(200);
  body=<Table title="Guardians" headers={["Name","Mobile","Alternate","Address"]} rows={(data??[]).map(x=>[x.name,x.mobile,x.alternate_mobile??"—",x.address??"—"])}/>;
 } else if(section==="attendance"){
  const [sessionsQ,enrollmentsQ,attendanceQ,approvalsQ]=await Promise.all([
   s.from("class_sessions").select("id,batch_id,session_date,starts_at,ends_at,subjects(name)").order("session_date",{ascending:false}).limit(100),
   s.from("enrollments").select("student_id,batch_id,students(id,student_no,name)").eq("is_active",true),
   s.from("attendance").select("session_id,student_id,status,remarks").order("marked_at",{ascending:false}).limit(1000),
   s.from("approval_requests").select("id,entity_id,status,requested_by,requested_at,decision_note").eq("workflow_type","ATTENDANCE_FINALIZATION").eq("entity_type","CLASS_SESSION").order("requested_at",{ascending:false}).limit(500)
  ]);
  const attendanceBatches=batches.map(x=>({id:x.id,name:x.name}));
  const sessions=(sessionsQ.data??[]).map(x=>({id:x.id,batch_id:x.batch_id,session_date:x.session_date,starts_at:x.starts_at,ends_at:x.ends_at,subject_name:x.subjects?.name??null}));
  const attendanceStudents=(enrollmentsQ.data??[]).flatMap(x=>x.students?[{id:x.students.id,student_no:x.students.student_no,name:x.students.name,batch_id:x.batch_id}]:[]);
  body=<AttendanceManager batches={attendanceBatches} sessions={sessions} students={attendanceStudents} existing={attendanceQ.data??[]} approvals={approvalsQ.data??[]} role={user.role}/>;
 } else if(section==="teachers"){
  const {data}=await s.from("teachers").select("id,name,mobile,is_active").order("name");
  body=user.role==="ADMIN"?<TeacherManager teachers={data??[]}/>:<Table title="Teachers" headers={["Name","Mobile"]} rows={(data??[]).map(x=>[x.name,x.mobile??"—"])}/>;
 } else if(section==="fees"){
  const {data}=await s.from("fee_structures").select("id,title,amount,frequency").order("effective_from",{ascending:false});
  body=<FeeManager years={years} classes={classes} programs={programs} fees={data??[]}/>;
 } else if(section==="payments"){
  const [studentsQ,paymentsQ]=await Promise.all([s.from("students").select("id,student_no,name,enrollments(id)").eq("status","ACTIVE").order("name"),s.from("payments").select("id,receipt_no,amount,payment_date,students(name,student_no)").order("created_at",{ascending:false}).limit(100)]);
  body=<PaymentManager students={studentsQ.data??[]} payments={paymentsQ.data??[]}/>;
 } else if(section==="assessments"){
  const [assessmentsQ,enrollmentsQ,resultsQ,approvalsQ]=await Promise.all([
   s.from("assessments").select("id,title,batch_id,held_on,total_marks").order("held_on",{ascending:false}).limit(100),
   s.from("enrollments").select("student_id,batch_id,students(id,student_no,name)").eq("is_active",true),
   s.from("assessment_results").select("assessment_id,student_id,marks,remarks").limit(2000),
   s.from("approval_requests").select("id,entity_id,status,requested_by,requested_at,decision_note").eq("workflow_type","ASSESSMENT_RESULTS_FINALIZATION").eq("entity_type","ASSESSMENT").order("requested_at",{ascending:false}).limit(500)
  ]);
  const assessmentData=assessmentsQ.data??[];
  const resultStudents=(enrollmentsQ.data??[]).flatMap(x=>x.students?[{id:x.students.id,student_no:x.students.student_no,name:x.students.name,batch_id:x.batch_id}]:[]);
  body=<><AssessmentManager years={years} batches={batches} subjects={subjects} assessments={assessmentData}/><AssessmentResultsManager assessments={assessmentData} students={resultStudents} results={resultsQ.data??[]} approvals={approvalsQ.data??[]} role={user.role}/></>;
 } else if(section==="progress"){
  const [studentsQ,recordsQ]=await Promise.all([
   s.from("students").select("id,student_no,name").eq("status","ACTIVE").order("name"),
   s.from("weekly_monitoring").select("id,student_id,week_start,homework_score,participation_score,test_score,remarks,students(name,student_no)").order("week_start",{ascending:false}).limit(300)
  ]);
  body=<ProgressManager students={studentsQ.data??[]} records={recordsQ.data??[]}/>;
 } else if(section==="parents"){
  const [studentsQ,recordsQ]=await Promise.all([
   s.from("students").select("id,student_no,name").eq("status","ACTIVE").order("name"),
   s.from("parent_communications").select("id,student_id,communication_type,occurred_at,notes,next_follow_up,students(name,student_no),guardians(name)").order("occurred_at",{ascending:false}).limit(300)
  ]);
  body=<ParentCommunicationManager students={studentsQ.data??[]} records={recordsQ.data??[]}/>;
 } else if(section==="notices"){
  const {data}=await s.from("notices").select("id,title,audience,published_at").order("created_at",{ascending:false}).limit(100);
  body=<NoticeManager notices={data??[]}/>;
 } else {
  body=<Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><p className="text-muted-foreground">This workflow is being connected to the live academy records.</p></CardContent></Card>;
 }
 return <SidebarProvider><AppSidebar user={user}/><SidebarInset><header className="flex min-h-16 items-center gap-3 border-b px-4 py-2"><SidebarTrigger/><Separator orientation="vertical" className="h-4"/><DashboardHeader section={section}/></header><main className="flex-1 space-y-6 p-4 md:p-6">{body}</main></SidebarInset></SidebarProvider>;
}

function StudentDirectory({rows}:{rows:{id:string;student_no:string;name:string;school:string;status:string}[]}){return <Card><CardHeader><CardTitle>Student Master</CardTitle></CardHeader><CardContent><div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left"><th className="p-3">ID</th><th className="p-3">Student</th><th className="p-3">School</th><th className="p-3">Status</th></tr></thead><tbody>{rows.map(r=><tr key={r.id} className="border-b"><td className="p-3"><Link className="font-medium underline-offset-4 hover:underline" href={"/dashboard/students/"+r.id}>{r.student_no}</Link></td><td className="p-3"><Link className="font-medium underline-offset-4 hover:underline" href={"/dashboard/students/"+r.id}>{r.name}</Link></td><td className="p-3">{r.school}</td><td className="p-3">{r.status}</td></tr>)}</tbody></table>{!rows.length&&<p className="py-8 text-center text-muted-foreground">No records yet.</p>}</div></CardContent></Card>}

function Table({title,headers,rows}:{title:string;headers:string[];rows:(string|number)[][]}){return <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left">{headers.map(h=><th key={h} className="p-3">{h}</th>)}</tr></thead><tbody>{rows.map((r,i)=><tr key={i} className="border-b">{r.map((v,j)=><td key={j} className="p-3">{v}</td>)}</tr>)}</tbody></table>{!rows.length&&<p className="py-8 text-center text-muted-foreground">No records yet.</p>}</div></CardContent></Card>}
