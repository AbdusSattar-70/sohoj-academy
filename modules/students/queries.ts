import { createClient } from "@/lib/supabase/server";

export type StudentListRow = {
  id: string;
  studentNo: string;
  fullName: string;
  schoolName: string;
  status: string;
  createdAt: string;
};

export type StudentListPage = {
  rows: StudentListRow[];
  total: number;
  page: number;
  pageSize: number;
};

export async function getStudentList({
  page = 1,
  query = "",
  pageSize = 50,
}: {
  page?: number;
  query?: string;
  pageSize?: number;
} = {}): Promise<StudentListPage> {
  const supabase = await createClient();
  const safePage = Math.max(1, page);
  const safePageSize = Math.min(100, Math.max(10, pageSize));
  const from = (safePage - 1) * safePageSize;
  const to = from + safePageSize - 1;
  let studentsQuery = supabase
    .from("students")
    .select(
      "id,student_no,full_name,school_id,school_name_snapshot,status,created_at",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);
  const needle = query.trim().replace(/[(),]/g, " ");
  if (needle) {
    studentsQuery = studentsQuery.or(
      `student_no.ilike.%${needle}%,full_name.ilike.%${needle}%,school_name_snapshot.ilike.%${needle}%`,
    );
  }
  const [studentsQ, schoolsQ] = await Promise.all([
    studentsQuery,
    supabase.from("schools").select("id,name"),
  ]);

  const schoolNames = new Map(
    (schoolsQ.data ?? []).map((row) => [row.id, row.name])
  );

  return {
    rows: (studentsQ.data ?? []).map((row) => ({
      id: row.id,
      studentNo: row.student_no,
      fullName: row.full_name,
      schoolName:
        (row.school_id ? schoolNames.get(row.school_id) : null) ??
        row.school_name_snapshot ??
        "—",
      status: row.status,
      createdAt: row.created_at,
    })),
    total: studentsQ.count ?? 0,
    page: safePage,
    pageSize: safePageSize,
  };
}
