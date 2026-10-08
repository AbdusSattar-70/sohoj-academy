export type WorkflowGuideData = {
  en: string;
  bn: string;
  steps: [string, string][];
  next?: string[];
};
export const workflowGuides: Record<string, WorkflowGuideData> = {
  admissions: {
    en: "Complete one admission case",
    bn: "একটি ভর্তি সম্পন্ন করুন",
    steps: [
      [
        "Start from a new application or a verified enquiry; save a draft if unfinished.",
        "নতুন আবেদন অথবা যাচাইকৃত আগ্রহী শিক্ষার্থী থেকে শুরু করুন; অসম্পূর্ণ হলে খসড়া রাখুন।",
      ],
      [
        "Confirm identity, programme/batch, referral, paper consent and fee/discount before final submission.",
        "চূড়ান্ত জমার আগে পরিচয়, প্রোগ্রাম/ব্যাচ, রেফারাল, কাগজের সম্মতি এবং ফি/ছাড় যাচাই করুন।",
      ],
      [
        "Final submission creates the Student ID and invoice. Unpaid charges stay due; collect payment and print the receipt from the case.",
        "চূড়ান্ত জমায় Student ID ও invoice তৈরি হয়। অপরিশোধিত টাকা বকেয়া থাকে; case থেকে টাকা গ্রহণ ও receipt print করুন।",
      ],
    ],
    next: ["students", "student-accounts"],
  },
  "teacher-dashboard": {
    en: "Your daily teaching workflow",
    bn: "আপনার দৈনন্দিন পাঠদানের ধাপ",
    steps: [
      [
        "Open today's assigned class; upcoming classes can be used to prepare questions.",
        "আজকের নির্ধারিত ক্লাস খুলুন; আসন্ন ক্লাস থেকে প্রশ্ন প্রস্তুত করতে পারেন।",
      ],
      [
        "Record student attendance, actual teaching time, topics and homework; submit for admin review.",
        "শিক্ষার্থীর উপস্থিতি, প্রকৃত পাঠদানের সময়, টপিক ও বাড়ির কাজ লিখে admin review-এর জন্য জমা দিন।",
      ],
      [
        "Use My work for your own attendance, assigned tasks and earnings; these are separate from student attendance.",
        "নিজের উপস্থিতি, নির্ধারিত কাজ ও পাওনার জন্য আমার কাজ খুলুন; এগুলো শিক্ষার্থীর attendance থেকে আলাদা।",
      ],
    ],
    next: ["my-work"],
  },
  "my-work": {
    en: "Your work, attendance and earnings",
    bn: "আপনার কাজ, উপস্থিতি ও পাওনা",
    steps: [
      [
        "Choose the Attendance, Assigned work or Earnings tab. Only the selected section loads.",
        "উপস্থিতি, নির্ধারিত কাজ অথবা পাওনা tab খুলুন। শুধু নির্বাচিত অংশের তথ্য load হবে।",
      ],
      [
        "Report task progress or blockers; completed work needs admin acceptance. Progress does not automatically change salary.",
        "কাজের অগ্রগতি বা বাধা জানান; সম্পন্ন কাজ admin গ্রহণ করবেন। অগ্রগতি অনুযায়ী বেতন স্বয়ংক্রিয়ভাবে বদলায় না।",
      ],
    ],
  },
  "staff-operations": {
    en: "Manage staff work",
    bn: "স্টাফের কাজ পরিচালনা",
    steps: [
      [
        "Choose Attendance or Assigned work. Select the responsible person before recording or assigning.",
        "উপস্থিতি অথবা নির্ধারিত কাজ নির্বাচন করুন। রেকর্ড বা দায়িত্ব দেওয়ার আগে সংশ্লিষ্ট ব্যক্তি নির্বাচন করুন।",
      ],
      [
        "Give a clear task, deadline and instructions; review completed submissions or return them with an explanation.",
        "স্পষ্ট কাজ, সময়সীমা ও নির্দেশনা দিন; জমা কাজ গ্রহণ করুন অথবা কারণসহ সংশোধনের জন্য ফেরত দিন।",
      ],
      [
        "Academic questions follow the teacher's routine; do not assign duplicate question-making tasks here.",
        "Academic প্রশ্ন শিক্ষক নিজের রুটিন থেকে তৈরি করেন; একই প্রশ্নের জন্য এখানে আলাদা কাজ দেবেন না।",
      ],
    ],
  },
  "programme-offerings": {
    en: "Prepare a programme for admission",
    bn: "ভর্তির জন্য প্রোগ্রাম প্রস্তুত করুন",
    steps: [
      [
        "Create or edit the academic context. Standard fees, batch placement and public visibility are separate setup steps.",
        "শিক্ষার প্রেক্ষাপট তৈরি বা edit করুন। নির্ধারিত ফি, ব্যাচ এবং website visibility আলাদা প্রস্তুতির ধাপ।",
      ],
      [
        "Check fees and batch capacity before opening applications. Website visibility does not mean applications are open.",
        "আবেদন চালুর আগে ফি ও ব্যাচ capacity যাচাই করুন। Website visibility মানেই আবেদন চালু নয়।",
      ],
    ],
    next: ["fee-plans", "batches", "weekly-routines"],
  },
  "weekly-routines": {
    en: "Plan first, then generate dated classes",
    bn: "পরিকল্পনার পরে তারিখভিত্তিক ক্লাস তৈরি করুন",
    steps: [
      [
        "Prepare batch times, qualified teacher, room availability and holidays; then save the weekly routine.",
        "ব্যাচের সময়, যোগ্য শিক্ষক, কক্ষের availability ও ছুটি প্রস্তুত করে সাপ্তাহিক রুটিন সংরক্ষণ করুন।",
      ],
      [
        "Generate sessions for a date range. For a single-day change, use that session's change action rather than rewriting the routine.",
        "নির্দিষ্ট সময়ের session তৈরি করুন। এক দিনের পরিবর্তন সেই session-এর action দিয়ে করুন; পুরো রুটিন পুনরায় লিখবেন না।",
      ],
    ],
    next: ["academic-planning", "academic-operations"],
  },
  "academic-operations": {
    en: "Class calendar and actual records",
    bn: "ক্লাস ক্যালেন্ডার ও প্রকৃত তথ্য",
    steps: [
      [
        "Filter dates and open a class. Planned time and actual teaching time remain separate.",
        "তারিখ filter করে ক্লাস খুলুন। পরিকল্পিত সময় ও প্রকৃত পাঠদানের সময় আলাদা থাকে।",
      ],
      [
        "Use linked substitute, reschedule, cancel or makeup actions; approved evidence is retained.",
        "Substitute, সময় পরিবর্তন, বাতিল অথবা makeup action ব্যবহার করুন; অনুমোদিত তথ্য সংরক্ষিত থাকে।",
      ],
    ],
    next: ["weekly-routines"],
  },
  "student-accounts": {
    en: "Receive fees without losing the due record",
    bn: "বকেয়ার হিসাব রেখে ফি গ্রহণ করুন",
    steps: [
      [
        "Find the student and select the invoice; confirm discount, payment amount and payment method.",
        "শিক্ষার্থী খুঁজে invoice নির্বাচন করুন; ছাড়, আদায়ের টাকা ও পরিশোধের মাধ্যম যাচাই করুন।",
      ],
      [
        "An invoice records a charge; a receipt confirms actual money received. Review the remaining due after saving.",
        "Invoice পাওনার হিসাব; receipt প্রকৃত টাকা গ্রহণের প্রমাণ। সংরক্ষণের পরে অবশিষ্ট বকেয়া দেখুন।",
      ],
    ],
    next: ["receivables"],
  },
  "question-bank": {
    en: "Prepare, submit and review questions",
    bn: "প্রশ্ন প্রস্তুতি, জমা ও যাচাই",
    steps: [
      [
        "Teacher selects an assigned session and chapter/topic/page, saves a Google Docs draft link and submits.",
        "শিক্ষক নির্ধারিত session ও অধ্যায়/টপিক/পৃষ্ঠা নির্বাচন করে Google Docs খসড়া লিংক সংরক্ষণ ও জমা দেন।",
      ],
      [
        "Admin reviews or returns; finalization records separate academy-owned question and answer-key documents. Google sharing is managed separately.",
        "Admin যাচাই বা ফেরত দেন; final করার সময় academy-owned প্রশ্ন ও answer-key আলাদা document রাখেন। Google sharing আলাদাভাবে পরিচালনা করতে হবে।",
      ],
    ],
  },
  "student-progress": {
    en: "Make a report from approved evidence",
    bn: "অনুমোদিত তথ্য থেকে প্রতিবেদন",
    steps: [
      [
        "Select batch, student and completed period; generate a preview, add comments and home-support choices.",
        "ব্যাচ, শিক্ষার্থী ও সম্পন্ন সময়কাল দিয়ে preview তৈরি করুন; মন্তব্য ও বাড়ির সহায়তা নির্বাচন করুন।",
      ],
      [
        "Only approved evidence is counted; missing results are not zero. Admin finalizes; later corrections need a new report.",
        "শুধু অনুমোদিত তথ্য গণনা হয়; missing ফল শূন্য নয়। Admin final করেন; পরবর্তী সংশোধনের জন্য নতুন report প্রয়োজন।",
      ],
    ],
  },
  "academic-directory": {
    en: "Manage reusable academic choices",
    bn: "বারবার ব্যবহারের শিক্ষার তালিকা",
    steps: [
      [
        "Select the required list, then Create or Edit. Prefer selecting an existing record to making another one.",
        "প্রয়োজনীয় তালিকা খুলে তৈরি বা edit করুন। নতুন duplicate তৈরির বদলে বিদ্যমানটি নির্বাচন করুন।",
      ],
      [
        "Deactivate outdated choices so previous records remain readable.",
        "পুরোনো choice inactive করুন, যাতে আগের তথ্য পড়া যায়।",
      ],
    ],
  },
  staff: {
    en: "Verify staff once",
    bn: "স্টাফকে একবার যাচাই করুন",
    steps: [
      [
        "Review the access request, match the existing identity and choose the permitted responsibilities.",
        "প্রবেশের আবেদন যাচাই করে বিদ্যমান পরিচয় মিলিয়ে অনুমোদিত দায়িত্ব নির্বাচন করুন।",
      ],
      [
        "Send secure account setup only after verification. A requested role alone never grants access.",
        "যাচাইয়ের পরে নিরাপদ account setup পাঠান। চাওয়া role নিজে থেকে প্রবেশাধিকার দেয় না।",
      ],
    ],
    next: ["staff-operations"],
  },
};

