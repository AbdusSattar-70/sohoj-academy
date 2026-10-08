import type { WorkflowStep } from "./workflow-guide";
export const dailySteps: WorkflowStep[] = [
  {
    title: ["Open the dated class", "১. আজকের ক্লাস ও শিক্ষার্থীর উপস্থিতি"],
    body: [
      "Teachers open their assigned class, record the student roster, topics, actual start/end and homework, then submit. Admin reviews or requests correction. A cancelled class earns no teaching hours; use linked makeup or reschedule actions.",
      "শিক্ষক নিজের assigned session খুলে student attendance, topics, actual সময় ও homework জমা দেন। Admin গ্রহণ বা correction চান। Cancelled class-এর teaching hours নেই; প্রয়োজন হলে makeup বা reschedule action দিন।",
    ],
    href: "/dashboard/academics/operations",
    permission: "academics.view",
  },
  {
    title: ["Keep staff presence separate", "২. স্টাফের উপস্থিতি আলাদা"],
    body: [
      "My attendance is staff presence, not student attendance or verified teaching hours. Authorized staff record attendance; missing records are not automatically absence.",
      "নিজের/স্টাফের উপস্থিতি student attendance বা verified teaching hours নয়। অনুমোদিত ব্যক্তি record করবেন। Missing record মানে absent নয়।",
    ],
    href: "/dashboard/attendance",
    permission: "workforce.self.view",
  },
  {
    title: ["Submit Google Docs questions", "৩. প্রশ্ন ও answer key"],
    body: [
      "Prepare questions from the scheduled teaching scope in Google Docs, include chapter/topic/pages and submit for review. Admin returns corrections or records the final academy-owned documents. No separate admin question task is needed.",
      "Routine-এর বিষয় থেকে Google Docs-এ প্রশ্ন ও answer key তৈরি করুন। অধ্যায়/topic/page দিয়ে review-এ জমা দিন। Admin correction অথবা final academy document যুক্ত করেন; আলাদা question task দেন না।",
    ],
    href: "/dashboard/academics/questions",
    permission: "academics.view",
  },
  {
    title: [
      "Record a test and student results",
      "৪. পরীক্ষা ও individual marks",
    ],
    body: [
      "A batch/subject test contains individual student results and absence. Publish its terms, enter results and submit for review. A separate test per student is not necessary for a shared batch exam.",
      "একটি batch/subject test-এর অধীনে প্রত্যেক শিক্ষার্থীর marks/absence থাকবে। Terms publish করে ফল জমা দিন ও review করুন। একই batch exam প্রত্যেক ছাত্রের জন্য নতুন করে তৈরি নয়।",
    ],
    href: "/dashboard/academics/assessments",
    permission: "academics.view",
  },
  {
    title: ["Review progress reports", "৫. অগ্রগতি প্রতিবেদন"],
    body: [
      "Generate the period report from approved evidence, review comments and missing data, submit and finalize. Unrecorded marks or attendance are not assumed zero or absent.",
      "Approved evidence থেকে period report তৈরি করুন। Comments ও missing data যাচাই করে জমা ও final করুন। অনথিভুক্ত marks/attendance-কে zero বা absent ধরবেন না।",
    ],
    href: "/dashboard/academics/progress",
    permission: "academics.view",
  },
  {
    title: [
      "Follow dues, payments and running costs",
      "৬. বকেয়া, পরিশোধ ও দৈনন্দিন খরচ",
    ],
    body: [
      "Student fees show charges, discounts, collections and outstanding balance separately. Record running expenses and other income. Earnings show earned, actually paid and remaining; salary estimates are not payment confirmations.",
      "Student fees-তে charge, discount, collection ও due আলাদা দেখুন। Running expense ও other income record করুন। Earnings-এ earned, actual paid ও remaining আলাদা; estimate মানে টাকা পরিশোধ নয়।",
    ],
    href: "/dashboard/finance/billing",
    permission: "finance.view",
  },
];
