import {z} from "zod";
import {requirePermission} from "@/modules/platform/auth/erp-context";
import {PageHeader} from "@/components/erp/page-header";
import {getBankData} from "@/modules/finance/bank/queries";
import {BankRegister} from "@/modules/finance/bank/register";
export default async function BankReconciliation({searchParams}:{searchParams:Promise<{account?:string;page?:string;q?:string;view?:string}>}){await requirePermission("accounting.reconcile");const q=await searchParams,page=Math.min(10000,Math.max(1,parseInt(q.page??"1")||1)),account=z.string().uuid().safeParse(q.account).success?q.account:undefined,search=(q.q??"").slice(0,100),unmatched=q.view!=="all";return <div className="space-y-5"><PageHeader eyebrow="Finance" title="Bank statements & matching" description="Import verified external transactions and match exact posted account movements without changing ledger balances."/><BankRegister data={await getBankData(account,page,search,unmatched)} page={page} accountId={account} search={search} unmatched={unmatched}/></div>;}
