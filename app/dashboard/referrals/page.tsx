import { z } from "zod";
import { requireErpContext } from "@/modules/platform/auth/erp-context";
import { PageHeader } from "@/components/erp/page-header";
import { getReferrerWorkspace } from "@/modules/referrals/queries";
import { ReferrerRegister } from "@/modules/referrals/register";
export default async function Referrals({searchParams}:{searchParams:Promise<{person?:string}>}){
 await requireErpContext();const {person}=await searchParams;const id=person&&z.string().uuid().safeParse(person).success?person:undefined;
 const data=await getReferrerWorkspace(id);
 return <div className="space-y-6"><PageHeader eyebrow="Referral partnerships" title={data.manager?"Referrers":"My referred students"} description="Tuition collection, discounts and acquisition rewards. Only actual net collected tuition earns a reward; refunds and corrections adjust entitlement."/><ReferrerRegister data={data}/></div>;
}
