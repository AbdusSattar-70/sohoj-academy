import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getPlanning} from "@/modules/finance/planning/queries";
import {PlanningRegister} from "@/modules/finance/planning/register";
export default async function Planning({searchParams}:{searchParams:Promise<{month?:string;page?:string}>}){await requirePermission("accounting.view");const q=await searchParams,page=Math.min(10000,Math.max(1,parseInt(q.page??"1")||1)),month=/^\d{4}-(0[1-9]|1[0-2])$/.test(q.month??"")?`${q.month}-01`:undefined;return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Budgets & programme contribution" description="Agreed budgets, evidenced income/expense allocation and clearly labelled cash scenarios."/><PlanningRegister data={await getPlanning(month,page)} page={page}/></div>;}
