"use client";

import { useMemo, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { UserRoundPlus } from "lucide-react";
import { createStaffMember } from "@/modules/staff/actions";
import type { CreateStaffInput } from "@/modules/staff/schema";
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
  const [roleCode, setRoleCode] = useState(roles[0]?.code ?? "");
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const teachingRole = useMemo(
    () => roles.find((role) => role.code === roleCode)?.isTeachingRole ?? false,
    [roleCode, roles]
  );

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);

    const input: CreateStaffInput = {
      fullName: String(formData.get("fullName") ?? ""),
      mobile: String(formData.get("mobile") ?? ""),
      alternateMobile: String(formData.get("alternateMobile") ?? ""),
      email: String(formData.get("email") ?? ""),
      address: String(formData.get("address") ?? ""),
      emergencyContactName: String(formData.get("emergencyContactName") ?? ""),
      emergencyContactMobile: String(formData.get("emergencyContactMobile") ?? ""),
      joinedOn: String(formData.get("joinedOn") ?? ""),
      staffRoleCode: roleCode,
      subjectIds: teachingRole ? formData.getAll("subjectIds").map(String) : [],
      notes: String(formData.get("notes") ?? ""),
    };

    setMessage(null);

    startTransition(async () => {
      const result = await createStaffMember(input);

      if (result.ok) {
        form.reset();
        setRoleCode(roles[0]?.code ?? "");
        setMessage({
          ok: true,
          text: `Staff identity created successfully. Permanent Staff ID: ${result.staffNo}.`,
        });
        router.refresh();
      } else {
        setMessage({ ok: false, text: result.error });
      }
    });
  }

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

      <form onSubmit={submit} className="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        <ErpFormField
          id="staff-full-name"
          label="Full Name"
          required
          hint="Use the official academy display name for schedules, statements and records."
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="fullName"
              required
              autoComplete="name"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-primary-role"
          label="Primary Role"
          required
          hint="The role describes current responsibility. It does not create a second identity."
        >
          {({ id, describedBy, invalid }) => (
            <select
              id={id}
              name="staffRoleCode"
              required
              value={roleCode}
              onChange={(event) => setRoleCode(event.target.value)}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
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
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="joinedOn"
              type="date"
              required
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-mobile"
          label="Primary Mobile"
          hint="An active Staff identity cannot reuse another active staff member's mobile number."
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="mobile"
              inputMode="tel"
              autoComplete="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField id="staff-alt-mobile" label="Alternate Mobile">
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="alternateMobile"
              inputMode="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField
          id="staff-email"
          label="Email"
          hint="Contact email only. System login access is provisioned separately."
        >
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="email"
              type="email"
              autoComplete="email"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField id="staff-address" label="Address" className="md:col-span-2">
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="address"
              autoComplete="street-address"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField id="staff-emergency-name" label="Emergency Contact Name">
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="emergencyContactName"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        <ErpFormField id="staff-emergency-mobile" label="Emergency Contact Mobile">
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="emergencyContactMobile"
              inputMode="tel"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={inputClass}
            />
          )}
        </ErpFormField>

        {teachingRole && (
          <fieldset className="md:col-span-2 xl:col-span-3">
            <legend className="text-sm font-semibold">Teaching Subjects</legend>
            <p className="mt-1 text-xs leading-5 text-muted-foreground">
              Select only subjects this teacher is qualified to teach. These
              assignments will later drive routine conflict checks and substitute suggestions.
            </p>
            <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {subjects.map((subject) => (
                <label
                  key={subject.id}
                  className="flex min-h-11 cursor-pointer items-center gap-3 rounded-xl border bg-background px-3 py-2 text-sm hover:bg-muted"
                >
                  <input
                    type="checkbox"
                    name="subjectIds"
                    value={subject.id}
                    className="size-4"
                  />
                  <span>{subject.name}</span>
                </label>
              ))}
            </div>
          </fieldset>
        )}

        <ErpFormField
          id="staff-notes"
          label="Administrative Note"
          hint="Use for relevant internal context. Salary or compensation terms do not belong in free-text notes."
          className="md:col-span-2 xl:col-span-3"
        >
          {({ id, describedBy, invalid }) => (
            <textarea
              id={id}
              name="notes"
              rows={3}
              aria-describedby={describedBy}
              aria-invalid={invalid}
              className={`${inputClass} py-2.5`}
            />
          )}
        </ErpFormField>

        <div className="md:col-span-2 xl:col-span-3">
          <ErpFormStatus message={message} />
        </div>

        <div className="md:col-span-2 xl:col-span-3 flex justify-end">
          <Button type="submit" disabled={pending} className="min-h-11">
            <UserRoundPlus className="mr-2 size-4" aria-hidden="true" />
            {pending ? "Creating Staff…" : "Create Staff Identity"}
          </Button>
        </div>
      </form>
    </section>
  );
}
