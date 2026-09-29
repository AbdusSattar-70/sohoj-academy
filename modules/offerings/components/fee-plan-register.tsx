"use client";

import { useState } from "react";
import Link from "next/link";
import { StatusBadge } from "@/components/erp/status-badge";
import {
  FeePlanForm,
  type EditingFeePlan,
} from "@/modules/offerings/components/fee-plan-form";
import type { OfferingOverview } from "@/modules/offerings/queries";

export function FeePlanRegister({
  data,
  today,
  offeringName,
  canManage,
  canViewOfferings,
}: {
  data: OfferingOverview;
  today: string;
  offeringName: (id: string) => string;
  canManage: boolean;
  canViewOfferings: boolean;
}) {
  const [editing, setEditing] = useState<EditingFeePlan | null>(null);

  function startEdit(plan: OfferingOverview["plans"][number]) {
    setEditing({
      id: plan.id,
      offeringId: plan.offering_id,
      version: plan.version,
      billingCycle: plan.billing_cycle as EditingFeePlan["billingCycle"],
      dueDay: plan.due_day,
      effectiveFrom: plan.effective_from,
      components: data.components
        .filter((item) => item.fee_plan_version_id === plan.id)
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((item) => ({
          code: item.code,
          name: item.name,
          amount: Number(item.amount),
          chargeType:
            item.charge_type as EditingFeePlan["components"][number]["chargeType"],
          recurrence:
            item.recurrence as EditingFeePlan["components"][number]["recurrence"],
        })),
    });
  }

  return (
    <>
      {canManage && (
        <FeePlanForm
          key={editing?.id ?? "new"}
          data={data}
          today={today}
          editing={editing ?? undefined}
          onDone={editing ? () => setEditing(null) : undefined}
        />
      )}
      <section className="rounded-2xl border bg-card p-5 sm:p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="font-semibold">Published Fee Plans</h2>
            <p className="text-sm text-muted-foreground">
              One active plan per offering. Amounts shown here are standard
              fees, before any approved student exception.
            </p>
          </div>
          {canViewOfferings && (
            <Link
              href="/dashboard/academics/offerings"
              className="text-sm font-semibold text-primary underline-offset-4 hover:underline"
            >
              View Offerings →
            </Link>
          )}
        </div>
        {data.plans.length ? (
          <div className="mt-4 space-y-3">
            {data.plans.map((plan) => {
              const components = data.components.filter(
                (item) => item.fee_plan_version_id === plan.id,
              );
              const canEdit = canManage && plan.status === "ACTIVE";
              return (
                <article
                  key={plan.id}
                  className={`rounded-xl border p-4 ${editing?.id === plan.id ? "border-primary ring-1 ring-ring/30" : ""}`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <h3 className="font-semibold">
                        {offeringName(plan.offering_id)} · Version{" "}
                        {plan.version}
                      </h3>
                      <p className="text-xs text-muted-foreground">
                        {plan.billing_cycle.replaceAll("_", " ")} · effective{" "}
                        {plan.effective_from} · {plan.currency_code}
                      </p>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <StatusBadge value={plan.status} />
                      {canEdit && (
                        <button
                          type="button"
                          onClick={() => startEdit(plan)}
                          className="min-h-9 rounded-lg border px-3 text-xs font-semibold hover:bg-muted"
                        >
                          {editing?.id === plan.id ? "Editing…" : "Edit"}
                        </button>
                      )}
                    </div>
                  </div>
                  <ul className="mt-3 grid gap-2 text-sm sm:grid-cols-2 lg:grid-cols-3">
                    {components.map((item) => (
                      <li
                        key={item.id}
                        className="rounded-lg bg-muted/50 px-3 py-2"
                      >
                        {item.name}{" "}
                        <strong className="float-right">
                          {Number(item.amount).toLocaleString("en-BD", {
                            minimumFractionDigits: 2,
                          })}
                        </strong>
                        <span className="block text-xs text-muted-foreground">
                          {item.charge_type} ·{" "}
                          {item.recurrence.replaceAll("_", " ")}
                        </span>
                      </li>
                    ))}
                  </ul>
                  <p className="mt-3 text-xs text-muted-foreground">
                    Reason: {plan.change_reason}
                  </p>
                  {canManage && plan.status !== "ACTIVE" && (
                    <p className="mt-2 text-xs text-muted-foreground">
                      This plan is no longer active, so it stays as recorded
                      history. Publish a new plan for the offering to change
                      current charges.
                    </p>
                  )}
                </article>
              );
            })}
          </div>
        ) : (
          <p className="mt-5 rounded-xl border border-dashed p-6 text-sm text-muted-foreground">
            No Fee Plans published. Create a Programme Offering, then publish
            its standard charges.
          </p>
        )}
      </section>
    </>
  );
}
