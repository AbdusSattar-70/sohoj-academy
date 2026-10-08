import type { WorkflowStep } from "./workflow-guide";
export const admissionSteps: WorkflowStep[] = [
  {
    title: ["Choose the correct entry path", "১. ভর্তির সঠিক পথ"],
    body: [
      "Enter a new student directly, continue an existing enquiry, or add another admission for an existing student. Direct admission does not need a Prospect. Public preferences remain unverified until staff confirm placement.",
      "নতুন শিক্ষার্থী সরাসরি, enquiry থেকে conversion অথবা existing student-এর নতুন programme নির্বাচন করুন। Direct admission-এ অপ্রয়োজনীয় Prospect লাগে না। Public পছন্দ যাচাই না করে চূড়ান্ত placement করবেন না।",
    ],
    href: "/dashboard/admissions",
    permission: "admissions.view",
  },
  {
    title: ["Verify identity and placement", "২. পরিচয় ও placement যাচাই"],
    body: [
      "Review student, guardian, school, address, offering and available batch in the case. Create a missing school or relationship inline. Save a draft if details are incomplete; correct a Prospect’s inherited data before moving forward.",
      "একই case-এ ছাত্র, অভিভাবক, স্কুল, ঠিকানা, offering ও খালি batch যাচাই করুন। স্কুল বা relationship না পেলে সেখানেই যোগ করুন। অসম্পূর্ণ হলে Draft রাখুন। Prospect থেকে এলে inherited data প্রথমে সংশোধন করুন।",
    ],
    href: "/dashboard/admissions",
    permission: "admissions.view",
  },
  {
    title: ["Record referral and paper consent", "৩. রেফারাল ও কাগজের সম্মতি"],
    body: [
      "Select Organic or a verified referrer; add a missing referrer inline. Print the application, obtain the guardian signature and record the date and physical file location. A scan upload is not required.",
      "Organic বা যাচাইকৃত referrer নির্বাচন করুন; না থাকলে সেখানেই যোগ করুন। Form print করে অভিভাবকের signature নিন; তারিখ ও physical file location record করুন। Scan upload প্রয়োজন নেই।",
    ],
    href: "/dashboard/admissions",
    permission: "admissions.view",
  },
  {
    title: ["Review fees and finalize", "৪. ফি যাচাই করে চূড়ান্ত করুন"],
    body: [
      "Review pinned standard fees, allowed discount and any agreed one-time charge. Finalize only after prerequisites are complete. The case issues the student identity and initial invoice. An invoice records charges, not money received.",
      "নির্ধারিত ফি, অনুমোদিত discount ও অতিরিক্ত এককালীন charge যাচাই করুন। প্রয়োজনীয় ধাপ শেষে Finalize করুন। Student identity ও initial invoice হবে। Invoice টাকা পাওয়ার প্রমাণ নয়।",
    ],
    href: "/dashboard/admissions",
    permission: "admissions.view",
  },
  {
    title: [
      "Record actual payment and print receipt",
      "৫. টাকা গ্রহণ ও receipt",
    ],
    body: [
      "On the same case, record only money actually received and its payment method. Print its receipt; printing does not post a second payment. Activate enrollment according to the configured payment policy; unpaid charges remain due.",
      "একই case-এ যত টাকা বাস্তবে পেয়েছেন ও payment method দিন। Receipt print করুন; print-এ দ্বিতীয় payment হয় না। Payment policy অনুযায়ী enrollment activate করুন; unpaid টাকা due থাকবে।",
    ],
    href: "/dashboard/admissions",
    permission: "admissions.view",
  },
];
