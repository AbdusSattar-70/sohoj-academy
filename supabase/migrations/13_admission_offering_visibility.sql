-- Show the admission operator all active offerings, including those awaiting fee setup.
-- The admission command still requires a currently effective published Fee Plan.
create or replace function public.admission_offering_options()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select case
    when auth.uid() is null or not public.has_permission('admissions.view')
      then '[]'::jsonb
    else coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,'name',o.name,'code',o.code,
        'classId',o.class_id,'className',c.name,
        'yearName',ay.name,'branchName',br.name,
        'feeReady',exists(
          select 1 from public.fee_plan_versions f
          where f.offering_id=o.id and f.status='ACTIVE'
            and f.effective_from <= timezone(org.timezone,now())::date
        )
      ) order by ay.starts_on desc,o.name)
      from public.programme_offerings o
      join public.classes c on c.id=o.class_id
      join public.academic_years ay on ay.id=o.academic_year_id
      join public.organizations org on org.id=o.organization_id
      left join public.branches br on br.id=o.branch_id
      where o.status='ACTIVE'
    ),'[]'::jsonb)
  end;
$$;

revoke all on function public.admission_offering_options() from public,anon;
grant execute on function public.admission_offering_options() to authenticated;