Object.assign(workflowGuides, {
  dashboard: {
    en: "Choose today's next action",
    bn: "আজকের পরের কাজ নির্বাচন করুন",
    steps: [
      [
        "Open a linked count or quick action to work on admissions, fees or staff tasks.",
        "ভর্তি, ফি অথবা স্টাফের কাজ করতে সংশ্লিষ্ট সংখ্যা বা action খুলুন।",
      ],
      [
        "Use the action centre for due follow-ups and pending reviews; academic setup is kept in its own sidebar group.",
        "বকেয়ার যোগাযোগ ও pending review-এর জন্য করণীয় কেন্দ্র খুলুন; শিক্ষার প্রস্তুতি sidebar-এর আলাদা বিভাগে পাবেন।",
      ],
    ],
    next: ["admissions", "staff-operations", "action-center"],
  },
  "action-center": {
    en: "Resolve due work",
    bn: "প্রয়োজনীয় কাজ সম্পন্ন করুন",
    steps: [
      [
        "Open the specific enquiry, access request or review instead of creating a second record.",
        "নতুন দ্বিতীয় record না করে সংশ্লিষ্ট enquiry, access request বা review খুলুন।",
      ],
      [
        "Check the underlying record before approving or repeating an uncertain action.",
        "অনুমোদন অথবা অনিশ্চিত কাজ পুনরায় করার আগে মূল record যাচাই করুন।",
      ],
    ],
  },
  "fee-plans": {
    en: "Set standard charges",
    bn: "নির্ধারিত ফি প্রস্তুত করুন",
    steps: [
      [
        "Choose the exact offering, tuition cycle, due day and fee components. A standard fee is not a payment.",
        "নির্দিষ্ট offering, tuition cycle, due day ও fee components নির্বাচন করুন। নির্ধারিত ফি টাকা গ্রহণ নয়।",
      ],
      [
        "Check what the published/current fee applies to before saving; existing issued invoices remain separate financial records.",
        "সংরক্ষণের আগে প্রকাশিত/বর্তমান ফি কোথায় প্রযোজ্য দেখুন; আগের issued invoice আলাদা financial record।",
      ],
    ],
    next: ["programme-offerings", "batches"],
  },
  batches: {
    en: "Prepare placement",
    bn: "ব্যাচে জায়গা প্রস্তুত করুন",
    steps: [
      [
        "Select the offering, set capacity and recognizable batch name; define days/time under academic planning.",
        "Offering নির্বাচন করে capacity ও পরিচিত ব্যাচের নাম দিন; দিন/সময় শিক্ষা পরিকল্পনায় দিন।",
      ],
      [
        "Batch capacity and classroom seats are separate; check both before scheduling.",
        "ব্যাচের capacity ও classroom-এর আসন আলাদা; schedule-এর আগে দুটোই যাচাই করুন।",
      ],
    ],
    next: ["academic-planning", "weekly-routines"],
  },
  "academic-planning": {
    en: "Prepare rooms and available times",
    bn: "কক্ষ ও ব্যবহারযোগ্য সময় প্রস্তুত করুন",
    steps: [
      [
        "Choose the setup section you need. Room capacity, teacher qualification and weekly availability are different records.",
        "প্রয়োজনীয় setup section খুলুন। কক্ষের capacity, শিক্ষকের যোগ্যতা ও weekly availability আলাদা record।",
      ],
      [
        "Availability must cover the entire session, weekday and effective dates. Existing bookings can still prevent scheduling.",
        "Availability-তে পুরো session-এর সময়, সপ্তাহের দিন ও কার্যকর তারিখ থাকতে হবে। বিদ্যমান booking থাকলে schedule সম্ভব নাও হতে পারে।",
      ],
    ],
    next: ["weekly-routines"],
  },
  "teaching-plans": {
    en: "Prepare what will be taught",
    bn: "কী পড়ানো হবে প্রস্তুত করুন",
    steps: [
      [
        "Select batch and subject, prepare chapter/topic units and publish when ready. Scheduled classes pin their plan.",
        "ব্যাচ ও বিষয় নির্বাচন করে অধ্যায়/টপিক units তৈরি করুন; প্রস্তুত হলে publish করুন। Scheduled ক্লাসে সংশ্লিষ্ট plan যুক্ত থাকে।",
      ],
      [
        "Record actual topic coverage on the class page, not by rewriting completed sessions.",
        "সম্পন্ন session পুনরায় না লিখে ক্লাস পেজে প্রকৃত টপিকের অগ্রগতি দিন।",
      ],
    ],
    next: ["weekly-routines"],
  },
  assessments: {
    en: "Record tests and review results",
    bn: "পরীক্ষা ও ফল যাচাই",
    steps: [
      [
        "Choose the batch/subject, set assessment date and maximum marks; publish before entering results.",
        "ব্যাচ/বিষয় নির্বাচন করে পরীক্ষার তারিখ ও মোট নম্বর দিন; ফল দেওয়ার আগে publish করুন।",
      ],
      [
        "Save results, submit and wait for independent review. Only approved results enter the progress report.",
        "ফল সংরক্ষণ করে জমা দিন এবং আলাদা review-এর অপেক্ষা করুন। শুধু অনুমোদিত ফল অগ্রগতি report-এ যায়।",
      ],
    ],
    next: ["student-progress"],
  },
  students: {
    en: "Use the permanent student record",
    bn: "স্থায়ী শিক্ষার্থী record ব্যবহার করুন",
    steps: [
      [
        "Find the student by identity; open the record for contacts, enrollment and lifecycle actions.",
        "পরিচয় দিয়ে শিক্ষার্থী খুঁজুন; যোগাযোগ, enrollment ও lifecycle action-এর জন্য record খুলুন।",
      ],
      [
        "Use controlled transfer/withdrawal actions; marking a person inactive does not erase past attendance or balances.",
        "নিয়ন্ত্রিত transfer/withdrawal action ব্যবহার করুন; ব্যক্তিকে inactive করলে আগের উপস্থিতি বা balance মুছে যায় না।",
      ],
    ],
    next: ["admissions", "student-accounts"],
  },
  "operating-money": {
    en: "Record real running income or expenses",
    bn: "প্রকৃত পরিচালনার আয় বা খরচ দিন",
    steps: [
      [
        "Choose the income/expense type, amount, date and payment account. Staff salary and student fees have their own workflows.",
        "আয়/খরচের ধরন, টাকা, তারিখ ও payment account নির্বাচন করুন। স্টাফের বেতন ও শিক্ষার্থীর ফি আলাদা workflow।",
      ],
      [
        "Check the record after saving and avoid recording the same payment twice.",
        "সংরক্ষণের পরে record দেখুন; একই লেনদেন দুইবার রেকর্ড করবেন না।",
      ],
    ],
    next: ["finance-overview"],
  },
  "access-security": {
    en: "Give only the access required",
    bn: "প্রয়োজনীয় প্রবেশাধিকার দিন",
    steps: [
      [
        "Verify the person and role; requested access is not automatic approval.",
        "ব্যক্তি ও role যাচাই করুন; চাওয়া access স্বয়ংক্রিয় অনুমোদন নয়।",
      ],
      [
        "Choose the necessary permissions and confirm the person's assigned scope before enabling operational access.",
        "প্রয়োজনীয় permission নির্বাচন করে কাজের scope যাচাইয়ের পরে operational access দিন।",
      ],
    ],
    next: ["staff"],
  },
});
