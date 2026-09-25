"use client";

import { useMemo, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { BriefcaseBusiness, CheckCircle2, UserRoundPlus } from "lucide-react";
import { createStaffMember } from "@/modules/staff/actions";
import type {
  CreateStaffInput,
} from "@/modules/staff/schema";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FormField, FormStatus } from "@/components/shared/form-field";
import { WorkflowHelp } from "@/components/shared/workflow-help";
import { useLanguage } from "@/components/providers/language-provider";
import type { AppRole } from "@/lib/constants";

export type StaffDirectoryRow = {
  id: string;
  staffNo: string;
  fullName: string;
  nameBn: string | null;
  mobile: string | null;
  email: string | null;
  status: "ACTIVE" | "INACTIVE";
  roleCode: string | null;
  roleName: string | null;
  roleNameBn: string | null;
  employmentType: string | null;
  employmentStatus: string | null;
  startsOn: string | null;
  subjects: string[];
};

export type StaffRoleOption = {
  code: string;
  name: string;
  nameBn: string | null;
  isTeachingRole: boolean;
};

type SubjectOption = {
  id: string;
  name: string;
};

type Feedback = { ok: boolean; text: string } | null;

const selectClass =
  "min-h-11 w-full rounded-xl border border-input bg-background px-3 text-sm text-foreground outline-none transition focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/30";

