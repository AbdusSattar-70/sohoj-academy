import { createAcademicYear, createBatch, createClass, createProgram, createSubject } from "@/app/actions/operations";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

type Opt={id:string;name:string};

export function SettingsManager({years,classes,programs,subjects,batches}:{years:(Opt&{starts_on:string;ends_on:string;is_active:boolean})[];classes:(Opt&{sort_order:number})[];programs:(Opt&{code:string|null})[];subjects:(Opt&{code:string|null})[];batches:(Opt&{capacity:number})[]}) {
  return <div className="grid gap-6 xl:grid-cols-2">
    <Panel title="Academic Years" rows={years.map(x=>[x.name,`${x.starts_on} → ${x.ends_on}${x.is_active?" • Active":""}`])}>
      <form action={createAcademicYearAction} className="grid gap-2 sm:grid-cols-2"><Input name="name" placeholder="2026" required/><Input name="starts_on" type="date" required/><Input name="ends_on" type="date" required/><label className="flex items-center gap-2 text-sm"><input name="is_active" type="checkbox"/> Active year</label><Button className="sm:col-span-2">Add Academic Year</Button></form>
    </Panel>
    <Panel title="Classes" rows={classes.map(x=>[x.name,`Order ${x.sort_order}`])}>
      <form action={createClassAction} className="flex gap-2"><Input name="name" placeholder="Class 8" required/><Input name="sort_order" type="number" placeholder="8"/><Button>Add</Button></form>
    </Panel>
    <Panel title="Programs" rows={programs.map(x=>[x.name,x.code??"—"])}>
      <form action={createProgramAction} className="flex gap-2"><Input name="name" placeholder="SSC A+ Preparation" required/><Input name="code" placeholder="SSC-A+"/><Button>Add</Button></form>
    </Panel>
    <Panel title="Subjects" rows={subjects.map(x=>[x.name,x.code??"—"])}>
      <form action={createSubjectAction} className="flex gap-2"><Input name="name" placeholder="Mathematics" required/><Input name="code" placeholder="MATH"/><Button>Add</Button></form>
    </Panel>
    <Panel title="Batches" rows={batches.map(x=>[x.name,`Capacity ${x.capacity}`])}>
      <form action={createBatchAction} className="grid gap-2 sm:grid-cols-2">
        <Input name="name" placeholder="Class 8 - A" required/>
        <select name="academic_year_id" required className="h-9 rounded-md border bg-background px-3 text-sm"><option value="">Academic year</option>{years.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select>
        <select name="class_id" required className="h-9 rounded-md border bg-background px-3 text-sm"><option value="">Class</option>{classes.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select>
        <select name="program_id" className="h-9 rounded-md border bg-background px-3 text-sm"><option value="">Program (optional)</option>{programs.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select>
        <Input name="capacity" type="number" min="1" defaultValue="12"/>
        <Button>Add Batch</Button>
      </form>
    </Panel>
  </div>
}

function Panel({title,rows,children}:{title:string;rows:string[][];children:React.ReactNode}){
 return <section className="rounded-xl border bg-card p-5"><h2 className="mb-4 text-lg font-semibold">{title}</h2>{children}<div className="mt-4 divide-y">{rows.length?rows.map((r,i)=><div key={i} className="flex justify-between gap-3 py-2 text-sm"><span className="font-medium">{r[0]}</span><span className="text-muted-foreground">{r[1]}</span></div>):<p className="mt-4 text-sm text-muted-foreground">No records yet.</p>}</div></section>
}

async function createAcademicYearAction(fd: FormData) { "use server"; await createAcademicYear(fd); }
async function createClassAction(fd: FormData) { "use server"; await createClass(fd); }
async function createProgramAction(fd: FormData) { "use server"; await createProgram(fd); }
async function createSubjectAction(fd: FormData) { "use server"; await createSubject(fd); }
async function createBatchAction(fd: FormData) { "use server"; await createBatch(fd); }
