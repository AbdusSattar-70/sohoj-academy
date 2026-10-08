import type { HelpText } from "@/components/erp/help-disclosure";
export const fieldGuides: Record<string, HelpText> = {
  "Academic Year": {
    en: "The year for this offering. More than one year can be active while preparing a future intake.",
    bn: "এই offering-এর শিক্ষাবর্ষ। পরবর্তী ভর্তি প্রস্তুতির সময় একাধিক বছর active থাকতে পারে।",
  },
  Class: {
    en: "Student academic level, not the physical classroom. Training courses may not require a school class.",
    bn: "শিক্ষার্থীর শিক্ষার স্তর; বাস্তব classroom নয়। Training course-এ school class প্রয়োজন নাও হতে পারে।",
  },
  Programme: {
    en: "Select an existing programme definition. An offering adds the year, branch and eligible student context.",
    bn: "বিদ্যমান programme নির্বাচন করুন। Offering-এর মাধ্যমে বছর, শাখা ও প্রযোজ্য শিক্ষার্থীর প্রেক্ষাপট যুক্ত হয়।",
  },
  "Programme offering": {
    en: "Choose the exact programme, branch and academic context. Only eligible active choices can be used for verified admission.",
    bn: "নির্দিষ্ট programme, শাখা ও শিক্ষার প্রেক্ষাপট নির্বাচন করুন। যাচাইকৃত ভর্তিতে প্রযোজ্য active choice ব্যবহার হবে।",
  },
  Batch: {
    en: "The group the student joins. Check days/time and available seats before choosing.",
    bn: "শিক্ষার্থী যে দলে যোগ দেবেন। নির্বাচনের আগে দিন/সময় ও খালি আসন দেখুন।",
  },
  Capacity: {
    en: "Maximum enrollment seats for this batch. Classroom seating is checked separately when scheduling.",
    bn: "এই ব্যাচের সর্বোচ্চ ভর্তির আসন। Schedule-এর সময় classroom-এর আসন আলাদাভাবে যাচাই হয়।",
  },
  "Billing cycle": {
    en: "Tuition repeats with this cycle; one-time charges are billed once. This does not receive money.",
    bn: "এই cycle অনুযায়ী tuition পুনরাবৃত্ত হয়; one-time charge একবার দেওয়া হয়। এটি টাকা গ্রহণ নয়।",
  },
  "Due day": {
    en: "Choose 1–28 so the due date exists in every month. It is a payment deadline, not automatic collection.",
    bn: "প্রতি মাসে তারিখ রাখতে ১–২৮ দিন নির্বাচন করুন। এটি পরিশোধের সময়সীমা; স্বয়ংক্রিয় টাকা গ্রহণ নয়।",
  },
  Amount: {
    en: "Enter the amount in BDT. Check whether this form records a charge, discount or actual payment before saving.",
    bn: "টাকার অঙ্ক BDT-তে দিন। Save-এর আগে এটি charge, discount নাকি প্রকৃত payment তা দেখুন।",
  },
  Reason: {
    en: "State why this change is needed. It stays with the audit record; do not put passwords or secret account information here.",
    bn: "পরিবর্তনের কারণ দিন। Audit record-এ থাকে; password বা গোপন account তথ্য দেবেন না।",
  },
  School: {
    en: "Select the existing institution; create a missing choice once if authorized. Public applicant text stays unverified until reviewed.",
    bn: "বিদ্যমান প্রতিষ্ঠান নির্বাচন করুন; অনুমতি থাকলে অনুপস্থিতটি একবার তৈরি করুন। Public applicant-এর তথ্য review না হওয়া পর্যন্ত unverified থাকে।",
  },
  "Guardian mobile": {
    en: "Use the verified guardian contact, 01XXXXXXXXX. It is not a unique student identity.",
    bn: "যাচাইকৃত অভিভাবকের 01XXXXXXXXX যোগাযোগ নম্বর দিন। এটি একক student identity নয়।",
  },
  "Student name": {
    en: "Use the verified name. Student identity is issued by the system; shared family mobile numbers do not replace it.",
    bn: "যাচাইকৃত নাম দিন। System student identity দেয়; পরিবারের একই mobile সেটির বিকল্প নয়।",
  },
  Relationship: {
    en: "Choose the guardian's relationship to the student; create a missing reusable choice only when authorized.",
    bn: "শিক্ষার্থীর সঙ্গে অভিভাবকের সম্পর্ক নির্বাচন করুন; অনুমতি থাকলে missing choice তৈরি করুন।",
  },
  Discount: {
    en: "A fee reduction, not money received. Select an allowed percentage and record eligibility before final billing.",
    bn: "ফি কমানো; টাকা গ্রহণ নয়। Final billing-এর আগে অনুমোদিত শতাংশ ও যোগ্যতার কারণ নির্বাচন করুন।",
  },
};
export function fieldGuide(label: string) {
  return fieldGuides[
    Object.keys(fieldGuides).find(
      (key) => key.toLocaleLowerCase() === label.trim().toLocaleLowerCase(),
    ) ?? label
  ];
}
