"use client";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useLanguage } from "@/components/providers/language-provider";
export function WorkTabs({
  admin = false,
  selected,
}: {
  admin?: boolean;
  selected: string;
}) {
  const q = useSearchParams(),
    { locale } = useLanguage();
  const base = admin ? "/dashboard/staff/operations" : "/dashboard/my-work";
  const choices = admin
    ? [
        ["attendance", "Attendance & terms", "উপস্থিতি ও পারিশ্রমিকের শর্ত"],
        ["tasks", "Assign & review work", "কাজ দিন ও পর্যালোচনা করুন"],
      ]
    : [
        ["attendance", "My attendance", "আমার উপস্থিতি"],
        ["tasks", "Assigned work", "নির্ধারিত কাজ"],
        ["earnings", "Earnings & payments", "পাওনা ও পরিশোধ"],
      ];
  return (
    <nav
      aria-label={locale === "bn" ? "কাজের বিভাগ" : "Work sections"}
      className="flex flex-wrap gap-2"
    >
      {choices.map(([id, en, bn]) => {
        const next = new URLSearchParams(q.toString());
        next.set("tab", id);
        next.delete("page");
        next.delete("tasksPage");
        next.delete("tasksView");
        return (
          <Link
            key={id}
            prefetch={false}
            href={base + "?" + next}
            aria-current={selected === id ? "page" : undefined}
            className={
              "inline-flex min-h-11 items-center rounded-lg border px-4 py-2 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring " +
              (selected === id
                ? "bg-primary text-primary-foreground"
                : "hover:bg-muted")
            }
          >
            {locale === "bn" ? bn : en}
          </Link>
        );
      })}
    </nav>
  );
}
