import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getWebsiteOfferings } from "@/modules/offerings/queries";
import { WebsiteWorkspace } from "@/modules/crm/website/workspace";
export default async function WebsiteManagementPage() {
  await requirePermission("academics.manage");
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={<LocalizedText en="Website & CRM" bn="ওয়েবসাইট ও CRM" />}
        title={<LocalizedText en="Website management" bn="ওয়েবসাইট পরিচালনা" />}
        description={
          <LocalizedText
            en="Edit programme showcase copy, visibility and application intake. Academic list creation belongs in Academic settings."
            bn="প্রোগ্রামের প্রকাশ্য তথ্য, দৃশ্যমানতা ও আবেদন গ্রহণ সম্পাদনা করুন। শিক্ষা তালিকা তৈরি Academic settings-এর কাজ।"
          />
        }
      />
      <WebsiteWorkspace data={await getWebsiteOfferings()} />
    </div>
  );
}
