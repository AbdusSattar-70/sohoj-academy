-- Assessment result entry permissions.

alter table public.assessment_results enable row level security;

create policy "staff read assessment results" on public.assessment_results
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff manage assessment results" on public.assessment_results
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create or replace function public.save_assessment_results(
  p_assessment_id uuid,
  p_entries jsonb
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_total numeric;
  v_count integer := 0;
  v_entry jsonb;
  v_marks numeric;
begin
  if public.current_role() not in ('ADMIN','OPERATOR','TEACHER') then
    raise exception 'Not authorized';
  end if;

  select total_marks into v_total from public.assessments where id = p_assessment_id;
  if v_total is null then raise exception 'Assessment not found'; end if;

  for v_entry in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    v_marks := (v_entry->>'marks')::numeric;
    if v_marks < 0 or v_marks > v_total then
      raise exception 'Marks must be between 0 and %', v_total;
    end if;

    insert into public.assessment_results (assessment_id, student_id, marks, remarks)
    values (p_assessment_id,(v_entry->>'student_id')::uuid,v_marks,nullif(v_entry->>'remarks',''))
    on conflict (assessment_id, student_id)
    do update set marks=excluded.marks, remarks=excluded.remarks;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
