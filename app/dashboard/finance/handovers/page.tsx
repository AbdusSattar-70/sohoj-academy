import {requireErpContext} from "@/modules/platform/auth/erp-context";
import {LocalizedText} from "@/components/shared/localized-text";
import {redirect} from "next/navigation";
import {getHandovers} from "@/modules/finance/handovers/queries";
import {HandoverRegister} from "@/modules/finance/handovers/register";
export default async function Handovers({searchParams}:{searchParams:Promise<{page?:string}>}){const context=await requireErpContext();if(!context.permissions.some(p=>["accounting.reconcile","workforce.self.view"].includes(p)))redirect("/dashboard?access=denied");const q=await searchParams;const page=Math.max(1,Math.min(10000,parseInt(q.page??"1",10)||1));return <div className="space-y-6"><h1 className="text-2xl font-semibold"><LocalizedText en="Cash handover receipts" bn="নগদ হস্তান্তর গ্রহণের প্রমাণ"/></h1><HandoverRegister data={await getHandovers(page)} page={page}/></div>;}
