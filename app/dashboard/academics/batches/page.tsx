import Link from "next/link";
import { PageHeader } from "@/components/erp/page-header";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { getAdmissionWorkspace } from "@/modules/admissions/queries";
import { AdmissionCommandForm } from "@/modules/admissions/components/command-form";
export default async function BatchesPage() {
  const context = await requirePermission("academics.view");
  const data = await getAdmissionWorkspace();
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Academic Setup"
        title="Batches"
        description="Create batches under active Programme Offerings. Seat availability is checked again when enrollment activates."
      />
      <p className="text-sm">
        <Link className="underline" href="/dashboard/academics/offerings">
          Programme Offerings
        </Link>{" "}
        → Fee Plan → Batch → Admission
      </p>
      {context.permissions.includes("academics.manage") && (
        <AdmissionCommandForm
          action="CREATE_BATCH"
          data={data}
          label="Create Batch"
          description="Choose an offering with a published Fee Plan. Capacity must fit the active academy policy."
        />
      )}
      <div className="grid gap-4 md:grid-cols-2">
        {data.batches.map((b) => (
          <article key={b.id} className="rounded-xl border bg-card p-5">
            <h2 className="font-semibold">{b.name}</h2>
            <p className="text-sm text-muted-foreground">
              {b.code} ·{" "}
              {data.offerings.find((o) => o.id === b.offeringId)?.name}
            </p>
            <p className="mt-3">
              {b.occupied} enrolled / {b.capacity} seats
            </p>
          </article>
        ))}
      </div>
      {!data.batches.length && (
        <p className="rounded-xl border border-dashed p-6 text-sm">
          No batches yet. Publish a Fee Plan for an offering, then create a
          batch here.
        </p>
      )}
    </div>
  );
}
