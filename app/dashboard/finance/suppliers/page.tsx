import {z} from "zod";
import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getSupplierStatement} from "@/modules/finance/suppliers/queries";
import {SupplierRegister} from "@/modules/finance/suppliers/register";
export default async function Suppliers({searchParams}:{searchParams:Promise<{vendor?:string;q?:string;page?:string}>}){await requirePermission("accounting.view");const p=await searchParams,id=z.string().uuid().safeParse(p.vendor),q=(p.q??"").slice(0,100),page=Math.min(10000,Math.max(1,parseInt(p.page??"1")||1));return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Supplier accounts" description="Payable balances, settlement and separate supplier assets."/><SupplierRegister data={await getSupplierStatement(id.success?id.data:undefined,q,page)} page={page} q={q}/></div>;}
