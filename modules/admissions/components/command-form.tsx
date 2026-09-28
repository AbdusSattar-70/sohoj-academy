"use client";
import { useRef, useState, useTransition, type FormEvent } from "react";
import { useForm, useWatch, type FieldPath } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { ErpFormField, ErpFormStatus } from "@/components/erp/form-field";
import {
  commandSchema,
  type AdmissionCommand,
  type AdmissionWorkspace,
} from "../schema";
import { runAdmissionCommand } from "../actions";
const inputClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm focus-visible:ring-2 focus-visible:ring-ring aria-[invalid=true]:border-destructive";
type Option = { id: string; name: string; disabled?: boolean };
export function AdmissionCommandForm({
  action,
  data,
  admissionId,
  label,
  description,
  maxAmount,
  identity,
  defaultProspectId,
  initialBatch,
  onSuccess,
  onCancel,
}: {
  action: AdmissionCommand["action"];
  data: AdmissionWorkspace;
  admissionId?: string;
  label: string;
  description: string;
  maxAmount?: number;
  identity?: { name: string; guardian: string; mobile: string };
  defaultProspectId?: string;
  initialBatch?: { id: string; code: string; name: string; capacity: number };
  onSuccess?: () => void;
  onCancel?: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null,
  );
  const request = useRef<{ signature: string; id: string } | null>(null);
  const {
    register,
    handleSubmit,
    control,
    setValue,
    reset,
    setError,
    formState: { errors, isDirty },
  } = useForm<AdmissionCommand>({
    resolver: zodResolver(commandSchema),
    mode: "onChange",
    defaultValues: {
      action,
      admissionId,
      requestId: crypto.randomUUID(),
      reason: "",
      ...(identity
        ? {
            studentName: identity.name,
            guardianName: identity.guardian,
            mobile: identity.mobile,
          }
        : {}),
      ...(action === "CREATE_BATCH"
        ? { capacity: data.capacityLimit ?? undefined }
        : {}),
      ...(action === "EDIT_BATCH" && initialBatch
        ? { batchId: initialBatch.id, code: initialBatch.code, name: initialBatch.name, capacity: initialBatch.capacity }
        : {}),
      ...(action === "CREATE" && defaultProspectId
        ? { prospectId: defaultProspectId }
        : {}),
    },
  });
  const prospectId = useWatch({ control, name: "prospectId" });
  const prospect = data.prospects.find((p) => p.id === prospectId);
  const field = (
    key: FieldPath<AdmissionCommand>,
    title: string,
    hint: string,
    options?: Option[],
    numeric = false,
    required = true,
  ) => (
    <ErpFormField
      key={key}
      id={`${action}-${admissionId ?? "new"}-${key}`}
      label={title}
      required={required}
      hint={hint}
      error={errors[key]?.message}
    >
      {({ id, describedBy, invalid }) =>
        options ? (
          <select
            id={id}
            className={inputClass}
            aria-describedby={describedBy}
            aria-invalid={invalid}
            {...register(key, {
              onChange: () => {
                if (key === "prospectId")
                  setValue("batchId", "", {
                    shouldDirty: true,
                    shouldValidate: true,
                  });
              },
            })}
          >
            <option value="">Select {title}</option>
            {options.map((o) => (
              <option key={o.id} value={o.id} disabled={o.disabled}>
                {o.name}
              </option>
            ))}
          </select>
        ) : (
          <input
            id={id}
            className={inputClass}
            aria-describedby={describedBy}
            aria-invalid={invalid}
            type={numeric ? "number" : "text"}
            step={key === "amount" ? "0.01" : numeric ? "1" : undefined}
            min={numeric ? 0 : undefined}
            max={
              key === "amount"
                ? maxAmount
                : key === "capacity"
                  ? (data.capacityLimit ?? 500)
                  : undefined
            }
            {...register(key, { valueAsNumber: numeric })}
          />
        )
      }
    </ErpFormField>
  );
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    void handleSubmit((values) => {
      const signature = JSON.stringify(values);
      if (!request.current || request.current.signature !== signature) {
        request.current = { signature, id: crypto.randomUUID() };
      }
      const payload = { ...values, requestId: request.current.id };
      setMessage(null);
      startTransition(async () => {
        const result = await runAdmissionCommand(payload);
        if (!result.ok) {
          if (result.field)
            setError(result.field as FieldPath<AdmissionCommand>, {
              message: result.message,
            });
          setMessage({ ok: false, text: result.message });
          return;
        }
        request.current = null;
        onSuccess?.();
        reset({
          action,
          admissionId,
          requestId: crypto.randomUUID(),
          reason: "",
          ...(identity
            ? {
                studentName: identity.name,
                guardianName: identity.guardian,
                mobile: identity.mobile,
              }
            : {}),
          ...(action === "CREATE_BATCH"
            ? { capacity: data.capacityLimit ?? undefined }
            : {}),
          ...(action === "CREATE" && defaultProspectId
            ? { prospectId: defaultProspectId }
            : {}),
        });
        setMessage({ ok: true, text: result.message ?? "Saved." });
      });
    })();
  };
  return (
    <form onSubmit={submit} className="space-y-4 rounded-2xl border p-5">
      <div>
        <h3 className="font-semibold">{label}</h3>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {(action === "CREATE_BATCH" || action === "EDIT_BATCH") && (
          <>
            {action === "CREATE_BATCH" && field(
              "offeringId",
              "Offering",
              "Choose the programme offering this batch belongs to.",
              data.offerings.map((o) => ({
                id: o.id,
                name: `${o.name} · ${o.className}`,
              })),
            )}
            {field(
              "code",
              "Batch Code",
              "Short operational code used in schedules and reports.",
            )}
            {field(
              "name",
              "Batch Name",
              "Use the name staff and guardians recognize.",
            )}
            {field(
              "capacity",
              "Capacity",
              `Current policy maximum: ${data.capacityLimit ?? "not configured"}.`,
              undefined,
              true,
            )}
            {action === "EDIT_BATCH" && <input type="hidden" {...register("batchId")} />}
          </>
        )}
        {action === "CREATE" && (
          <>
            {field(
              "prospectId",
              "Prospect",
              "Select an existing enquiry. Identity and guardian details are inherited.",
              data.prospects.map((p) => ({
                id: p.id,
                name: `${p.number} · ${p.name} · ${p.mobile}`,
              })),
            )}
            {field(
              "batchId",
              "Batch",
              "Only batches for this Prospect’s class are offered. Full batches cannot be selected.",
              data.batches
                .filter((b) => b.isActive && b.classId === prospect?.classId)
                .map((b) => ({
                  id: b.id,
                  name: `${b.name} · ${b.occupied}/${b.capacity} seats`,
                  disabled:
                    b.occupied >=
                    Math.min(b.capacity, data.capacityLimit ?? b.capacity),
                })),
            )}
          </>
        )}
        {action === "EDIT_DRAFT" && (
          <>
            {field(
              "studentName",
              "Student Name",
              "Use the verified student name.",
            )}
            {field(
              "guardianName",
              "Guardian Name",
              "Primary guardian for contact and billing.",
            )}
            {field("mobile", "Mobile", "Bangladesh mobile, 01XXXXXXXXX.")}
          </>
        )}
        {action === "PAY" && (
          <>
            {field(
              "amount",
              "Amount received",
              maxAmount
                ? `Outstanding balance about BDT ${maxAmount.toFixed(2)}.`
                : "Enter the amount actually received.",
              undefined,
              true,
            )}
            {field(
              "paymentMethodId",
              "Payment method",
              "How the payment was received.",
              data.paymentMethods.map((m) => ({ id: m.id, name: m.name })),
            )}
            {field(
              "externalReference",
              "External reference",
              "Optional bank or gateway reference.",
              undefined,
              false,
              false,
            )}
          </>
        )}
        {field(
          "reason",
          "Reason",
          "Short operational reason for the audit trail.",
        )}
      </div>
      {prospect && action === "CREATE" && (
        <div className="rounded-xl border bg-muted/30 p-4 text-sm leading-6">
          <p className="font-medium text-foreground">
            Verified CRM data will seed this draft
          </p>
          <p className="mt-1 text-muted-foreground">
            {prospect.number} · {prospect.name}
          </p>
          <p className="mt-1 text-muted-foreground">
            Guardian: {prospect.guardian} · {prospect.mobile}
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            Student, guardian and contact details are inherited from the
            Prospect. Choose an eligible batch, then review fees before
            acceptance.
          </p>
        </div>
      )}
      <ErpFormStatus message={message} />
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={pending || !isDirty}>
          {pending ? "Working…" : label}
        </Button>
        {onCancel && (
          <Button type="button" variant="outline" disabled={pending} onClick={onCancel}>
            Cancel
          </Button>
        )}
      </div>
    </form>
  );
}
