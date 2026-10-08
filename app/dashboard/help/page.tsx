import { PageHeader } from "@/components/erp/page-header";
import { LocalizedText } from "@/components/shared/localized-text";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { WorkflowSteps } from "@/modules/help/workflow-guide";
import { setupSteps } from "@/modules/help/setup-steps";
import { admissionSteps } from "@/modules/help/admission-steps";
import { dailySteps } from "@/modules/help/daily-steps";
export default async function HelpPage() {
  const context = await requirePermission("dashboard.view");
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={
          <LocalizedText en="Help & workflows" bn="সহায়তা ও কাজের ধাপ" />
        }
        title={
          <LocalizedText
            en="From first setup to daily work"
            bn="প্রথম প্রস্তুতি থেকে দৈনন্দিন কাজ"
          />
        }
        description={
          <LocalizedText
            en="Open the stage you need. Setup is occasional; admission is one case; daily teaching uses dated sessions. Links appear only for your permissions."
            bn="যে ধাপ প্রয়োজন সেটি খুলুন। Setup মাঝে মাঝে; ভর্তি একই case-এ; প্রতিদিনের পাঠদান তারিখভিত্তিক session-এ। অনুমতি অনুযায়ী link দেখাবে।"
          />
        }
      />
      <nav aria-label="Workflow sections" className="flex flex-wrap gap-2">
        {[
          ["setup", "Setup", "প্রথম প্রস্তুতি"],
          ["admission", "Admission", "ভর্তি"],
          ["daily", "Daily work", "দৈনন্দিন কাজ"],
        ].map(([id, en, bn]) => (
          <a
            key={id}
            href={"#" + id}
            className="inline-flex min-h-11 items-center rounded-lg border px-4 hover:bg-muted"
          >
            <LocalizedText en={en} bn={bn} />
          </a>
        ))}
      </nav>
      <aside className="space-y-2 rounded-xl border bg-muted/30 p-4">
        <h2 className="font-semibold">
          <LocalizedText en="Worked example" bn="একটি উদাহরণ" />
        </h2>
        <p className="leading-7">
          <LocalizedText
            en="SSC Coaching, Class 10 Science, Morning A, 12 seats, Sun/Tue/Thu 7–9 AM. Prepare the teacher, room and routine, generate classes, then admit students into the batch."
            bn="SSC Coaching, Class 10 Science, Morning A, ১২ আসন, রবি-মঙ্গল-বৃহস্পতি সকাল ৭–৯টা। শিক্ষক, কক্ষ ও routine প্রস্তুত করে dated class তৈরি করুন; তারপর ব্যাচে ভর্তি নিন।"
          />
        </p>
        <p className="leading-7">
          <LocalizedText
            en="BDT 3,000 tuition with an allowed 10% discount means BDT 2,700 tuition due. If BDT 2,000 is received, print its receipt; BDT 700 remains due, plus any separate one-time fees. Referral rewards are calculated from eligible net tuition collected, never from an unpaid invoice."
            bn="Tuition ৩,০০০ টাকায় অনুমোদিত ১০% discount হলে tuition due ২,৭০০। ২,০০০ টাকা পেলে সেই টাকার receipt দিন; ৭০০ টাকা বাকি, সঙ্গে পৃথক এককালীন fee থাকলে তা যোগ হবে। Referrer reward unpaid invoice থেকে নয়, প্রযোজ্য net tuition collection থেকে।"
          />
        </p>
      </aside>
      {[
        {
          id: "setup",
          en: "First setup",
          bn: "প্রথম প্রস্তুতি",
          steps: setupSteps,
        },
        {
          id: "admission",
          en: "Student admission",
          bn: "শিক্ষার্থী ভর্তি",
          steps: admissionSteps,
        },
        {
          id: "daily",
          en: "Teaching, reports and money",
          bn: "পাঠদান, প্রতিবেদন ও টাকা",
          steps: dailySteps,
        },
      ].map((section) => (
        <section
          key={section.id}
          id={section.id}
          className="scroll-mt-24 space-y-3"
        >
          <h2 className="text-xl font-semibold">
            <LocalizedText en={section.en} bn={section.bn} />
          </h2>
          <WorkflowSteps
            steps={section.steps}
            permissions={context.permissions}
          />
        </section>
      ))}
      <section className="space-y-2 rounded-xl border p-4">
        <h2 className="font-semibold">
          <LocalizedText en="If something fails" bn="সমস্যা হলে" />
        </h2>
        <p className="leading-7">
          <LocalizedText
            en="Keep the form open and correct highlighted fields. For scheduling, check subject qualification, weekday, effective dates, the full availability window, room capacity and existing bookings. If a save result is uncertain, check the existing record before retrying. Use header search for a name, ID, invoice or RCT receipt reference; it searches only permitted records."
            bn="Form খোলা রেখে highlighted ভুল সংশোধন করুন। Schedule-এ subject qualification, দিন, effective dates, পুরো availability window, room capacity ও booking যাচাই করুন। Save-এর ফল অনিশ্চিত হলে retry-এর আগে existing record দেখুন। Header search-এ নাম, ID, invoice বা RCT receipt reference লিখুন; শুধু অনুমোদিত তথ্য খোঁজে।"
          />
        </p>
      </section>
    </div>
  );
}
