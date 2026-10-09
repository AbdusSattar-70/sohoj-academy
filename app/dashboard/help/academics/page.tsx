import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { WorkflowSteps } from "@/modules/help/workflow-guide";
import { setupSteps } from "@/modules/help/setup-steps";
import { dailySteps } from "@/modules/help/daily-steps";
export default async function AcademicHelpPage() {
  const context = await requirePermission("academics.view");
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={
          <LocalizedText
            en="Academic workflow"
            bn="শিক্ষা কার্যক্রমের নির্দেশিকা"
          />
        }
        title={
          <LocalizedText
            en="Assign a teacher and run a class"
            bn="শিক্ষককে ক্লাস দিন ও কার্যক্রম সম্পন্ন করুন"
          />
        }
        description={
          <LocalizedText
            en="An availability window permits scheduling; a routine books resources; a dated session records actual teaching. Student attendance, staff presence and teaching hours are separate."
            bn="Availability-তে সময় দেওয়া যায়; routine-এ বরাদ্দ হয়; dated session-এ actual কাজ record হয়। Student attendance, staff উপস্থিতি ও teaching hours আলাদা।"
          />
        }
      />
      <section className="space-y-3">
        <h2 className="text-xl font-semibold">
          <LocalizedText
            en="Prepare and schedule"
            bn="প্রস্তুতি ও scheduling"
          />
        </h2>
        <WorkflowSteps
          steps={setupSteps.slice(0, 6)}
          permissions={context.permissions}
        />
      </section>
      <section className="space-y-3">
        <h2 className="text-xl font-semibold">
          <LocalizedText
            en="Teach, submit and review"
            bn="পাঠদান, submission ও review"
          />
        </h2>
        <WorkflowSteps
          steps={dailySteps.slice(0, 5)}
          permissions={context.permissions}
        />
      </section>
      <aside className="space-y-2 rounded-xl border p-4">
        <h2 className="font-semibold">
          <LocalizedText
            en="Scheduling notices and changed classes"
            bn="সময়সূচির সতর্কতা ও ক্লাস পরিবর্তন"
          />
        </h2>
        <p className="leading-7">
          <LocalizedText
            en="Check the selected teacher, teaching subject, weekday, Bangladesh time and effective date. Saved availability represents preferred hours and only warns. Real room/teacher unavailability and existing bookings still prevent scheduling. Existing room, teacher and batch bookings are also checked. Keep your input and correct the conflicting field."
            bn="নির্বাচিত শিক্ষক, বিষয়, দিন, বাংলাদেশ সময় ও effective date যাচাই করুন। সংরক্ষিত availability পছন্দের সময় হিসেবে শুধু সতর্ক করে। বাস্তব কক্ষ/শিক্ষকের বন্ধ সময় এবং আগের booking ক্লাস তৈরিতে বাধা থাকবে। শিক্ষক, কক্ষ ও ব্যাচের booking-ও যাচাই হয়। Input রেখে conflict সংশোধন করুন।"
          />
        </p>
        <p className="leading-7">
          <LocalizedText
            en="Use the dated session’s action for a substitute, room change, reschedule, cancellation or linked makeup. It changes that class, not the entire routine. Two planned hours with 1.5 approved actual hours counts as 1.5 teaching hours; cancelled classes do not count."
            bn="Substitute, room change, reschedule, cancel বা linked makeup ওই dated session-এর action থেকে করুন। পুরো routine বদলাবে না। Planned ২ ঘণ্টা, approved actual ১.৫ ঘণ্টা হলে teaching hours ১.৫; cancelled class গণনা হবে না।"
          />
        </p>
      </aside>
    </div>
  );
}
