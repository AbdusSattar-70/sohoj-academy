import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getStock} from "@/modules/finance/stock/queries";
import {StockRegister} from "@/modules/finance/stock/register";
export default async function Stock({searchParams}:{searchParams:Promise<{q?:string;page?:string}>}){await requirePermission("accounting.view");const p=await searchParams,q=(p.q??"").slice(0,100),page=Math.min(10000,Math.max(1,parseInt(p.page??"1")||1));return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Consumable stock" description="Actual receipts, usage and count differences with immutable history."/><StockRegister data={await getStock(page,q)} page={page} q={q}/></div>;}
