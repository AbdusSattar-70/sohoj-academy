import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getRecurringExpenses} from "@/modules/finance/recurring/queries";
import {RecurringRegister} from "@/modules/finance/recurring/register";
export default async function RecurringExpenses({searchParams}:{searchParams:Promise<{month?:string;page?:string}>}){await requirePermission("accounting.expense.manage");const q=await searchParams,page=Math.min(10000,Math.max(1,parseInt(q.page??"1")||1));const month=/^\d{4}-(0[1-9]|1[0-2])$/.test(q.month??"")?`${q.month}-01`:undefined;return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Recurring expenses" description="Monthly rent, utilities and agreed expenses. Prepare drafts, verify actual bills, then post and settle."/><RecurringRegister data={await getRecurringExpenses(month,page)} page={page}/></div>;}
