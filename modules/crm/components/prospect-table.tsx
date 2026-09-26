"use client";

import Link from "next/link";
import { Search } from "lucide-react";
import { useMemo, useState } from "react";
import { StatusBadge } from "@/components/erp/status-badge";
import type { ProspectListRow } from "@/modules/crm/queries";

const statuses = [
  "ALL",
  "NEW",
  "CONTACTED",
  "COUNSELLING",
  "TRIAL_SCHEDULED",
  "TRIAL_ATTENDED",
  "REGISTERED",
  "CONVERTED",
  "FUTURE_FOLLOW_UP",
  "LOST",
] as const;

export function ProspectTable({ rows }: { rows: ProspectListRow[] }) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<(typeof statuses)[number]>("ALL");

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();

    return rows.filter((row) => {
      const matchesStatus = status === "ALL" || row.status === status;
      const matchesQuery =
        !needle ||
        [
          row.prospectNo,
          row.studentName,
          row.guardianName,
          row.mobile,
          row.className,
          row.schoolName,
          row.sourceName,
          row.assignedTo,
        ].some((value) => value.toLowerCase().includes(needle));

      return matchesStatus && matchesQuery;
    });
  }, [query, rows, status]);

  return (
    <section className="overflow-hidden rounded-2xl border bg-card">
      <div className="flex flex-col gap-3 border-b p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:max-w-sm">
          <Search
            className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden="true"
          />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search name, mobile, school, class or prospect ID"
            className="min-h-11 w-full rounded-xl border bg-background pl-9 pr-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            aria-label="Search prospects"
          />
        </div>

        <label className="flex items-center gap-2 text-sm">
          <span className="text-muted-foreground">Status</span>
          <select
            value={status}
            onChange={(event) =>
              setStatus(event.target.value as (typeof statuses)[number])
            }
            className="min-h-11 rounded-xl border bg-background px-3"
          >
            {statuses.map((item) => (
              <option key={item} value={item}>
                {item === "ALL" ? "All statuses" : item.replaceAll("_", " ")}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[1180px] text-sm">
          <thead>
            <tr className="border-b bg-muted/40 text-left">
              <th className="px-4 py-3 font-semibold">Prospect</th>
              <th className="px-4 py-3 font-semibold">Student / Guardian</th>
              <th className="px-4 py-3 font-semibold">Class / School</th>
              <th className="px-4 py-3 font-semibold">Source</th>
              <th className="px-4 py-3 font-semibold">Owner</th>
              <th className="px-4 py-3 font-semibold">Next Follow-up</th>
              <th className="px-4 py-3 font-semibold">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((row) => (
              <tr key={row.id} className="border-b align-top hover:bg-muted/30">
                <td className="px-4 py-3">
                  <Link
                    href={`/dashboard/crm/prospects/${row.id}`}
                    className="font-semibold text-blue-700 hover:underline dark:text-blue-300"
                  >
                    {row.prospectNo}
                  </Link>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {new Date(row.createdAt).toLocaleDateString()}
                  </p>
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/dashboard/crm/prospects/${row.id}`}
                    className="font-medium hover:underline"
                  >
                    {row.studentName}
                  </Link>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {row.guardianName} • {row.mobile}
                  </p>
                </td>
                <td className="px-4 py-3">
                  <p>{row.className}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {row.schoolName}
                  </p>
                </td>
                <td className="px-4 py-3">{row.sourceName}</td>
                <td className="px-4 py-3">{row.assignedTo}</td>
                <td className="px-4 py-3">
                  {row.nextFollowUpAt ? (
                    <>
                      <p>{new Date(row.nextFollowUpAt).toLocaleDateString()}</p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {new Date(row.nextFollowUpAt).toLocaleTimeString([], {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </p>
                    </>
                  ) : (
                    "—"
                  )}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge value={row.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {!filtered.length && (
          <div className="p-8 text-center text-sm text-muted-foreground">
            No prospects match the current filters.
          </div>
        )}
      </div>

      <div className="border-t px-4 py-3 text-xs text-muted-foreground">
        Showing {filtered.length} of {rows.length} prospect records.
      </div>
    </section>
  );
}
