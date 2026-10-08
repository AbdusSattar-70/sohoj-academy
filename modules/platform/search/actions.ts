"use server";
import { requireErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
export type SearchRecord = {
  id: string;
  title: string;
  detail: string;
  href: string;
};
export async function searchErpRecords(
  raw: string,
): Promise<{ rows: SearchRecord[]; failed: boolean }> {
  const context = await requireErpContext();
  if (context.status !== "ACTIVE") return { rows: [], failed: false };
  const q = raw
    .trim()
    .replace(/[^\p{L}\p{N}\s@+-]/gu, " ")
    .slice(0, 80)
    .trim();
  if (q.length < 2) return { rows: [], failed: false };
  const db = await platformClient();
  // Manager directory searches remain restricted to admin in this delivery.
  // Teachers receive their own assigned sessions; a client-supplied role never grants scope.
  const config: {
    permission: string;
    table: string;
    fields: string;
    search: string[];
    label: string;
    href: (id: string) => string;
  }[] = [
    {
      permission: "students.view",
      table: "students",
      fields: "id,student_no,full_name",
      search: ["student_no", "full_name"],
      label: "Student",
      href: (id) => `/dashboard/students/${id}`,
    },
    {
      permission: "crm.prospects.view",
      table: "prospects",
      fields: "id,prospect_no,student_name,mobile",
      search: ["prospect_no", "student_name", "mobile"],
      label: "Application",
      href: (id) => `/dashboard/crm/prospects/${id}`,
    },
    {
      permission: "staff.view",
      table: "staff",
      fields: "id,staff_no,full_name,mobile,email",
      search: ["staff_no", "full_name", "mobile", "email"],
      label: "Staff",
      href: () => "/dashboard/staff",
    },
    {
      permission: "academics.view",
      table: "programme_offerings",
      fields: "id,code,name",
      search: ["code", "name"],
      label: "Programme offering",
      href: () => "/dashboard/academics/offerings",
    },
    {
      permission: "finance.view",
      table: "admission_invoices",
      fields: "id,invoice_no",
      search: ["invoice_no"],
      label: "Invoice",
      href: (id) => `/dashboard/finance/billing/${id}/print`,
    },
    {
      permission: "admissions.view",
      table: "admission_cases",
      fields: "id,admission_no",
      search: ["admission_no"],
      label: "Admission",
      href: (id) => `/dashboard/admissions/${id}`,
    },
    {
      permission: "system.master_data.manage",
      table: "classes",
      fields: "id,code,name",
      search: ["code", "name"],
      label: "Class",
      href: () => "/dashboard/academics/settings",
    },
    {
      permission: "academics.view",
      table: "batches",
      fields: "id,code,name",
      search: ["code", "name"],
      label: "Batch",
      href: () => "/dashboard/academics/batches",
    },
    {
      permission: "referrals.manage",
      table: "referral_people",
      fields: "id,full_name,mobile",
      search: ["full_name", "mobile"],
      label: "Referrer",
      href: (id) => `/dashboard/referrals?person=${id}`,
    },
  ];
  if (!context.roles.includes("ADMIN")) {
    if (!context.staffId || !context.permissions.includes("academics.view"))
      return { rows: [], failed: false };
    const r = await db
      .from("class_sessions")
      .select("id,session_date,planned_scope")
      .eq("teacher_id", context.staffId)
      .ilike("planned_scope", `%${q}%`)
      .order("session_date", { ascending: false })
      .limit(6);
    return {
      failed: Boolean(r.error),
      rows: (r.data ?? []).map((row) => ({
        id: row.id,
        title: row.planned_scope,
        detail: String(row.session_date),
        href: `/dashboard/academics/sessions/${row.id}`,
      })),
    };
  }
  const contactSearch = async (): Promise<{
    rows: SearchRecord[];
    failed: boolean;
  }> => {
    if (
      !context.permissions.includes("students.view") ||
      !/^\+?[0-9 -]{5,}$/.test(q)
    )
      return { rows: [], failed: false };
    const guardians = await db
      .from("guardians")
      .select("id")
      .or(`mobile.ilike.%${q}%,alternate_mobile.ilike.%${q}%`)
      .limit(5);
    if (guardians.error || !guardians.data?.length)
      return { rows: [], failed: Boolean(guardians.error) };
    const linked = await db
      .from("student_guardians")
      .select("students(id,student_no,full_name)")
      .in(
        "guardian_id",
        guardians.data.map((row) => row.id),
      )
      .limit(5);
    const rows = (linked.data ?? []) as unknown as {
      students: { id: string; student_no: string; full_name: string } | null;
    }[];
    return {
      failed: Boolean(linked.error),
      rows: rows
        .filter((row) => row.students)
        .map((row) => ({
          id: row.students!.id,
          title: row.students!.full_name,
          detail: `Guardian contact · ${row.students!.student_no}`,
          href: `/dashboard/students/${row.students!.id}`,
        })),
    };
  };
  const receiptSearch = async (): Promise<{
    rows: SearchRecord[];
    failed: boolean;
  }> => {
    if (
      !context.permissions.includes("finance.view") ||
      !/^RCT[- ]?[0-9]*$/i.test(q)
    )
      return { rows: [], failed: false };
    const payments = await db
      .from("admission_payments")
      .select("id,receipt_no")
      .ilike("receipt_no", `%${q}%`)
      .limit(5);
    if (payments.error || !payments.data?.length)
      return { rows: [], failed: Boolean(payments.error) };
    const allocations = await db
      .from("admission_payment_allocations")
      .select("payment_id,admission_invoices(admission_id)")
      .in(
        "payment_id",
        payments.data.map((row) => row.id),
      )
      .limit(10);
    const rows = (allocations.data ?? []) as unknown as {
      payment_id: string;
      admission_invoices: { admission_id: string } | null;
    }[];
    return {
      failed: Boolean(allocations.error),
      rows: rows
        .filter((row) => row.admission_invoices)
        .map((row) => {
          const payment = payments.data!.find((p) => p.id === row.payment_id)!;
          return {
            id: payment.id,
            title: payment.receipt_no,
            detail: "Payment receipt",
            href: `/dashboard/admissions/${row.admission_invoices!.admission_id}/print?receipt=${encodeURIComponent(payment.receipt_no)}`,
          };
        }),
    };
  };
  const results = await Promise.all(
    config
      .filter((c) => context.permissions.includes(c.permission))
      .map(async (c) => {
        const r = await db
          .from(c.table)
          .select(c.fields)
          .or(c.search.map((field) => `${field}.ilike.%${q}%`).join(","))
          .limit(5);
        const rows = (r.data ?? []) as unknown as Record<string, string>[];
        return {
          failed: Boolean(r.error),
          rows: rows
            .filter((row) => /^[0-9a-f-]{36}$/i.test(row.id ?? ""))
            .map((row) => ({
              id: row.id,
              title:
                row.full_name ??
                row.student_name ??
                row.name ??
                row.invoice_no ??
                row.admission_no,
              detail: `${c.label} · ${row.student_no ?? row.prospect_no ?? row.staff_no ?? row.code ?? row.invoice_no ?? row.admission_no ?? row.mobile ?? ""}`,
              href: c.href(row.id),
            })),
        };
      }),
  );
  const related = await Promise.all([contactSearch(), receiptSearch()]);
  const all = [...results, ...related];
  const unique = new Map(
    all.flatMap((r) => r.rows).map((row) => [row.href + row.id, row]),
  );
  return { rows: [...unique.values()], failed: all.some((r) => r.failed) };
}
