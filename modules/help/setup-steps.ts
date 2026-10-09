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
      "Review access requests, match existing identity and assign only required access. Teaching subjects are optional recommendations; admin may assign any listed active teacher or themselves. Requested roles never grant access.",
      "স্টাফের আবেদন যাচাই করে existing identity মিলিয়ে প্রয়োজনীয় role দিন। একই ব্যক্তি দ্বিতীয়বার তৈরি করবেন না। শিক্ষকের বিষয় recommendation হিসেবে দিতে পারেন; admin তালিকার সক্রিয় শিক্ষক বা নিজেকে ক্লাস দিতে পারবেন।",
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
      "Add a classroom with enough seats. Preferred hours are optional recommendations. Real holidays/unavailability and existing bookings remain enforced.",
      "পর্যাপ্ত আসনের কক্ষ যোগ করুন। পছন্দের সময় দেওয়া ঐচ্ছিক; তা পরামর্শ। বাস্তব ছুটি/বন্ধ সময় ও আগের booking যাচাই হবে।",
    ],
    href: "/dashboard/academics/planning?section=rooms",
    permission: "academics.sessions.manage",
  },
  {
    title: [
      "Save a routine, then generate classes",
      "৬. রুটিন থেকে তারিখভিত্তিক ক্লাস",
    ],
    body: [
      "Choose batch, subject, teacher, room and time; tick multiple weekdays on one class row. Review and activate. Optionally create a dated teaching plan here. Open the class calendar for attendance.",
      "ব্যাচ, বিষয়, শিক্ষক, কক্ষ ও সময় দিন; একই ক্লাসের সব দিন tick করুন। যাচাই করে চালু করুন। চাইলে এখানেই তারিখভিত্তিক পাঠ পরিকল্পনা তৈরি করুন। উপস্থিতির জন্য ক্লাস ক্যালেন্ডার খুলুন।",
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
