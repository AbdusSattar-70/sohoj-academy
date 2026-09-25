-- Attendance permissions and staff-side upsert helper.

alter table public.attendance enable row level security;

create policy "staff read attendance" on public.attendance
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff manage attendance" on public.attendance
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create or replace function public.save_attendance(
  p_session_id uuid,
  p_entries jsonb
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_count integer := 0;
  v_entry jsonb;
begin
  if public.current_role() not in ('ADMIN','OPERATOR','TEACHER') then
    raise exception 'Not authorized';
  end if;

  if p_session_id is null then
    raise exception 'Session is required';
  end if;

  for v_entry in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    insert into public.attendance (
      session_id,
      student_id,
      status,
      remarks,
      marked_by,
      marked_at
    )
    values (
      p_session_id,
      (v_entry->>'student_id')::uuid,
      (v_entry->>'status')::public.attendance_status,
      nullif(v_entry->>'remarks',''),
      v_user,
      now()
    )
    on conflict (session_id, student_id)
    do update set
      status = excluded.status,
      remarks = excluded.remarks,
      marked_by = excluded.marked_by,
      marked_at = now();

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
