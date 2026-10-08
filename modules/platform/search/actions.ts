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
      permission: "crm.view",
      table: "prospects",
      fields: "id,prospect_no,student_name,mobile",
      search: ["prospect_no", "student_name", "mobile"],
      label: "Application",
      href: (id) => `/dashboard/crm/prospects/${id}`,
    },
    {
      permission: "staff.view",
      table: "staff",
      fields: "id,staff_no,full_name",
      search: ["staff_no", "full_name"],
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
      permission: "finance.billing.view",
      table: "invoices",
      fields: "id,invoice_no",
      search: ["invoice_no"],
      label: "Invoice",
      href: (id) => `/dashboard/finance/billing/${id}/print`,
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
                row.full_name ?? row.student_name ?? row.name ?? row.invoice_no,
              detail: `${c.label} · ${row.student_no ?? row.prospect_no ?? row.staff_no ?? row.code ?? row.invoice_no}`,
              href: c.href(row.id),
            })),
        };
      }),
  );
  return {
    rows: results.flatMap((r) => r.rows),
    failed: results.some((r) => r.failed),
  };
}
