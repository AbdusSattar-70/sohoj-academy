import { AppSidebar } from "@/components/dashboard/app-sidebar";
import { AdmissionForm } from "@/components/dashboard/admission-form";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { createClient } from "@/lib/supabase/server";
import type { User } from "@/types/user";

const modules: Record<string, string> = {
  admissions: "Admission Entry", students: "Student Master", guardians: "Guardians",
  attendance: "Attendance", assessments: "Assessments & Results", progress: "Progress Reports",
  fees: "Fee Structure", payments: "Fee Collection", parents: "Parent Communication",
  notices: "Notices", teachers: "Teachers", routine: "Routine", print: "Print Center",
  settings: "Settings", audit: "Audit & Recovery",
};

export default async function DashboardContent({ user, section = "dashboard" }: { user: User; section?: string }) {
  const title = section === "dashboard" ? "Dashboard" : modules[section] ?? "Dashboard";
  let admissionData: null | {
    academicYears: { id: string; name: string }[];
    classes: { id: string; name: string }[];
    programs: { id: string; name: string }[];
    batches: { id: string; name: string; class_id: string; program_id: string | null; academic_year_id: string }[];
  } = null;

  if (section === "admissions" && ["ADMIN", "OPERATOR"].includes(user.role)) {
    const supabase = await createClient();
    const [years, classes, programs, batches] = await Promise.all([
      supabase.from("academic_years").select("id,name").order("starts_on", { ascending: false }),
      supabase.from("classes").select("id,name").order("sort_order"),
      supabase.from("programs").select("id,name").eq("is_active", true).order("name"),
      supabase.from("batches").select("id,name,class_id,program_id,academic_year_id").eq("is_active", true).order("name"),
    ]);
    admissionData = {
      academicYears: years.data ?? [], classes: classes.data ?? [], programs: programs.data ?? [], batches: batches.data ?? [],
    };
  }

  return (
    <SidebarProvider>
      <AppSidebar user={user} />
      <SidebarInset>
        <header className="flex h-16 items-center gap-3 border-b px-4">
          <SidebarTrigger /><Separator orientation="vertical" className="h-4" />
          <div><p className="font-semibold">{title}</p><p className="text-xs text-muted-foreground">Sohoj Academy Digital Campus</p></div>
        </header>
        <main className="flex-1 space-y-6 p-4 md:p-6">
          {section === "dashboard" ? (
            <>
              <div><h1 className="text-2xl font-bold">Digital Campus</h1><p className="text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p></div>
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {["Active Students", "Today's Attendance", "Fees Collected", "Upcoming Tests"].map((label) => (
                  <Card key={label}><CardHeader className="pb-2"><CardTitle className="text-sm">{label}</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">—</div><p className="text-xs text-muted-foreground">Live data coming from operations</p></CardContent></Card>
                ))}
              </div>
              <Card><CardHeader><CardTitle>Operations</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-3">
                {Object.entries(modules).map(([key, label]) => <a key={key} href={"/dashboard/" + key} className="rounded-lg border p-4 hover:bg-muted"><p className="font-medium">{label}</p><p className="text-sm text-muted-foreground">Open module</p></a>)}
              </CardContent></Card>
            </>
          ) : section === "admissions" ? (
            user.role === "ADMIN" || user.role === "OPERATOR" ? (
              <Card><CardHeader><CardTitle>New Student Admission</CardTitle></CardHeader><CardContent>
                {admissionData ? <AdmissionForm {...admissionData} /> : <p>Could not load admission settings.</p>}
              </CardContent></Card>
            ) : <Card><CardContent className="pt-6">You do not have permission to create admissions.</CardContent></Card>
          ) : (
            <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><p className="text-muted-foreground">This module is connected to the academy domain and will use live Supabase records.</p></CardContent></Card>
          )}
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
