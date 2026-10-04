import {requireErpContext} from "@/modules/platform/auth/erp-context";
import {redirect} from "next/navigation";
import {PageHeader} from "@/components/erp/page-header";
import {getAssets} from "@/modules/finance/assets/queries";
import {AssetsRegister} from "@/modules/finance/assets/register";
export default async function Assets({searchParams}:{searchParams:Promise<{page?:string;status?:string;q?:string}>}){const c=await requireErpContext();if(!c.permissions.some(p=>["assets.manage","workforce.self.view"].includes(p)))redirect("/dashboard");const q=await searchParams;const page=Math.min(100000,Math.max(1,parseInt(q.page??"1")||1));const status=["DRAFT","ACTIVE","INACTIVE","DISPOSED","CANCELLED"].includes(q.status??"")?q.status!:"ALL";const search=(q.q??"").slice(0,100);return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Assets & custody" description="Capitalized equipment, custody acknowledgements, monthly depreciation and recorded disposal. Staff see their own assigned assets."/><AssetsRegister data={await getAssets(page,status,search)} status={status} search={search}/></div>;}
