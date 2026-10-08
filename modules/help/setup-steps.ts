import type { WorkflowStep } from "./workflow-guide";
export const setupSteps: WorkflowStep[] = [
  {
    title: [
      "Check academic and registration lists",
      "১. শিক্ষা ও নিবন্ধনের তালিকা যাচাই",
    ],
    body: [
      "Check seeded classes, groups, subjects, years, programme definitions and schools. Add missing choices and deactivate outdated ones. A class is an educational level; a classroom is a physical room. Training can use course dates without a school class.",
      "Seed তালিকা থেকে শ্রেণি, group, বিষয়, বছর, programme ও স্কুল যাচাই করুন। অনুপস্থিত তথ্য যোগ করুন, অচল তথ্য inactive করুন। Class 10 শিক্ষার স্তর; Room 1 বাস্তব কক্ষ। Training-এ school class বাধ্যতামূলক নয়।",
    ],
    href: "/dashboard/academics/settings",
    permission: "system.master_data.manage",
  },
  {
    title: [
      "Verify staff and teaching subjects",
      "২. স্টাফ যাচাই ও পাঠদানের বিষয়",
    ],
    body: [
      "Review access requests, match existing identity and assign only required access. Configure the verified teacher’s teaching subjects before scheduling. Requested roles never grant access.",
      "স্টাফের আবেদন যাচাই করে existing identity মিলিয়ে প্রয়োজনীয় role দিন। একই ব্যক্তি দ্বিতীয়বার তৈরি করবেন না। এরপর শিক্ষকের অনুমোদিত বিষয় দিন; শুধু account থাকলেই সব বিষয় পড়ানোর অনুমতি হয় না।",
    ],
    href: "/dashboard/staff",
    permission: "staff.view",
  },
  {
    title: [
      "Prepare an offering and standard fees",
      "৩. অফারিং ও নির্ধারিত ফি",
    ],
    body: [
      "Prepare the programme’s branch, class/group and dates. Set standard tuition, one-time fees and allowed discounts separately. Draft status, website visibility and application intake are different controls.",
      "SSC প্রস্তুতি ২০২৭-এর শাখা, Class 10 Science, বিষয় ও তারিখ ঠিক করুন। নির্ধারিত tuition, এককালীন fee ও allowed discount দিন। Draft, website visibility ও আবেদন গ্রহণ আলাদা controls।",
    ],
    href: "/dashboard/academics/offerings",
    permission: "academics.view",
  },
  {
    title: ["Create a batch and set its times", "৪. ব্যাচ ও পাঠদানের সময়"],
    body: [
      "Create Morning A with 12 seats. Set weekdays and daily time windows in batch planning. A 7–9 AM window can contain several subject classes; it does not book a teacher.",
      "Morning A, ১২ আসনের ব্যাচ তৈরি করুন। Batch planning-এ রবি-মঙ্গল-বৃহস্পতি সকাল ৭–৯টা দিন। দুই ঘণ্টায় আলাদা বিষয়ের session হতে পারে; এতে শিক্ষক বুক হয় না।",
    ],
    href: "/dashboard/academics/batches",
    permission: "academics.view",
  },
  {
    title: [
      "Prepare room and teacher availability",
      "৫. শিক্ষক ও কক্ষের ব্যবহারযোগ্য সময়",
    ],
    body: [
      "Add room capacity, teaching qualifications, effective dates and weekly availability. The whole session must fit the window. Holidays and existing bookings are checked separately.",
      "কক্ষের আসন, শিক্ষকের বিষয়, কার্যকর তারিখ ও সাপ্তাহিক সময় দিন। Session-এর পুরো সময় window-এর মধ্যে থাকতে হবে। ছুটি ও আগে থেকে booking আলাদা যাচাই হয়।",
    ],
    href: "/dashboard/academics/planning?section=availability",
    permission: "academics.sessions.manage",
  },
  {
    title: [
      "Save a routine, then generate classes",
      "৬. রুটিন থেকে তারিখভিত্তিক ক্লাস",
    ],
    body: [
      "Choose batch, subject, qualified teacher, room and day/time. Save the weekly routine, then Generate classes on its row for a date range. Conflicts retain your input. Open a dated class to record attendance.",
      "ব্যাচ, বিষয়, যোগ্য শিক্ষক, কক্ষ ও দিন–সময় দিয়ে routine সংরক্ষণ করুন। তার row থেকে date range-এর ক্লাস তৈরি করুন। Conflict হলে input থাকবে। উপস্থিতি routine-এ নয়, তারিখভিত্তিক session-এ নেবেন।",
    ],
    href: "/dashboard/academics/routine",
    permission: "academics.sessions.manage",
  },
  {
    title: ["Publish the website showcase", "৭. ওয়েবসাইট ও আবেদন চালু"],
    body: [
      "Use Website management for public programme descriptions, visibility and intake. Academic choices remain in Academic settings. Preview the public page before opening applications.",
      "Website management থেকে প্রকাশ্য বিবরণ, visibility ও intake ঠিক করুন। শ্রেণি/বিষয় এখানে তৈরি নয়। Public পেজ দেখে আবেদন চালু করুন।",
    ],
    href: "/dashboard/crm/manage",
    permission: "academics.manage",
  },
];
