"use client";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { PublicControlsForm } from "@/modules/offerings/components/public-controls-form";
import type { OfferingOverview } from "@/modules/offerings/queries";
import { useLanguage } from "@/components/providers/language-provider";
export function WebsiteWorkspace({
  data,
}: {
  data: Pick<OfferingOverview, "offerings" | "subjects" | "offeringSubjects">;
}) {
  const { locale } = useLanguage();
  const t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [selected, setSelected] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const offering = data.offerings.find((row) => row.id === selected);
  return (
    <div className="space-y-5">
      {notice && (
        <p role="status" className="rounded-lg border p-3">
          {notice}
        </p>
      )}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-left text-sm">
          <thead>
            <tr>
              <th className="p-3">
                {t("Programme showcase", "প্রোগ্রামের প্রদর্শন")}
              </th>
              <th className="p-3">{t("Website", "ওয়েবসাইট")}</th>
              <th className="p-3">{t("Applications", "আবেদন")}</th>
              <th className="p-3">{t("Action", "করণীয়")}</th>
            </tr>
          </thead>
          <tbody>
            {data.offerings.map((row) => (
              <tr key={row.id} className="border-t">
                <td className="p-3">{row.name}</td>
                <td className="p-3">
                  {row.is_website_visible
                    ? t("Visible", "দৃশ্যমান")
                    : t("Hidden", "লুকানো")}
                </td>
                <td className="p-3">
                  {row.is_accepting_applications
                    ? t("Open", "চালু")
                    : t("Closed", "বন্ধ")}
                </td>
                <td className="p-3">
                  <Button
                    variant="outline"
                    onClick={(event) => {
                      guardWorkspaceNavigation(event, locale);
                      if(event.defaultPrevented) return;
                      setSelected(row.id);
                      setNotice("");
                    }}
                  >
                    {t("Edit public content", "প্রকাশ্য তথ্য সম্পাদনা")}
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!data.offerings.length && (
        <p>
          {t(
            "No programme showcase yet. Prepare a programme offering in Academics first.",
            "এখনো প্রদর্শনের প্রোগ্রাম নেই। আগে শিক্ষা বিভাগে offering প্রস্তুত করুন।",
          )}
        </p>
      )}
      {offering && (
        <section className="space-y-3 rounded-xl border p-4">
          <Button variant="outline" onClick={(event) => {guardWorkspaceNavigation(event, locale); if(!event.defaultPrevented) setSelected(null);}}>
            {t("Close editor", "সম্পাদনা বন্ধ করুন")}
          </Button>
          <PublicControlsForm
            key={offering.id}
            offering={offering}
            subjects={data.subjects}
            linkedSubjectIds={data.offeringSubjects
              .filter((row) => row.offering_id === offering.id)
              .map((row) => row.subject_id)}
            onSuccess={() => {
              setSelected(null);
              setNotice(
                t("Public content saved.", "প্রকাশ্য তথ্য সংরক্ষিত হয়েছে।"),
              );
            }}
          />
        </section>
      )}
    </div>
  );
}
