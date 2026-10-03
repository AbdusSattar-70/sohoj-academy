import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getCashFlow} from "@/modules/finance/cash-flow/queries";
import {CashFlowRegister} from "@/modules/finance/cash-flow/register";
export default async function CashFlow({searchParams}:{searchParams:Promise<{month?:string;page?:string}>}){await requirePermission("accounting.view");const q=await searchParams,page=Math.min(10000,Math.max(1,parseInt(q.page??"1")||1)),month=/^\d{4}-(0[1-9]|1[0-2])$/.test(q.month??"")?`${q.month}-01`:undefined;return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Cash flow" description="Operating, investing and financing cash movements with unclassified items kept visible."/><CashFlowRegister data={await getCashFlow(month,page)} page={page}/></div>;}
