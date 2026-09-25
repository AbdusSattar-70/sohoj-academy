import { AppSidebar } from "@/components/dashboard/app-sidebar";
import { AdmissionForm } from "@/components/dashboard/admission-form";
import { SettingsManager } from "@/components/dashboard/settings-manager";
import { AssessmentManager, FeeManager, NoticeManager, PaymentManager, TeacherManager } from "@/components/dashboard/operation-managers";
import { AttendanceManager } from "@/components/dashboard/attendance-manager";
import { AssessmentResultsManager } from "@/components/dashboard/assessment-results-manager";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { createClient } from "@/lib/supabase/server";
import type { User } from "@/types/user";

const modules:Record<string,string>={admissions:"Admission Entry",students:"Student Master",guardians:"Guardians",attendance:"Attendance",assessments:"Assessments & Results",progress:"Progress Reports",fees:"Fee Structure",payments:"Fee Collection",parents:"Parent Communication",notices:"Notices",teachers:"Teachers",routine:"Routine",print:"Print Center",settings:"Settings",audit:"Audit & Recovery"};

export default async function DashboardContent({user,section="dashboard"}:{user:User;section?:string}){
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
  const stats=[["Active Students",studentCount.count??0],["Attendance Marked Today",todayAttendance.count??0],["Fees Collected",`৳${total.toLocaleString()}`],["Upcoming Tests",testCount.count??0]];
  body=<><div><h1 className="text-2xl font-bold">Digital Campus</h1><p className="text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p></div><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{stats.map(([a,b])=><Card key={a}><CardHeader className="pb-2"><CardTitle className="text-sm">{a}</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">{b}</div></CardContent></Card>)}</div><Card><CardHeader><CardTitle>Operations</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-3">{Object.entries(modules).map(([k,v])=><a key={k} href={"/dashboard/"+k} className="rounded-lg border p-4 hover:bg-muted"><p className="font-medium">{v}</p><p className="text-sm text-muted-foreground">Open module</p></a>)}</CardContent></Card></>;
 } else if(section==="admissions"&&(user.role==="ADMIN"||user.role==="OPERATOR")){
  body=<Card><CardHeader><CardTitle>New Student Admission</CardTitle></CardHeader><CardContent><AdmissionForm academicYears={years} classes={classes} programs={programs} batches={batches}/></CardContent></Card>;
 } else if(section==="settings"&&user.role==="ADMIN"){
  body=<SettingsManager years={years} classes={classes} programs={programs} subjects={subjects} batches={batches}/>;
 } else if(section==="students"){
  const {data}=await s.from("students").select("id,student_no,name,status,school_name,enrollments(class_id,batch_id,monthly_fee,discount)").order("created_at",{ascending:false}).limit(200);
  body=<Table title="Student Master" headers={["ID","Student","School","Status"]} rows={(data??[]).map(x=>[x.student_no,x.name,x.school_name??"—",x.status])}/>;
 } else if(section==="guardians"){
  const {data}=await s.from("guardians").select("id,name,mobile,alternate_mobile,address").order("created_at",{ascending:false}).limit(200);
  body=<Table title="Guardians" headers={["Name","Mobile","Alternate","Address"]} rows={(data??[]).map(x=>[x.name,x.mobile,x.alternate_mobile??"—",x.address??"—"])}/>;
 } else if(section==="attendance"){
  const [sessionsQ,enrollmentsQ,attendanceQ]=await Promise.all([
   s.from("class_sessions").select("id,batch_id,session_date,starts_at,ends_at,subjects(name)").order("session_date",{ascending:false}).limit(100),
   s.from("enrollments").select("student_id,batch_id,students(id,student_no,name)").eq("is_active",true),
   s.from("attendance").select("session_id,student_id,status,remarks").order("marked_at",{ascending:false}).limit(1000)
  ]);
  const attendanceBatches=batches.map(x=>({id:x.id,name:x.name}));
  const sessions=(sessionsQ.data??[]).map(x=>({id:x.id,batch_id:x.batch_id,session_date:x.session_date,starts_at:x.starts_at,ends_at:x.ends_at,subject_name:x.subjects?.name??null}));
  const attendanceStudents=(enrollmentsQ.data??[]).flatMap(x=>x.students?[{id:x.students.id,student_no:x.students.student_no,name:x.students.name,batch_id:x.batch_id}]:[]);
  body=<AttendanceManager batches={attendanceBatches} sessions={sessions} students={attendanceStudents} existing={attendanceQ.data??[]}/>;
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
  const [assessmentsQ,enrollmentsQ,resultsQ]=await Promise.all([
   s.from("assessments").select("id,title,batch_id,held_on,total_marks").order("held_on",{ascending:false}).limit(100),
   s.from("enrollments").select("student_id,batch_id,students(id,student_no,name)").eq("is_active",true),
   s.from("assessment_results").select("assessment_id,student_id,marks,remarks").limit(2000)
  ]);
  const assessmentData=assessmentsQ.data??[];
  const resultStudents=(enrollmentsQ.data??[]).flatMap(x=>x.students?[{id:x.students.id,student_no:x.students.student_no,name:x.students.name,batch_id:x.batch_id}]:[]);
  body=<><AssessmentManager years={years} batches={batches} subjects={subjects} assessments={assessmentData}/><AssessmentResultsManager assessments={assessmentData} students={resultStudents} results={resultsQ.data??[]}/></>;
 } else if(section==="notices"){
  const {data}=await s.from("notices").select("id,title,audience,published_at").order("created_at",{ascending:false}).limit(100);
  body=<NoticeManager notices={data??[]}/>;
 } else {
  body=<Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><p className="text-muted-foreground">This workflow is being connected to the live academy records.</p></CardContent></Card>;
 }
 return <SidebarProvider><AppSidebar user={user}/><SidebarInset><header className="flex h-16 items-center gap-3 border-b px-4"><SidebarTrigger/><Separator orientation="vertical" className="h-4"/><div><p className="font-semibold">{title}</p><p className="text-xs text-muted-foreground">Sohoj Academy Digital Campus</p></div></header><main className="flex-1 space-y-6 p-4 md:p-6">{body}</main></SidebarInset></SidebarProvider>;
}

function Table({title,headers,rows}:{title:string;headers:string[];rows:(string|number)[][]}){return <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr className="border-b text-left">{headers.map(h=><th key={h} className="p-3">{h}</th>)}</tr></thead><tbody>{rows.map((r,i)=><tr key={i} className="border-b">{r.map((v,j)=><td key={j} className="p-3">{v}</td>)}</tr>)}</tbody></table>{!rows.length&&<p className="py-8 text-center text-muted-foreground">No records yet.</p>}</div></CardContent></Card>}
