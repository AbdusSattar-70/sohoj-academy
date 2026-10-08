import { z } from "zod";
import { notFound } from "next/navigation";
import { getProgressReports } from "@/modules/academics/documents/queries";
import { ReportPaper } from "@/modules/academics/documents/progress";
import { ProgressPrintControls } from "@/modules/academics/documents/print-controls";
export default async function Page({
  params,
}: {
  params: Promise<{ reportId: string }>;
}) {
  const { reportId } = await params;
  if (!z.string().uuid().safeParse(reportId).success) notFound();
  const data = await getProgressReports(1, "FINAL", reportId),
    r = data.rows[0];
  if (!r) notFound();
  return (
    <section>
      <ProgressPrintControls />
      <style>{`@media print{[data-slot="sidebar-wrapper"]{display:block!important}[data-slot="sidebar"], [data-slot="sidebar-gap"], #erp-main ~ *,[data-slot="sidebar-inset"]>header{display:none!important}[data-slot="sidebar-inset"]{margin:0!important;width:100%!important}#erp-main{padding:0!important;max-width:none!important}#erp-main> :not(section){display:none!important}@page{size:A4;margin:0 15mm 15mm}.progress-paper{padding:50.8mm 0 0!important;border:0!important;background:white!important;color:black!important;font-family:Arial,sans-serif} .progress-paper *{color:black!important;background:transparent!important} .progress-paper tr,.progress-paper footer{break-inside:avoid}}`}</style>
      <ReportPaper report={r} />
    </section>
  );
}
