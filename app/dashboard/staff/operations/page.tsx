import {PageHeader} from "@/components/erp/page-header";
import {LocalizedText} from "@/components/shared/localized-text";
import {requirePermission} from "@/modules/platform/auth/erp-context";
import {getWorkData} from "@/modules/workforce/queries";
import {WorkWorkspace} from "@/modules/workforce/workspace";
import {workforceQuery} from "@/modules/workforce/route-query";
export default async function StaffOperations({searchParams}:{searchParams:Promise<{month?:string;person?:string;page?:string}>}){await requirePermission("workforce.manage");const q=workforceQuery(await searchParams);const data=await getWorkData(q.month,q.person,q.page);return <div className="space-y-6"><PageHeader eyebrow={<LocalizedText en="People" bn="ব্যক্তিবর্গ"/>} title={<LocalizedText en="Staff attendance & compensation terms" bn="স্টাফ উপস্থিতি ও পারিশ্রমিকের শর্ত"/>} description={<LocalizedText en="Record actual daily evidence. Corrections are audited; no staff record is deleted." bn="প্রকৃত দৈনিক তথ্য রেকর্ড করুন। সংশোধন অডিটে থাকে; স্টাফ রেকর্ড মুছে ফেলা হয় না।"/>}/><WorkWorkspace data={data} page={q.page} admin/></div>;}
