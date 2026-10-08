"use client";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
export function PrintAdmissionButton() {
  const { locale } = useLanguage();
  return (
    <div className="space-y-2 print:hidden">
      <Button onClick={() => window.print()}>
        {locale === "bn" ? "প্রিন্ট / PDF সংরক্ষণ" : "Print / Save PDF"}
      </Button>
      <p className="max-w-xl text-xs text-muted-foreground">
        {locale === "bn"
          ? "A4 কাগজ ও ১০০% scale ব্যবহার করুন। Browser header/footer বন্ধ করুন। প্রিন্টের আগে সব পৃষ্ঠা preview দেখুন; প্রিন্ট করলে ভর্তি বা টাকা গ্রহণ রেকর্ড হয় না।"
          : "Use A4 at 100% scale and disable browser headers/footers. Review every page in print preview. Printing does not record admission or payment."}
      </p>
    </div>
  );
}
