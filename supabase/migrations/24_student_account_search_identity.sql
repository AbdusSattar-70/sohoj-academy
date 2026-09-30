alter function public.finance_workspace() rename to finance_workspace_without_identity;
revoke all on function public.finance_workspace_without_identity() from public,anon,authenticated;
create or replace function public.finance_workspace()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 result:=public.finance_workspace_without_identity();
 return result||jsonb_build_object('admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',coalesce(s.full_name,a.identity_snapshot->>'student_name'),'number',a.admission_no,'status',a.status,'studentId',s.id,'studentNo',s.student_no,'mobile',a.identity_snapshot->>'mobile') order by a.created_at desc) from public.admission_cases a left join public.students s on s.id=a.student_id),'[]'::jsonb));
end $$;
revoke all on function public.finance_workspace() from public,anon;
grant execute on function public.finance_workspace() to authenticated;
