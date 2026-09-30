"use client";

import { RecordStateButton } from "@/components/erp/record-state-button";
import { useState } from "react";
import Link from "next/link";
import { StatusBadge } from "@/components/erp/status-badge";
import { OfferingForm } from "@/modules/offerings/components/offering-form";
import { PublicControlsForm } from "@/modules/offerings/components/public-controls-form";
import { PublicVersionWorkflow } from "@/modules/offerings/components/public-version-workflow";
import type { OfferingOverview } from "@/modules/offerings/queries";

type Panel =
  | { kind: "CREATE" }
  | { kind: "EDIT"; id: string }
  | { kind: "PUBLIC"; id: string };

export function OfferingRegister({
  data,
  canManage,
  canViewFees,
}: {
  data: OfferingOverview;
  canManage: boolean;
  canViewFees: boolean;
}) {
  const [panel, setPanel] = useState<Panel | null>(null);
  const selected =
    panel && panel.kind !== "CREATE"
      ? data.offerings.find((item) => item.id === panel.id)
      : undefined;
  const label = (rows: { id: string; name: string }[], id: string | null) =>
    rows.find((row) => row.id === id)?.name ?? "—";
  const linkedSubjectIds = selected
    ? data.offeringSubjects
        .filter((row) => row.offering_id === selected.id)
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((row) => row.subject_id)
    : [];
  const close = () => setPanel(null);
  return (
    <>
      <section className="overflow-hidden rounded-2xl border bg-card">
        <div className="flex flex-wrap items-center justify-between gap-4 border-b p-5 sm:p-6">
          <div>
            <h2 className="font-semibold">Offering Register</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {data.offerings.length} offerings, including drafts and history.
              Use row actions to edit details or public settings.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            {canViewFees && (
              <Link
                href="/dashboard/finance/fee-plans"
                className="text-sm font-semibold text-primary underline-offset-4 hover:underline"
              >
                View Fee Plans <span aria-hidden="true">→</span>
              </Link>
            )}
            {canManage && (
              <button
                type="button"
                onClick={() => setPanel({ kind: "CREATE" })}
                className="inline-flex min-h-11 items-center rounded-xl bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-90"
              >
                Create offering
              </button>
            )}
          </div>
        </div>
        {data.offerings.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1180px] text-left text-sm">
              <thead className="bg-muted/50 text-xs uppercase tracking-wide text-muted-foreground">
                <tr>
                  <th scope="col" className="px-4 py-3">
                    Code / name
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Year
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Branch
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Class / group
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Programme
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Status
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Website
                  </th>
                  <th scope="col" className="px-4 py-3">
                    Applications
                  </th>
                  {canManage && (
                    <th scope="col" className="px-4 py-3 text-right">
                      Actions
                    </th>
                  )}
                </tr>
              </thead>
              <tbody>
                {data.offerings.map((row) => (
                  <tr key={row.id} className="border-t align-top">
                    <td className="px-4 py-4">
                      <p className="font-semibold">{row.code}</p>
                      <p className="mt-1 text-muted-foreground">{row.name}</p>
                    </td>
                    <td className="px-4 py-4">
                      {label(data.years, row.academic_year_id)}
                    </td>
                    <td className="px-4 py-4">
                      {label(data.branches, row.branch_id)}
                    </td>
                    <td className="px-4 py-4">
                      {label(data.classes, row.class_id)} /{" "}
                      {row.group_id
                        ? label(data.groups, row.group_id)
                        : "Not applicable"}
                    </td>
                    <td className="px-4 py-4">
                      {label(data.programs, row.program_id)}
                    </td>
                    <td className="px-4 py-4">
                      <StatusBadge value={row.status} />
                    </td>
                    <td className="px-4 py-4">
                      {row.is_website_visible ? (
                        <span className="rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">
                          Visible
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Hidden</span>
                      )}
                    </td>
                    <td className="px-4 py-4">
                      {row.is_accepting_applications ? (
                        <span className="rounded-full bg-blue-50 px-2 py-1 text-xs font-semibold text-blue-800 dark:bg-blue-950/40 dark:text-blue-200">
                          Open
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Closed</span>
                      )}
                    </td>
                    {canManage && (
                      <td className="px-4 py-4 text-right">
                        <div className="flex flex-wrap justify-end gap-2">
                          {
                            <button
                              type="button"
                              onClick={() =>
                                setPanel({ kind: "EDIT", id: row.id })
                              }
                              className="min-h-9 rounded-lg border px-3 text-xs font-semibold hover:bg-muted"
                            >
                              Edit offering
                            </button>
                          }
                          <RecordStateButton
                            entity="offering"
                            id={row.id}
                            active={row.status !== "RETIRED"}
                          />
                          <button
                            type="button"
                            onClick={() =>
                              setPanel({ kind: "PUBLIC", id: row.id })
                            }
                            className="min-h-9 rounded-lg border px-3 text-xs font-semibold hover:bg-muted"
                          >
                            Public settings
                          </button>
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="p-10 text-center">
            <p className="font-semibold">No programme offerings yet</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Create a draft offering, then publish its standard Fee Plan to
              activate it.
            </p>
            {canManage && (
              <button
                type="button"
                onClick={() => setPanel({ kind: "CREATE" })}
                className="mt-4 min-h-11 rounded-xl bg-primary px-4 text-sm font-semibold text-primary-foreground"
              >
                Create offering
              </button>
            )}
          </div>
        )}
      </section>
      {panel?.kind === "CREATE" && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-black/50 p-4"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby="offering-create-title"
            className="my-auto max-h-[92vh] w-full max-w-3xl overflow-y-auto rounded-2xl border bg-background p-5 shadow-2xl sm:p-7"
          >
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 id="offering-create-title" className="text-xl font-bold">
                  Create Programme Offering
                </h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Set the academic context and staff-facing identity. Fee Plans
                  and public presentation are managed separately.
                </p>
              </div>
              <button
                type="button"
                onClick={close}
                aria-label="Close create offering form"
                className="flex size-9 shrink-0 items-center justify-center rounded-lg border text-lg hover:bg-muted"
              >
                ×
              </button>
            </div>
            <OfferingForm data={data} onSuccess={close} onCancel={close} />
          </section>
        </div>
      )}
      {panel?.kind === "EDIT" && selected && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-black/50 p-4"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby="offering-edit-title"
            className="my-auto max-h-[92vh] w-full max-w-3xl overflow-y-auto rounded-2xl border bg-background p-5 shadow-2xl sm:p-7"
          >
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 id="offering-edit-title" className="text-xl font-bold">
                  Edit Programme Offering
                </h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  {selected.code} · {selected.name}
                </p>
                {selected.status === "ACTIVE" && (
                  <p className="mt-2 rounded-lg border bg-muted/40 p-3 text-xs text-muted-foreground">
                    Active offerings keep their original year, branch, class,
                    programme and group so batches and admissions retain their
                    context. Update the staff-facing code or name here.
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={close}
                aria-label="Close edit offering form"
                className="flex size-9 shrink-0 items-center justify-center rounded-lg border text-lg hover:bg-muted"
              >
                ×
              </button>
            </div>
            <OfferingForm
              key={selected.id}
              data={data}
              initialOffering={selected}
              onSuccess={close}
              onCancel={close}
            />
          </section>
        </div>
      )}
      {panel?.kind === "PUBLIC" && selected && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-black/50 p-4"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby="offering-public-title"
            className="my-auto max-h-[94vh] w-full max-w-4xl overflow-y-auto rounded-2xl border bg-background p-5 shadow-2xl sm:p-7"
          >
            <div className="mb-4 flex items-start justify-between gap-4">
              <div>
                <h2 id="offering-public-title" className="text-xl font-bold">
                  Website & application settings
                </h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  {selected.code} · {selected.name}
                </p>
              </div>
              <button
                type="button"
                onClick={close}
                aria-label="Close public settings"
                className="flex size-9 shrink-0 items-center justify-center rounded-lg border text-lg hover:bg-muted"
              >
                ×
              </button>
            </div>
            <p className="mb-4 rounded-xl border bg-muted/30 p-3 text-sm text-muted-foreground">
              These settings control public visibility, application intake,
              showcase copy and subject selection. Homepage card design remains
              unchanged.
            </p>
            <PublicControlsForm
              offering={selected}
              subjects={data.subjects}
              linkedSubjectIds={linkedSubjectIds}
            />
            <PublicVersionWorkflow
              offering={selected}
              versions={data.publicVersions}
            />
          </section>
        </div>
      )}
    </>
  );
}