export function StaffManager({
  rows,
  roleOptions,
  subjects,
  viewerRole,
}: {
  rows: StaffDirectoryRow[];
  roleOptions: StaffRoleOption[];
  subjects: SubjectOption[];
  viewerRole: AppRole;
}) {
  const router = useRouter();
  const { locale } = useLanguage();
  const bn = locale === "bn";
  const tr = (en: string, bnText: string) => (bn ? bnText : en);
  const [selectedRole, setSelectedRole] = useState("TEACHER");
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<Feedback>(null);

  const isTeacher = useMemo(
    () =>
      roleOptions.find((role) => role.code === selectedRole)?.isTeachingRole ??
      selectedRole === "TEACHER",
    [roleOptions, selectedRole]
  );

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);

    const input: CreateStaffInput = {
      fullName: String(formData.get("fullName") ?? ""),
      nameBn: String(formData.get("nameBn") ?? ""),
      mobile: String(formData.get("mobile") ?? ""),
      alternateMobile: String(formData.get("alternateMobile") ?? ""),
      email: String(formData.get("email") ?? ""),
      address: String(formData.get("address") ?? ""),
      roleCode: selectedRole as CreateStaffInput["roleCode"],
      employmentType: String(
        formData.get("employmentType") ?? "PART_TIME"
      ) as CreateStaffInput["employmentType"],
      startsOn: String(formData.get("startsOn") ?? ""),
      subjectIds: isTeacher ? formData.getAll("subjectIds").map(String) : [],
      notes: String(formData.get("notes") ?? ""),
    };

    setMessage(null);

    startTransition(async () => {
      const result = await createStaffMember(input);
      if (result.ok) {
        form.reset();
        setSelectedRole("TEACHER");
        setMessage({
          ok: true,
          text: tr(
            `Staff member created successfully. Staff ID: ${result.staffNo}.`,
            `কর্মী সফলভাবে তৈরি হয়েছে। Staff ID: ${result.staffNo}।`
          ),
        });
        router.refresh();
      } else {
        setMessage({ ok: false, text: result.error });
      }
    });
  }

  return (
    <div className="space-y-6">
      <section className="rounded-2xl border bg-card p-5 sm:p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <div className="flex items-center gap-2 text-sm font-semibold text-blue-700 dark:text-blue-300">
              <BriefcaseBusiness className="size-4" aria-hidden="true" />
              {tr("Central Staff Identity", "কেন্দ্রীয় Staff Identity")}
            </div>
            <h2 className="mt-2 text-xl font-semibold">
              {tr("Staff Directory", "কর্মী ডিরেক্টরি")}
            </h2>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">
              {tr(
                "Every employee or contracted worker has one permanent Staff ID. Teacher, Operator, Accountant and other responsibilities are role assignments on that identity.",
                "প্রত্যেক কর্মী বা চুক্তিভিত্তিক সদস্যের একটি স্থায়ী Staff ID থাকবে। Teacher, Operator, Accountant ইত্যাদি পরিচয় আলাদা ব্যক্তি নয়—একই Staff identity-এর role assignment।"
              )}
            </p>
          </div>

          <div className="rounded-xl border bg-muted/40 px-4 py-3 text-sm">
            <p className="font-semibold">{rows.length}</p>
            <p className="text-xs text-muted-foreground">
              {tr("staff identities", "Staff identity")}
            </p>
          </div>
        </div>

        {viewerRole === "ADMIN" && (
          <>
            <WorkflowHelp
              title={tr("Creating staff correctly", "Staff সঠিকভাবে তৈরি করার নিয়ম")}
              steps={[
                tr(
                  "Create one Staff identity per real person. Do not create a second person record when their responsibility changes.",
                  "প্রতি বাস্তব ব্যক্তির জন্য একটি Staff identity তৈরি করুন। দায়িত্ব বদলালে দ্বিতীয় ব্যক্তি রেকর্ড তৈরি করবেন না।"
                ),
                tr(
                  "Choose the person's primary role and employment type. These can later be versioned without changing their permanent Staff ID.",
                  "ব্যক্তির primary role ও employment type নির্বাচন করুন। ভবিষ্যতে এগুলো পরিবর্তন হলেও স্থায়ী Staff ID বদলাবে না।"
                ),
                tr(
                  "For Teachers, assign the subjects they are qualified to teach. Scheduling and substitution will use these assignments later.",
                  "Teacher হলে তিনি যে বিষয়গুলো পড়াতে সক্ষম সেগুলো নির্বাচন করুন। ভবিষ্যৎ routine ও substitution এই assignment ব্যবহার করবে।"
                ),
              ]}
            />

            <form onSubmit={submit} className="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
              <FormField
                id="staff-full-name"
                label={tr("Full Name", "পূর্ণ নাম")}
                required
                hint={tr(
                  "Use the official name the academy should display in schedules, statements and records.",
                  "রুটিন, statement ও রেকর্ডে যে অফিসিয়াল নাম দেখানো হবে সেটি দিন।"
                )}
              >
                <Input
                  id="staff-full-name"
                  name="fullName"
                  className="min-h-11"
                  autoComplete="name"
                  required
                />
              </FormField>

              <FormField
                id="staff-name-bn"
                label={tr("Name (Bangla)", "নাম (বাংলা)")}
              >
                <Input id="staff-name-bn" name="nameBn" className="min-h-11" />
              </FormField>

              <FormField
                id="staff-mobile"
                label={tr("Primary Mobile", "প্রধান মোবাইল")}
                hint={tr(
                  "An active staff member cannot reuse another active staff member's mobile number.",
                  "একজন active কর্মীর মোবাইল নম্বর অন্য active কর্মীর জন্য পুনরায় ব্যবহার করা যাবে না।"
                )}
              >
                <Input
                  id="staff-mobile"
                  name="mobile"
                  className="min-h-11"
                  inputMode="tel"
                  autoComplete="tel"
                />
              </FormField>

              <FormField
                id="staff-alt-mobile"
                label={tr("Alternate Mobile", "বিকল্প মোবাইল")}
              >
                <Input
                  id="staff-alt-mobile"
                  name="alternateMobile"
                  className="min-h-11"
                  inputMode="tel"
                />
              </FormField>

              <FormField
                id="staff-email"
                label={tr("Email", "ইমেইল")}
                hint={tr(
                  "This is contact information. Login-account linking is managed separately.",
                  "এটি যোগাযোগের তথ্য। Login account linking আলাদাভাবে পরিচালিত হবে।"
                )}
              >
                <Input
                  id="staff-email"
                  name="email"
                  type="email"
                  className="min-h-11"
                  autoComplete="email"
                />
              </FormField>

              <FormField
                id="staff-starts-on"
                label={tr("Employment Starts", "কর্মসংস্থান শুরুর তারিখ")}
                required
              >
                <Input
                  id="staff-starts-on"
                  name="startsOn"
                  type="date"
                  className="min-h-11"
                  required
                />
              </FormField>

              <FormField
                id="staff-role"
                label={tr("Primary Role", "Primary Role")}
                required
                hint={tr(
                  "Role describes responsibility; it does not create a second person identity.",
                  "Role দায়িত্ব বোঝায়; এটি আলাদা person identity তৈরি করে না।"
                )}
              >
                <select
                  id="staff-role"
                  name="roleCode"
                  value={selectedRole}
                  onChange={(event) => setSelectedRole(event.target.value)}
                  className={selectClass}
                  required
                >
                  {roleOptions.map((role) => (
                    <option key={role.code} value={role.code}>
                      {bn && role.nameBn ? role.nameBn : role.name}
                    </option>
                  ))}
                </select>
              </FormField>

              <FormField
                id="staff-employment-type"
                label={tr("Employment Type", "Employment Type")}
                required
              >
                <select
                  id="staff-employment-type"
                  name="employmentType"
                  className={selectClass}
                  defaultValue="PART_TIME"
                  required
                >
                  <option value="FULL_TIME">{tr("Full-time", "পূর্ণকালীন")}</option>
                  <option value="PART_TIME">{tr("Part-time", "খণ্ডকালীন")}</option>
                  <option value="CONTRACT">{tr("Contract", "চুক্তিভিত্তিক")}</option>
                  <option value="VISITING">{tr("Visiting", "ভিজিটিং")}</option>
                  <option value="OTHER">{tr("Other", "অন্যান্য")}</option>
                </select>
              </FormField>

              <FormField
                id="staff-address"
                label={tr("Address", "ঠিকানা")}
              >
                <Input id="staff-address" name="address" className="min-h-11" />
              </FormField>

              {isTeacher && (
                <fieldset className="md:col-span-2 xl:col-span-3">
                  <legend className="text-sm font-semibold">
                    {tr("Teaching Subjects", "পাঠদানের বিষয়সমূহ")}
                  </legend>
                  <p className="mt-1 text-xs leading-5 text-muted-foreground">
                    {tr(
                      "Select subjects this teacher is qualified to teach. This becomes structured academic master data.",
                      "এই শিক্ষক যে বিষয়গুলো পড়াতে সক্ষম সেগুলো নির্বাচন করুন। এটি structured academic master data হিসেবে সংরক্ষিত হবে।"
                    )}
                  </p>
                  <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                    {subjects.map((subject) => (
                      <label
                        key={subject.id}
                        className="flex min-h-11 cursor-pointer items-center gap-3 rounded-xl border px-3 py-2 text-sm hover:bg-muted"
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

              <FormField
                id="staff-notes"
                label={tr("Administrative Note", "প্রশাসনিক নোট")}
                hint={tr(
                  "Optional internal context. Compensation terms should not be stored here.",
                  "ঐচ্ছিক internal context। Compensation terms এখানে লিখবেন না।"
                )}
                className="md:col-span-2 xl:col-span-3"
              >
                <textarea
                  id="staff-notes"
                  name="notes"
                  rows={3}
                  className="w-full rounded-xl border border-input bg-background px-3 py-2.5 text-sm outline-none focus-visible:ring-3 focus-visible:ring-ring/30"
                />
              </FormField>

              <div className="md:col-span-2 xl:col-span-3">
                <FormStatus message={message} />
              </div>

              <div className="md:col-span-2 xl:col-span-3 flex justify-end">
                <Button type="submit" disabled={pending} className="min-h-11">
                  <UserRoundPlus className="mr-2 size-4" aria-hidden="true" />
                  {pending
                    ? tr("Creating Staff…", "Staff তৈরি হচ্ছে…")
                    : tr("Create Staff Identity", "Staff Identity তৈরি করুন")}
                </Button>
              </div>
            </form>
          </>
        )}
      </section>

      <section className="overflow-hidden rounded-2xl border bg-card">
        <div className="border-b px-5 py-4 sm:px-6">
          <h3 className="font-semibold">
            {tr("Current Staff", "বর্তমান কর্মীবৃন্দ")}
          </h3>
          <p className="mt-1 text-xs text-muted-foreground">
            {tr(
              "Permanent Staff ID remains stable even when role or employment terms change.",
              "Role বা employment terms পরিবর্তন হলেও স্থায়ী Staff ID অপরিবর্তিত থাকবে।"
            )}
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[900px] text-sm">
            <thead>
              <tr className="border-b bg-muted/40 text-left">
                <th className="p-3">{tr("Staff ID", "Staff ID")}</th>
                <th className="p-3">{tr("Name", "নাম")}</th>
                <th className="p-3">{tr("Role", "Role")}</th>
                <th className="p-3">{tr("Employment", "Employment")}</th>
                <th className="p-3">{tr("Subjects", "বিষয়")}</th>
                <th className="p-3">{tr("Contact", "যোগাযোগ")}</th>
                <th className="p-3">{tr("Status", "অবস্থা")}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-b align-top">
                  <td className="p-3 font-semibold">{row.staffNo}</td>
                  <td className="p-3">
                    <p className="font-medium">{row.fullName}</p>
                    {row.nameBn && (
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {row.nameBn}
                      </p>
                    )}
                  </td>
                  <td className="p-3">
                    {bn && row.roleNameBn
                      ? row.roleNameBn
                      : row.roleName ?? row.roleCode ?? "—"}
                  </td>
                  <td className="p-3">
                    <p>{row.employmentType?.replaceAll("_", " ") ?? "—"}</p>
                    {row.startsOn && (
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {tr("Since", "শুরু")} {row.startsOn}
                      </p>
                    )}
                  </td>
                  <td className="p-3">
                    {row.subjects.length ? row.subjects.join(", ") : "—"}
                  </td>
                  <td className="p-3">
                    <p>{row.mobile ?? "—"}</p>
                    {row.email && (
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {row.email}
                      </p>
                    )}
                  </td>
                  <td className="p-3">
                    <span className="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium">
                      <CheckCircle2 className="size-3.5" aria-hidden="true" />
                      {row.employmentStatus ?? row.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {!rows.length && (
            <p className="p-8 text-center text-sm text-muted-foreground">
              {tr("No staff identities recorded yet.", "এখনও কোনো Staff identity নেই।")}
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
