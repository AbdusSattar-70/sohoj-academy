-- Public catalogue is entirely curated in the ERP. The open state uses the
-- organization's local date, the same date used when accepting a submission.
create or replace function public.list_public_programme_offerings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select
      o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id,
      ay.name as academic_year_name,
      b.name as branch_name,
      c.name as class_name,
      ag.name as group_name,
      o.showcase_title, o.showcase_title_bn,
      o.showcase_description, o.showcase_description_bn,
      o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case
        when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN'
      end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', s.id, 'code', s.code, 'name', s.name
        ) order by pos.sort_order), '[]'::jsonb)
        from public.programme_offering_subjects pos
        join public.subjects s on s.id = pos.subject_id
        where pos.offering_id = o.id and s.is_active
      ) as subjects,
      (
        select jsonb_build_object(
          'billing_cycle', fp.billing_cycle,
          'currency_code', fp.currency_code,
          'components', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', fc.code, 'name', fc.name, 'amount', fc.amount,
              'charge_type', fc.charge_type, 'recurrence', fc.recurrence
            ) order by fc.sort_order)
            from public.fee_plan_components fc
            where fc.fee_plan_version_id = fp.id
          ), '[]'::jsonb)
        )
        from public.fee_plan_versions fp
        where fp.offering_id = o.id and fp.status = 'ACTIVE'
        limit 1
      ) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at
    limit 24
  ) x;
$$;

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;

-- The original submit function has subsequent school-review changes. Replace
-- only its date expression so those validations and snapshots remain intact.
do $migration$
declare
  definition text;
  old_expression text := $old$v_today date := (timezone('utc', now()))::date;$old$;
  new_expression text := $new$v_today date;$new$;
  org_lookup text := $old$
  where code='SOHOJ' and is_active
  limit 1;
$old$;
  local_date_lookup text := $new$
  where code='SOHOJ' and is_active
  limit 1;

  v_today := timezone(v_org.timezone, now())::date;
$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure) into definition;
  if position(old_expression in definition) = 0 then
    if position(new_expression in definition) > 0 and position(local_date_lookup in definition) > 0 then return; end if;
    raise exception 'Could not locate submission date expression; review submit_public_interest before migrating.';
  end if;
  if position(org_lookup in definition) = 0 then
    raise exception 'Could not locate organization lookup; review submit_public_interest before migrating.';
  end if;
  execute replace(replace(definition, old_expression, new_expression), org_lookup, local_date_lookup);
end;
$migration$;

-- Relationships are an administrator-managed public form vocabulary.
grant select on public.guardian_relationships to anon;
create policy guardian_relationships_public_read
on public.guardian_relationships for select to anon
using (is_active);
