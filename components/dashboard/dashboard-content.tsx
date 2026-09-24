import { AppSidebar } from "@/components/dashboard/app-sidebar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import type { User } from "@/types/user";

const modules: Record<string, string> = {
  admissions: "Admission Entry",
  students: "Student Master",
  guardians: "Guardians",
  attendance: "Attendance",
  assessments: "Assessments & Results",
  progress: "Progress Reports",
  fees: "Fee Structure",
  payments: "Fee Collection",
  parents: "Parent Communication",
  notices: "Notices",
  teachers: "Teachers",
  routine: "Routine",
  print: "Print Center",
  settings: "Settings",
  audit: "Audit & Recovery",
};

export default function DashboardContent({ user, section = "dashboard" }: { user: User; section?: string }) {
  const title = section === "dashboard" ? "Dashboard" : modules[section] ?? "Dashboard";
  return (
    <SidebarProvider>
      <AppSidebar user={user} />
      <SidebarInset>
        <header className="flex h-16 items-center gap-3 border-b px-4">
          <SidebarTrigger />
          <Separator orientation="vertical" className="h-4" />
          <div><p className="font-semibold">{title}</p><p className="text-xs text-muted-foreground">Sohoj Academy Digital Campus</p></div>
        </header>
        <main className="flex-1 space-y-6 p-4 md:p-6">
          {section === "dashboard" ? (
            <>
              <div><h1 className="text-2xl font-bold">Digital Campus</h1><p className="text-muted-foreground">শিক্ষা হোক সহজ ও আনন্দময়</p></div>
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {["Active Students", "Today's Attendance", "Fees Collected", "Upcoming Tests"].map((label) => (
                  <Card key={label}><CardHeader className="pb-2"><CardTitle className="text-sm">{label}</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">—</div><p className="text-xs text-muted-foreground">Live after Supabase setup</p></CardContent></Card>
                ))}
              </div>
              <Card><CardHeader><CardTitle>Operations</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-3">
                {Object.entries(modules).map(([key, label]) => <a key={key} href={"/dashboard/" + key} className="rounded-lg border p-4 hover:bg-muted"><p className="font-medium">{label}</p><p className="text-sm text-muted-foreground">Open module</p></a>)}
              </CardContent></Card>
            </>
          ) : (
            <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent><p className="text-muted-foreground">This module is connected to the new academy domain and ready for its live Supabase workflow.</p></CardContent></Card>
          )}
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
