import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { OfferingForm } from "@/modules/offerings/components/offering-form";
import { PublicControlsForm } from "@/modules/offerings/components/public-controls-form";
import { PublicVersionWorkflow } from "@/modules/offerings/components/public-version-workflow";
import { getOfferingOverview } from "@/modules/offerings/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { can } from "@/types/erp";

export default async function ProgrammeOfferingsPage() {
  const context = await requirePermission("academics.view");
  const data = await getOfferingOverview();
  const label = (rows: { id: string; name: string }[], id: string | null) =>
    rows.find((row) => row.id === id)?.name ?? "—";

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Academics"
        title="Programme Offerings"
        description="Define where, when and for whom a programme runs. Publish a Fee Plan to make an offering ACTIVE. Curate website visibility, application intake and showcase copy independently."
      />
      {can(context, "academics.manage") && <OfferingForm data={data} />}

      <section className="rounded-2xl border bg-card p-5 sm:p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="font-semibold">Offering Register</h2>
            <p className="text-sm text-muted-foreground">
              {data.offerings.length} offerings, including drafts and history.
            </p>
          </div>
          {can(context, "finance.view") && (
            <Link
              href="/dashboard/finance/fee-plans"
              className="text-sm font-semibold text-primary underline-offset-4 hover:underline"
            >
              View Fee Plans →
            </Link>
          )}
        </div>
        {data.offerings.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[960px] text-left text-sm">
              <thead>
                <tr className="border-b bg-muted/40">
                  <th className="p-3">Code / Name</th>
                  <th className="p-3">Year</th>
                  <th className="p-3">Branch</th>
                  <th className="p-3">Class / Group</th>
                  <th className="p-3">Programme</th>
                  <th className="p-3">Status</th>
                  <th className="p-3">Website</th>
                  <th className="p-3">Applications</th>
                </tr>
              </thead>
              <tbody>
                {data.offerings.map((row) => (
                  <tr key={row.id} className="border-b last:border-0">
                    <td className="p-3">
                      <strong>{row.code}</strong>
                      <span className="block text-muted-foreground">{row.name}</span>
                    </td>
                    <td className="p-3">{label(data.years, row.academic_year_id)}</td>
                    <td className="p-3">{label(data.branches, row.branch_id)}</td>
                    <td className="p-3">
                      {label(data.classes, row.class_id)} /{" "}
                      {row.group_id ? label(data.groups, row.group_id) : "All"}
                    </td>
                    <td className="p-3">{label(data.programs, row.program_id)}</td>
                    <td className="p-3">
                      <StatusBadge value={row.status} />
                    </td>
                    <td className="p-3">
                      {row.is_website_visible ? (
                        <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">
                          Visible
                        </span>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </td>
                    <td className="p-3">
                      {row.is_accepting_applications ? (
                        <span className="rounded-full bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-800 dark:bg-blue-950/40 dark:text-blue-200">
                          Open
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Closed</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="mt-5 rounded-xl border border-dashed p-6 text-sm text-muted-foreground">
            No offerings yet. Create one using the academic context above.
          </p>
        )}
      </section>

      {can(context, "academics.manage") && data.offerings.length > 0 && (
        <section className="rounded-2xl border bg-card p-5 sm:p-6">
          <div>
            <h2 className="font-semibold">Website & application controls</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Only ACTIVE offerings can be website-visible. Accepting applications can stay closed
              while teaching continues. Subject selection feeds public cards and forms.
            </p>
          </div>
          <div className="mt-5 space-y-6">
            {data.offerings.map((offering) => (
              <div key={offering.id}>
                <PublicControlsForm
                  offering={offering}
                  subjects={data.subjects}
                  linkedSubjectIds={data.offeringSubjects
                  .filter((row) => row.offering_id === offering.id)
                  .sort((a, b) => a.sort_order - b.sort_order)
                    .map((row) => row.subject_id)}
                />
                <PublicVersionWorkflow offering={offering} versions={data.publicVersions} />
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
