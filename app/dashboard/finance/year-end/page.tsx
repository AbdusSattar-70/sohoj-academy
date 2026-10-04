import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getYearEnd} from "@/modules/finance/year-end/queries";
import {YearEndRegister} from "@/modules/finance/year-end/register";
export default async function YearEnd({searchParams}:{searchParams:Promise<{start?:string}>}){await requirePermission("accounting.view");const q=await searchParams,start=/^\d{4}-(0[1-9]|1[0-2])$/.test(q.start??"")?`${q.start}-01`:`${new Date().getUTCFullYear()-1}-01-01`;return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Financial year closing" description="Review twelve months, transfer the result and preserve reversal history."/><YearEndRegister data={await getYearEnd(start)}/></div>;}
