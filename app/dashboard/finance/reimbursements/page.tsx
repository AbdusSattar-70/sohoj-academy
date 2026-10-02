import {requireErpContext} from "@/modules/platform/auth/erp-context";
import {redirect} from "next/navigation";
import {PageHeader} from "@/components/erp/page-header";
import {getClaims} from "@/modules/finance/reimbursements/queries";
import {ClaimsRegister} from "@/modules/finance/reimbursements/register";
export default async function Reimbursements({searchParams}:{searchParams:Promise<{page?:string;status?:string}>}){const context=await requireErpContext();if(!context.permissions.some(p=>["accounting.expense.manage","workforce.self.view"].includes(p)))redirect("/dashboard");const q=await searchParams;const status=["DRAFT","SUBMITTED","POSTED","CANCELLED"].includes(q.status??"")?q.status!:"ALL";const page=Math.min(100000,Math.max(1,parseInt(q.page??"1")||1));return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Staff expense claims" description="Personal funds only. Draft → receipt evidence → submit → finance verifies and posts → actual reimbursement."/><ClaimsRegister data={await getClaims(page,status)} status={status}/></div>;}
