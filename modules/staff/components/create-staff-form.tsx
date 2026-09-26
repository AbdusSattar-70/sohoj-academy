"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm, useWatch, type FieldPath } from "react-hook-form";
import { UserRoundPlus } from "lucide-react";
import { createStaffMember } from "@/modules/staff/actions";
import {
  createStaffInputSchema,
  type CreateStaffInput,
} from "@/modules/staff/schema";
import { Button } from "@/components/ui/button";
import { ErpFormField, ErpFormStatus } from "@/components/erp/form-field";
import { WorkflowGuide } from "@/components/erp/workflow-guide";

type RoleOption = {
  code: string;
  name: string;
  isTeachingRole: boolean;
};

type SubjectOption = {
  id: string;
  name: string;
};

const inputClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none transition focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-[invalid=true]:border-destructive";

export function CreateStaffForm({
  roles,
  subjects,
}: {
  roles: RoleOption[];
  subjects: SubjectOption[];
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null
  );

  const {
    register,
    handleSubmit,
    control,
    reset,
    setValue,
    setError,
    formState: { errors, isDirty, isValid },
  } = useForm<CreateStaffInput>({
    resolver: zodResolver(createStaffInputSchema),
    mode: "onChange",
    reValidateMode: "onChange",
    defaultValues: {
      fullName: "",
      mobile: "",
      alternateMobile: "",
      email: "",
      address: "",
      emergencyContactName: "",
      emergencyContactMobile: "",
      joinedOn: "",
      staffRoleCode: roles[0]?.code ?? "",
      subjectIds: [],
      notes: "",
    },
  });

  const roleCode = useWatch({ control, name: "staffRoleCode" });
  const teachingRole = useMemo(
    () =>
      roles.find((role) => role.code === roleCode)?.isTeachingRole ?? false,
    [roleCode, roles]
  );

  useEffect(() => {
    if (!teachingRole) {
      setValue("subjectIds", [], {
        shouldDirty: true,
        shouldValidate: true,
      });
    }
  }, [setValue, teachingRole]);

  const submit = handleSubmit((input) => {
    setMessage(null);

    startTransition(async () => {
      const result = await createStaffMember(input);

      if (result.ok) {
        reset({
          fullName: "",
          mobile: "",
          alternateMobile: "",
          email: "",
          address: "",
          emergencyContactName: "",
          emergencyContactMobile: "",
          joinedOn: "",
          staffRoleCode: roles[0]?.code ?? "",
          subjectIds: [],
          notes: "",
        });
        setMessage({
          ok: true,
          text: `Staff identity created successfully. Permanent Staff ID: ${result.staffNo}.`,
        });
        router.refresh();
        return;
      }

      if (result.field) {
        setError(result.field as FieldPath<CreateStaffInput>, {
          type: "server",
          message: result.error,
        });
      }

      setMessage({ ok: false, text: result.error });
    });
  });

  const canSubmit = isDirty && isValid && !pending;

  return (
    <section className="rounded-2xl border bg-card p-5 sm:p-6">
      <div className="mb-5">
        <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-700 dark:text-blue-300">
          Controlled workflow
        </p>
        <h2 className="mt-1 text-lg font-semibold">Create Staff Identity</h2>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Create one permanent Staff identity per real person. Roles and subject
          qualifications can change later without creating another person record.
        </p>
      </div>

      <WorkflowGuide
        steps={[
          "Enter the person's reliable identity and contact information.",
          "Choose the primary Staff role. Teacher is a role on Staff, not a separate person model.",
          "For teaching roles, select the subjects the person is qualified to teach.",
          "After saving, the system issues an immutable Staff ID and writes one correlated audit event.",
        ]}
      />

      <form
        onSubmit={submit}
        noValidate
        className="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3"
      >
        <ErpFormField
          id="staff-full-name"
          label="Full Name"
          required
          hint="Use the official academy display name for schedules, statements and records."
          error={errors.fullName?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              autoComplete="name"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("fullName")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-primary-role"
          label="Primary Role"
          required
          hint="The role describes current responsibility. It does not create a second identity."
          error={errors.staffRoleCode?.message}
        >
          {({ id, describedBy, invalid }) => (
            <select
              id={id}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("staffRoleCode")}
            >
              {roles.map((role) => (
                <option key={role.code} value={role.code}>
                  {role.name}
                </option>
              ))}
            </select>
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-joined-on"
          label="Joining Date"
          required
          hint="The effective date of the initial Staff role assignment."
          error={errors.joinedOn?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              type="date"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("joinedOn")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-mobile"
          label="Primary Mobile"
          hint="An active Staff identity cannot reuse another active staff member's mobile number."
          error={errors.mobile?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              inputMode="tel"
              autoComplete="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("mobile")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-alt-mobile"
          label="Alternate Mobile"
          error={errors.alternateMobile?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              inputMode="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("alternateMobile")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-email"
          label="Email"
          hint="Contact email only. System login access is provisioned separately."
          error={errors.email?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              type="email"
              autoComplete="email"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("email")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-address"
          label="Address"
          className="md:col-span-2"
          error={errors.address?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              autoComplete="street-address"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("address")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-emergency-name"
          label="Emergency Contact Name"
          error={errors.emergencyContactName?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("emergencyContactName")}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-emergency-mobile"
          label="Emergency Contact Mobile"
          error={errors.emergencyContactMobile?.message}
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              inputMode="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
              {...register("emergencyContactMobile")}
            />
          )}
        </ErpFormField>

        {teachingRole && (
          <fieldset className="md:col-span-2 xl:col-span-3">
            <legend className="text-sm font-semibold">Teaching Subjects</legend>
            <p className="mt-1 text-xs leading-5 text-muted-foreground">
              Select only subjects this teacher is qualified to teach. These
              assignments will later drive routine conflict checks and substitute
              suggestions.
            </p>
            <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {subjects.map((subject) => (
                <label
                  key={subject.id}
                  className="flex min-h-11 cursor-pointer items-center gap-3 rounded-xl border bg-background px-3 py-2 text-sm hover:bg-muted"
                >
                  <input
                    type="checkbox"
                    value={subject.id}
                    className="size-4"
                    {...register("subjectIds")}
                  />
                  <span>{subject.name}</span>
                </label>
              ))}
            </div>
            {errors.subjectIds?.message && (
              <p className="mt-2 text-xs font-medium text-destructive">
                {errors.subjectIds.message}
              </p>
            )}
          </fieldset>
        )}

        <ErpFormField
          id="staff-notes"
          label="Administrative Note"
          hint="Use for relevant internal context. Salary or compensation terms do not belong in free-text notes."
          className="md:col-span-2 xl:col-span-3"
          error={errors.notes?.message}
        >
          {({ id, describedBy, invalid }) => (
            <textarea
              id={id}
              rows={3}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={`${inputClass} py-2.5`}
              {...register("notes")}
            />
          )}
        </ErpFormField>

        <div className="md:col-span-2 xl:col-span-3">
          <ErpFormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end">
          {!canSubmit && !pending && (
            <p className="text-xs text-muted-foreground">
              Complete the required fields and resolve validation errors to
              enable saving.
            </p>
          )}
          <Button type="submit" disabled={!canSubmit} className="min-h-11">
            <UserRoundPlus className="mr-2 size-4" aria-hidden="true" />
            {pending ? "Creating Staff…" : "Create Staff Identity"}
          </Button>
        </div>
      </form>
    </section>
  );
}
