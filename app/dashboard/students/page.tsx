import Link from "next/link";
import { GraduationCap, Search } from "lucide-react";
import { EmptyState } from "@/components/erp/empty-state";
import { PageHeader } from "@/components/erp/page-header";
import { StatusBadge } from "@/components/erp/status-badge";
import { getStudentList } from "@/modules/students/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";

export default async function StudentsPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; q?: string }>;
}) {
  await requirePermission("students.view");
  const params = await searchParams;
  const page = Math.max(1, Number.parseInt(params.page ?? "1", 10) || 1);
  const query = params.q?.trim() ?? "";
  const result = await getStudentList({ page, query });
  const rows = result.rows;
  const pageCount = Math.max(1, Math.ceil(result.total / result.pageSize));
  const pageHref = (nextPage: number) => {
    const values = new URLSearchParams();
    if (query) values.set("q", query);
    values.set("page", String(nextPage));
    return `/dashboard/students?${values.toString()}`;
  };

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Student Core"
        title="Students"
        description="Permanent Student identities remain stable across academic years, batches, fee terms and lifecycle changes."
      />

      <section className="rounded-2xl border bg-card p-4">
        <form className="flex flex-col gap-3 sm:flex-row" role="search">
          <label className="relative flex-1">
            <span className="sr-only">Search students</span>
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
            <input name="q" defaultValue={query} placeholder="Search student ID, name or school" className="min-h-11 w-full rounded-xl border bg-background pl-9 pr-3 text-sm" />
          </label>
          <button className="min-h-11 rounded-xl bg-primary px-4 text-sm font-semibold text-primary-foreground">Search</button>
        </form>
      </section>

      {rows.length ? (
        <section className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[760px] text-sm">
              <thead>
                <tr className="border-b bg-muted/40 text-left">
                  <th className="px-4 py-3 font-semibold">Student ID</th>
                  <th className="px-4 py-3 font-semibold">Name</th>
                  <th className="px-4 py-3 font-semibold">School</th>
                  <th className="px-4 py-3 font-semibold">Status</th>
                  <th className="px-4 py-3 font-semibold">Created</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b hover:bg-muted/30">
                    <td className="px-4 py-3 font-semibold">
                      <Link
                        className="underline underline-offset-4"
                        href={`/dashboard/students/${row.id}`}
                      >
                        {row.studentNo}
                      </Link>
                    </td>
                    <td className="px-4 py-3">{row.fullName}</td>
                    <td className="px-4 py-3">{row.schoolName}</td>
                    <td className="px-4 py-3">
                      <StatusBadge value={row.status} />
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(row.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex items-center justify-between border-t px-4 py-3 text-sm text-muted-foreground">
            <span>{result.total} student records · Page {result.page} of {pageCount}</span>
            <span className="flex gap-2">
              {page > 1 && <Link className="rounded-lg border px-3 py-2" href={pageHref(page - 1)}>Previous</Link>}
              {page < pageCount && <Link className="rounded-lg border px-3 py-2" href={pageHref(page + 1)}>Next</Link>}
            </span>
          </div>
        </section>
      ) : (
        <EmptyState
          icon={GraduationCap}
          title="No admitted students yet"
          description="Students will appear here after the v2 admission workflow creates a permanent Student identity. Prospect records remain separate until conversion."
        />
      )}
    </div>
  );
}
