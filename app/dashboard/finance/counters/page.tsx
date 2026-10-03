import {redirect} from "next/navigation";
import {requireErpContext} from "@/modules/platform/auth/erp-context";
import {getCounters} from "@/modules/finance/counters/queries";
import {CounterRegister} from "@/modules/finance/counters/register";
import {LocalizedText} from "@/components/shared/localized-text";
export default async function Counters({searchParams}:{searchParams:Promise<{page?:string;close?:string}>}){const ctx=await requireErpContext();if(!ctx.permissions.some(p=>["accounting.reconcile","workforce.self.view"].includes(p)))redirect("/dashboard?access=denied");const q=await searchParams;const page=Math.max(1,Math.min(10000,parseInt(q.page??"1",10)||1));return <div className="space-y-6"><h1 className="text-2xl font-semibold"><LocalizedText en="Cash counters & opening float" bn="নগদ কাউন্টার ও প্রারম্ভিক তহবিল"/></h1><CounterRegister data={await getCounters(page)} page={page} resumeCloseId={q.close}/></div>;}
