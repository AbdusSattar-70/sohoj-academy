"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm, type FieldPath } from "react-hook-form";
import { Button } from "@/components/ui/button";
import { ErpFormField, ErpFormStatus } from "@/components/erp/form-field";
import { createProgrammeOffering } from "@/modules/offerings/actions";
import { createOfferingSchema, type CreateOfferingInput } from "@/modules/offerings/schema";
import type { OfferingOverview } from "@/modules/offerings/queries";

const controlClass = "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm focus-visible:ring-2 focus-visible:ring-ring/30 aria-[invalid=true]:border-destructive";

export function OfferingForm({ data }: { data: OfferingOverview }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const { register, handleSubmit, reset, setError, formState: { errors, isDirty, isValid } } = useForm<CreateOfferingInput>({
    resolver: zodResolver(createOfferingSchema), mode: "onChange",
    defaultValues: { branchId: "", academicYearId: "", classId: "", programId: "", groupId: "", code: "", name: "", reason: "" },
  });
  const choices = [
    { key: "branchId", label: "Branch", hint: "The campus where classes will run.", values: data.branches },
    { key: "academicYearId", label: "Academic Year", hint: "Choose the year this offering belongs to.", values: data.years },
    { key: "classId", label: "Class", hint: "The eligible student class.", values: data.classes },
    { key: "programId", label: "Programme", hint: "The academic product being offered.", values: data.programs },
  ] as const;
  const submit = handleSubmit((input) => {
    setMessage(null);
    startTransition(async () => {
      const result = await createProgrammeOffering(input);
      if (!result.ok) {
        if (result.field) setError(result.field as FieldPath<CreateOfferingInput>, { message: result.error });
        setMessage({ ok: false, text: result.error });
        return;
      }
      reset();
      setMessage({ ok: true, text: "Offering created as a draft. Publish its Fee Plan to make it active." });
      router.refresh();
    });
  });

  return <section className="rounded-2xl border bg-card p-5 sm:p-6">
    <h2 className="text-lg font-semibold">Create Programme Offering</h2>
    <p className="mt-1 text-sm text-muted-foreground">Select the academic context first. The standard price is set separately in a versioned Fee Plan.</p>
    <form onSubmit={submit} noValidate className="mt-5 grid gap-5 md:grid-cols-2">
      {choices.map((choice) => <ErpFormField key={choice.key} id={`offering-${choice.key}`} label={choice.label} required hint={choice.hint} error={errors[choice.key]?.message}>
        {({ id, describedBy, invalid }) => <select id={id} aria-describedby={describedBy} aria-invalid={invalid} className={controlClass} {...register(choice.key)}>
          <option value="">Select {choice.label}</option>
          {choice.values.map((option) => <option key={option.id} value={option.id}>{option.name}</option>)}
        </select>}
      </ErpFormField>)}
      <ErpFormField id="offering-group" label="Academic Group" hint="Choose Science when this class is restricted to the Science group." error={errors.groupId?.message}>
        {({ id, describedBy, invalid }) => <select id={id} aria-describedby={describedBy} aria-invalid={invalid} className={controlClass} {...register("groupId")}>
          <option value="">All groups / not applicable</option>
          {data.groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}
        </select>}
      </ErpFormField>
      <ErpFormField id="offering-code" label="Offering Code" required hint="A short unique code within the academic year, e.g. SSC10-SCI-MAIN." error={errors.code?.message}>
        {({ id, describedBy, invalid }) => <input id={id} aria-describedby={describedBy} aria-invalid={invalid} className={controlClass} {...register("code")} />}
      </ErpFormField>
      <ErpFormField id="offering-name" label="Display Name" required hint="The name staff will recognize in Admission." error={errors.name?.message}>
        {({ id, describedBy, invalid }) => <input id={id} aria-describedby={describedBy} aria-invalid={invalid} className={controlClass} {...register("name")} />}
      </ErpFormField>
      <ErpFormField id="offering-reason" label="Creation Reason" required hint="This explanation is saved with the audit event." error={errors.reason?.message}>
        {({ id, describedBy, invalid }) => <input id={id} aria-describedby={describedBy} aria-invalid={invalid} className={controlClass} {...register("reason")} />}
      </ErpFormField>
      <div className="md:col-span-2 flex flex-wrap items-center gap-4">
        <Button type="submit" disabled={!isDirty || !isValid || pending}>{pending ? "Creating…" : "Create Draft Offering"}</Button>
        <ErpFormStatus message={message} />
      </div>
    </form>
  </section>;
}
