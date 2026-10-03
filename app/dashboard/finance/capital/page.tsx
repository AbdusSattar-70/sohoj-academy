import {z} from "zod";
import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getCapital} from "@/modules/finance/capital/queries";
import {CapitalRegister} from "@/modules/finance/capital/register";
export default async function Capital({searchParams}:{searchParams:Promise<{page?:string;owner?:string}>}){await requirePermission("accounting.reconcile");const q=await searchParams,page=Math.min(10000,Math.max(1,parseInt(q.page??"1")||1)),owner=z.string().uuid().safeParse(q.owner).success?q.owner:undefined;return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Owner capital & funding" description="Actual contributed funds and capital returns with balanced equity accounting."/><CapitalRegister data={await getCapital(page,owner)} page={page} ownerId={owner}/></div>;}
