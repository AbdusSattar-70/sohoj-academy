import Link from "next/link";
import {LocalizedText} from "@/components/shared/localized-text";
import {PageHeader} from "@/components/erp/page-header";
import {requirePermission} from "@/modules/platform/auth/erp-context";
import {getWorkData} from "@/modules/workforce/queries";
import {WorkWorkspace} from "@/modules/workforce/workspace";
import {workforceQuery} from "@/modules/workforce/route-query";
export default async function MyWorkPage({searchParams}:{searchParams:Promise<{month?:string;page?:string}>}){const context=await requirePermission("workforce.self.view");const q=workforceQuery(await searchParams);const data=await getWorkData(q.month,undefined,q.page);return <div className="space-y-6"><PageHeader eyebrow={<LocalizedText en="My workspace" bn="আমার কর্মক্ষেত্র"/>} title={<LocalizedText en="My work & attendance" bn="আমার কাজ ও উপস্থিতি"/>} description={<LocalizedText en="Your recorded attendance, agreed terms and links to your approved financial statement." bn="আপনার উপস্থিতি, পারিশ্রমিকের শর্ত ও অনুমোদিত আর্থিক হিসাব।"/>}/>{context.roles.includes("TEACHER")&&<Link className="inline-block rounded-lg border p-3" href="/dashboard/teacher"><LocalizedText en="My classes → record student attendance" bn="আমার ক্লাস → শিক্ষার্থীদের উপস্থিতি নিন"/></Link>}<WorkWorkspace data={data} page={q.page}/></div>;}
