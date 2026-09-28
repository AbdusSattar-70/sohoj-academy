import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { PrintAdmissionButton } from "@/modules/admissions/components/print-button";
import { requirePermission } from "@/modules/platform/auth/erp-context";

const field = (label: string, className = "") => <div className={className}>
  <p className="text-xs font-medium text-gray-700">{label}</p>
  <div className="mt-2 min-h-7 border-b border-gray-500" />
</div>;

export default async function BlankAdmissionApplicationForm() {
  await requirePermission("admissions.create");
  return <div className="space-y-4">
    <PageHeader
      eyebrow="Student Lifecycle · Print"
      title="Blank student application"
      description="Print this form for a student and guardian to complete by hand. Staff should enter the verified details in Admissions and attach the signed consent to the admission case."
      actions={<div className="flex gap-2 print:hidden"><Link className="inline-flex min-h-11 items-center rounded-xl border px-4 text-sm" href="/dashboard/admissions">Back to Admissions</Link><PrintAdmissionButton /></div>}
    />
    <style>{`@media print { body * { visibility:hidden; } .blank-application,.blank-application * { visibility:visible; } .blank-application { position:absolute; inset:0; width:100%; padding:0!important; border:0!important; box-shadow:none!important; color:#111!important; background:#fff!important; } .avoid-break { break-inside:avoid; } @page { size:A4; margin:12mm 14mm; } }`}</style>
    <article className="blank-application mx-auto max-w-3xl rounded-xl border bg-white p-8 text-gray-950">
      <header className="border-b-2 border-gray-800 pb-4 text-center">
        <h1 className="text-xl font-bold tracking-wide">SOHOJ ACADEMY</h1>
        <p className="mt-1 text-xs">Student Application &amp; Guardian Consent</p>
        <div className="mt-4 grid grid-cols-2 gap-6 text-left">
          {field("Application reference (office use)")}
          {field("Date received")}
        </div>
      </header>
      <section className="avoid-break mt-5">
        <h2 className="text-sm font-bold">1. Student information</h2>
        <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-4">
          {field("Full name (English)", "col-span-2")}
          {field("Full name (Bangla)", "col-span-2")}
          {field("Date of birth")}{field("Gender (optional)")}
          {field("Current school")}{field("School roll")}
        </div>
      </section>
      <section className="avoid-break mt-5">
        <h2 className="text-sm font-bold">2. Programme and placement preference</h2>
        <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-4">
          {field("Programme / offering", "col-span-2")}
          {field("Academic class")}{field("Preferred batch / time")}
          {field("Subjects where support is needed", "col-span-2")}
        </div>
        <p className="mt-2 text-[10px] text-gray-600">Final eligibility and batch placement are verified by Sohoj Academy. This application does not confirm admission or reserve a seat.</p>
      </section>
      <section className="avoid-break mt-5">
        <h2 className="text-sm font-bold">3. Parent / guardian information</h2>
        <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-4">
          {field("Guardian full name")}{field("Relationship to student")}
          {field("Primary mobile")}{field("Alternate mobile")}
          {field("Full address", "col-span-2")}
          {field("Referrer name (if any)")}{field("Referrer contact (optional)")}
        </div>
      </section>
      <section className="avoid-break mt-5">
        <h2 className="text-sm font-bold">4. Declaration and consent</h2>
        <p className="mt-2 text-[11px] leading-5">I confirm that the information provided is accurate to the best of my knowledge. I authorize Sohoj Academy to contact me about this application and use these details to verify eligibility, communicate with the family, and maintain the student’s education record. I understand that staff verification, admission acceptance, billing, payment and enrollment activation are separate steps. Fees and placement will be confirmed by the academy before acceptance.</p>
        <div className="mt-8 grid grid-cols-2 gap-x-10 gap-y-7 text-[11px]">
          {field("Guardian signature and date")}{field("Student signature (optional) and date")}
        </div>
      </section>
      <section className="avoid-break mt-6 border-t pt-3">
        <h2 className="text-sm font-bold">Office verification</h2>
        <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-4">
          {field("Offering / class verified")}{field("Batch selected")}
          {field("Identity and guardian details checked")}{field("Consent received on")}
          {field("Entered by")}{field("Staff signature")}
        </div>
      </section>
      <footer className="mt-5 border-t pt-2 text-[10px] text-gray-600">This form records an application and consent. It is not a fee receipt, admission confirmation, or proof of active enrollment.</footer>
    </article>
  </div>;
}
