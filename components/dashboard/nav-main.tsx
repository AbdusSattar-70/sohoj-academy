"use client";
import { BookOpenCheck, CalendarDays, ChevronRight, CircleDollarSign, GraduationCap, LayoutDashboard, Settings2, Users } from "lucide-react";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { SidebarGroup, SidebarGroupLabel, SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarMenuSub, SidebarMenuSubButton, SidebarMenuSubItem } from "@/components/ui/sidebar";

const groups = [
  { title: "Dashboard", url: "/dashboard", icon: LayoutDashboard, items: [] },
  { title: "Academic", icon: GraduationCap, items: [["Admissions","/dashboard/admissions"],["Students","/dashboard/students"],["Guardians","/dashboard/guardians"],["Attendance","/dashboard/attendance"],["Assessments","/dashboard/assessments"],["Progress","/dashboard/progress"]] },
  { title: "Finance", icon: CircleDollarSign, items: [["Fees","/dashboard/fees"],["Payments","/dashboard/payments"]] },
  { title: "Communication", icon: Users, items: [["Parents","/dashboard/parents"],["Notices","/dashboard/notices"]] },
  { title: "Management", icon: CalendarDays, items: [["Teachers","/dashboard/teachers"],["Routine","/dashboard/routine"]] },
  { title: "System", icon: Settings2, items: [["Print Center","/dashboard/print"],["Settings","/dashboard/settings"],["Audit & Recovery","/dashboard/audit"]] },
];

export function NavMain() {
  return <SidebarGroup><SidebarGroupLabel>Sohoj Academy</SidebarGroupLabel><SidebarMenu>
    {groups.map((item) => item.items.length === 0 ? (
      <SidebarMenuItem key={item.title}><SidebarMenuButton asChild tooltip={item.title}><a href={item.url}><item.icon /><span>{item.title}</span></a></SidebarMenuButton></SidebarMenuItem>
    ) : (
      <Collapsible key={item.title} asChild defaultOpen className="group/collapsible"><SidebarMenuItem>
        <CollapsibleTrigger asChild><SidebarMenuButton tooltip={item.title}><item.icon /><span>{item.title}</span><ChevronRight className="ml-auto transition-transform group-data-[state=open]/collapsible:rotate-90" /></SidebarMenuButton></CollapsibleTrigger>
        <CollapsibleContent><SidebarMenuSub>{item.items.map(([title,url]) => <SidebarMenuSubItem key={url}><SidebarMenuSubButton asChild><a href={url}><span>{title}</span></a></SidebarMenuSubButton></SidebarMenuSubItem>)}</SidebarMenuSub></CollapsibleContent>
      </SidebarMenuItem></Collapsible>
    ))}
  </SidebarMenu></SidebarGroup>;
}
