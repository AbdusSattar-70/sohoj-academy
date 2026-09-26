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
}: {
  action: AdmissionCommand["action"];
  data: AdmissionWorkspace;
  admissionId?: string;
  label: string;
  description: string;
  maxAmount?: number;
  identity?: { name: string; guardian: string; mobile: string };
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
    formState: { errors, isDirty, isValid },
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
                  ? (data.capacityLimit ?? undefined)
                  : undefined
            }
            {...register(key, numeric ? { valueAsNumber: true } : {})}
          />
        )
      }
    </ErpFormField>
  );
  const submit = (event: FormEvent<HTMLFormElement>) =>
    handleSubmit((value) => {
      const signature = JSON.stringify({ ...value, requestId: undefined });
      if (request.current?.signature !== signature)
        request.current = { signature, id: crypto.randomUUID() };
      const requestId = request.current.id;
      setMessage(null);
      startTransition(async () => {
        try {
          const result = await runAdmissionCommand({ ...value, requestId });
          setMessage({ ok: result.ok, text: result.message });
          if (!result.ok && result.field)
            setError(result.field as FieldPath<AdmissionCommand>, {
              message: result.message,
            });
          if (result.ok) {
            reset();
            request.current = null;
          }
        } catch {
          setMessage({
            ok: false,
            text: "The result could not be confirmed. Retry the same values; your request is protected against duplicate posting.",
          });
        }
      });
    })(event);
  return (
    <form
      noValidate
      onSubmit={submit}
      className="space-y-4 rounded-xl border bg-card p-4 print:hidden"
    >
      <div>
        <h3 className="font-semibold">{label}</h3>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      </div>
      <fieldset disabled={pending} className="grid gap-4 sm:grid-cols-2">
        {action === "CREATE_BATCH" && (
          <>
            {field(
              "offeringId",
              "Offering",
              "The batch inherits the offering’s academic year, branch, class and programme.",
              data.offerings.map((o) => ({
                id: o.id,
                name: `${o.name} · ${o.className}`,
              })),
            )}
            {field("code", "Batch Code", "Unique within the academic year.")}
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
                name: `${p.number} · ${p.name}`,
              })),
            )}
            {field(
              "batchId",
              "Batch",
              "Only batches for this Prospect’s class are offered. Full batches cannot be selected.",
              data.batches
                .filter((b) => b.classId === prospect?.classId)
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
              "Use the verified guardian name.",
            )}
            {field(
              "mobile",
              "Guardian Mobile",
              "11-digit Bangladesh mobile, beginning 01.",
            )}
          </>
        )}
        {action === "PAY" && (
          <>
            {field(
              "paymentMethodId",
              "Payment Method",
              "Select how money was actually received.",
              data.paymentMethods,
            )}
            {field(
              "amount",
              "Amount Received (BDT)",
              `Outstanding balance: ${maxAmount?.toFixed(2)}. Enter only actual money received.`,
              undefined,
              true,
            )}
            {field(
              "externalReference",
              "Transaction Reference",
              "Use the bank/mobile transaction reference when available.",
              undefined,
              false,
              false,
            )}
          </>
        )}
        {field(
          "reason",
          "Reason / Verification Note",
          "Record what you checked or why you are performing this action.",
        )}
      </fieldset>
      {prospect && action === "CREATE" && (
        <p className="text-sm text-muted-foreground">
          Guardian: {prospect.guardian} · {prospect.mobile}. Standard fees will
          be shown in the saved draft for review.
        </p>
      )}
      <Button type="submit" disabled={!isDirty || !isValid || pending}>
        {pending ? "Saving…" : label}
      </Button>
      <ErpFormStatus message={message} />
    </form>
  );
}
