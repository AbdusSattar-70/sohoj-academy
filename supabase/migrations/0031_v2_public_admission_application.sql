-- Public admission applications remain Prospects until staff verifies and accepts an admission.
-- Keep the applicant's original declarations and the published terms visible at submission.
alter table public.programme_offerings
  add column if not exists public_schedule text,
  add column if not exists public_requirements text,
  add column if not exists admission_policy text,
  add column if not exists public_schedule_bn text,
  add column if not exists public_requirements_bn text,
  add column if not exists admission_policy_bn text;

create table public.public_admission_applications (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null unique references public.prospects(id),
  offering_id uuid not null references public.programme_offerings(id),
  fee_plan_version_id uuid references public.fee_plan_versions(id),
  guardian_address text not null check (length(btrim(guardian_address)) between 5 and 300),
  academic_background text check (academic_background is null or length(academic_background) <= 500),
  requirements_acknowledged boolean not null check (requirements_acknowledged),
  policy_acknowledged boolean not null check (policy_acknowledged),
  published_terms_snapshot jsonb not null,
  submitted_at timestamptz not null default now()
);
create index public_admission_applications_offering_idx
  on public.public_admission_applications(offering_id, submitted_at desc);
alter table public.public_admission_applications enable row level security;
grant select on public.public_admission_applications to authenticated;
revoke insert, update, delete on public.public_admission_applications from anon, authenticated;
create policy public_admission_applications_staff_read
on public.public_admission_applications for select to authenticated
using (public.has_permission('crm.prospects.view') or public.has_permission('admissions.view'));

-- The existing public-controls RPC owns the offering row lock, validation and audit.
-- Extend its update atomically, keeping callers that omit the new keys compatible.
do $migration$
declare
  definition text;
  old_block text := $old$    applications_close_on = v_close,
    updated_at = now()$old$;
  new_block text := $new$    applications_close_on = v_close,
    public_schedule = case when p_input ? 'public_schedule' then nullif(btrim(p_input->>'public_schedule'), '') else public_schedule end,
    public_requirements = case when p_input ? 'public_requirements' then nullif(btrim(p_input->>'public_requirements'), '') else public_requirements end,
    admission_policy = case when p_input ? 'admission_policy' then nullif(btrim(p_input->>'admission_policy'), '') else admission_policy end,
    public_schedule_bn = case when p_input ? 'public_schedule_bn' then nullif(btrim(p_input->>'public_schedule_bn'), '') else public_schedule_bn end,
    public_requirements_bn = case when p_input ? 'public_requirements_bn' then nullif(btrim(p_input->>'public_requirements_bn'), '') else public_requirements_bn end,
    admission_policy_bn = case when p_input ? 'admission_policy_bn' then nullif(btrim(p_input->>'admission_policy_bn'), '') else admission_policy_bn end,
    updated_at = now()$new$;
begin
  select pg_get_functiondef('public.update_programme_offering_public_controls(jsonb)'::regprocedure) into definition;
  if position(old_block in definition) = 0 then
    if position(new_block in definition) > 0 then return; end if;
    raise exception 'Could not extend offering controls; inspect RPC definition before migrating.';
  end if;
  execute replace(definition, old_block, new_block);
end;
$migration$;

-- Public submission stays the only anonymous mutation path. Validate the fuller
-- application before creating the Prospect, then retain an immutable snapshot.
do $migration$
declare
  definition text;
  old_validation text := $old$  select * into v_org
  from public.organizations$old$;
  new_validation text := $new$  if v_intent = 'admission' then
    if length(btrim(coalesce(p_payload->>'guardian_address', ''))) < 5 then
      raise exception 'Guardian address is required for an admission application.';
    end if;
    if coalesce((p_payload->>'requirements_acknowledged')::boolean, false) is not true
      or coalesce((p_payload->>'policy_acknowledged')::boolean, false) is not true then
      raise exception 'Review and acknowledge the programme requirements and admission policy.';
    end if;
  end if;

  select * into v_org
  from public.organizations$new$;
  old_insert text := $old$  insert into public.audit_events(
    correlation_id,
    entity_type,$old$;
  new_insert text := $new$  if v_intent = 'admission' then
    insert into public.public_admission_applications (
      prospect_id, offering_id, fee_plan_version_id, guardian_address,
      academic_background, requirements_acknowledged, policy_acknowledged,
      published_terms_snapshot
    ) values (
      v_prospect.id, v_offering.id,
      (select id from public.fee_plan_versions where offering_id = v_offering.id and status = 'ACTIVE' limit 1),
      btrim(p_payload->>'guardian_address'),
      nullif(btrim(coalesce(p_payload->>'academic_background', '')), ''),
      true, true,
      jsonb_build_object(
        'offering_name', coalesce(v_offering.showcase_title, v_offering.name),
        'requirements', v_offering.public_requirements,
        'policy', v_offering.admission_policy,
        'schedule', v_offering.public_schedule,
        'applications_open_on', v_offering.applications_open_on,
        'applications_close_on', v_offering.applications_close_on
      )
    );
  end if;

  insert into public.audit_events(
    correlation_id,
    entity_type,$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure) into definition;
  if position(old_validation in definition) = 0 or position(old_insert in definition) = 0 then
    raise exception 'Could not extend public admission submission; inspect RPC definition before migrating.';
  end if;
  execute replace(replace(definition, old_validation, new_validation), old_insert, new_insert);
end;
$migration$;

-- The public catalogue is intentionally display-safe; include only curated terms.
create or replace function public.list_public_programme_offerings()
returns jsonb language sql security definer set search_path = public stable as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id, ay.name as academic_year_name,
      b.name as branch_name, c.name as class_name, ag.name as group_name,
      o.showcase_title, o.showcase_title_bn, o.showcase_description,
      o.showcase_description_bn, o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      o.public_schedule, o.public_schedule_bn, o.public_requirements,
      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN' end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name)
        order by pos.sort_order), '[]'::jsonb)
       from public.programme_offering_subjects pos
       join public.subjects s on s.id = pos.subject_id
       where pos.offering_id = o.id and s.is_active) as subjects,
      (select jsonb_build_object('billing_cycle', fp.billing_cycle,
        'currency_code', fp.currency_code,
        'components', coalesce((select jsonb_agg(jsonb_build_object(
          'code', fc.code, 'name', fc.name, 'amount', fc.amount,
          'charge_type', fc.charge_type, 'recurrence', fc.recurrence)
          order by fc.sort_order) from public.fee_plan_components fc
          where fc.fee_plan_version_id = fp.id), '[]'::jsonb))
       from public.fee_plan_versions fp
       where fp.offering_id = o.id and fp.status = 'ACTIVE' limit 1) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at limit 24
  ) x;
$$;
revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;
