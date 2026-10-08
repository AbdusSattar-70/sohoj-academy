import Link from "next/link";
import { ExternalLink } from "lucide-react";
import { PageHeader } from "@/components/erp/page-header";
import { ProspectTable } from "@/modules/crm/components/prospect-table";
import { getProspectList } from "@/modules/crm/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function ProspectsPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; q?: string; status?: string; intent?: string }>;
}) {
  await requirePermission("crm.prospects.view");
  const params = await searchParams;
  const result = await getProspectList({
    page: Math.max(1, Number.parseInt(params.page ?? "1", 10) || 1),
    query: params.q,
    status: params.status,
    intent: params.intent,
  });
  const rows = result.rows;

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="CRM & Student Bank"
        title="Prospects"
        description="Verification queue for public interest and admission submissions. Filter by queue status, intent and schools that still need review before counselling or admission."
        actions={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/dashboard/academics/settings"
              className="inline-flex min-h-11 items-center gap-2 rounded-xl border bg-background px-4 text-sm font-semibold hover:bg-muted"
            >
              Academic & registration settings
            </Link>
            <Link
              href="/interest"
              target="_blank"
              className="inline-flex min-h-11 items-center gap-2 rounded-xl border bg-background px-4 text-sm font-semibold hover:bg-muted"
            >
              Public interest form
              <ExternalLink className="size-4" aria-hidden="true" />
            </Link>
          </div>
        }
      />

      <ProspectTable
        rows={rows}
        total={result.total}
        page={result.page}
        pageSize={result.pageSize}
        initialQuery={params.q ?? ""}
        initialStatus={params.status ?? "QUEUE"}
        initialIntent={params.intent ?? "ALL"}
      />
    </div>
  );
}
