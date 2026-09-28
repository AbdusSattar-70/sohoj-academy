-- Programme Offering and versioned standard Fee Plan foundation.
-- Admission will reference a published fee_plan_version_id, never copy mutable defaults.

create type public.offering_status as enum ('DRAFT','ACTIVE','RETIRED');

create table public.academic_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  unique (organization_id, code)
);

insert into public.academic_groups(organization_id,code,name)
select id,'SCIENCE','Science' from public.organizations where code='SOHOJ';

create table public.programme_offerings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  program_id uuid not null references public.programs(id),
  group_id uuid references public.academic_groups(id),
  code text not null,
  name text not null,
  status public.offering_status not null default 'DRAFT',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, academic_year_id, code),
  check (length(btrim(code)) between 2 and 40),
  check (length(btrim(name)) between 2 and 160)
);

create unique index programme_offering_context_uniq
on public.programme_offerings(academic_year_id, branch_id, class_id, program_id,
  coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid));

create trigger programme_offerings_set_updated_at
before update on public.programme_offerings
for each row execute function public.set_updated_at();

create table public.fee_plan_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.programme_offerings(id),
  version integer not null check (version > 0),
  status public.rule_status not null default 'DRAFT',
  billing_cycle text not null check (billing_cycle in ('ONE_TIME','MONTHLY','TERM')),
  due_day integer check (due_day between 1 and 28),
  currency_code text not null default 'BDT' check (currency_code ~ '^[A-Z]{3}$'),
  effective_from date not null,
  effective_to date,
  change_reason text not null check (length(btrim(change_reason)) >= 5),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (offering_id, version),
  check (effective_to is null or effective_to >= effective_from),
  check ((billing_cycle = 'MONTHLY' and due_day is not null)
    or (billing_cycle <> 'MONTHLY' and due_day is null))
);

create unique index fee_plan_one_active_per_offering
on public.fee_plan_versions(offering_id) where status='ACTIVE';

create table public.fee_plan_components (
  id uuid primary key default gen_random_uuid(),
  fee_plan_version_id uuid not null references public.fee_plan_versions(id),
  code text not null check (code ~ '^[A-Z][A-Z0-9_]{1,39}$'),
  name text not null check (length(btrim(name)) between 2 and 100),
  amount numeric(12,2) not null check (amount >= 0),
  charge_type text not null check (charge_type in ('TUITION','ADMISSION','EXAM','MATERIAL','OTHER')),
  recurrence text not null check (recurrence in ('PER_CYCLE','ONE_TIME')),
  sort_order integer not null default 0,
  unique (fee_plan_version_id, code)
);

create or replace function public.guard_fee_plan_history()
returns trigger language plpgsql set search_path=public as $$
declare v_plan_id uuid;
begin
  if tg_table_name='fee_plan_components' then
    if tg_op='INSERT' then v_plan_id := new.fee_plan_version_id;
    else v_plan_id := old.fee_plan_version_id; end if;
    if exists (select 1 from public.fee_plan_versions
               where id=v_plan_id
                 and status<>'DRAFT') then
      raise exception 'Published Fee Plan components are immutable.';
    end if;
    if tg_op='DELETE' then return old; end if;
    return new;
  end if;
  if tg_op='DELETE' then
    raise exception 'Fee Plan versions cannot be deleted.';
  end if;
  if old.status<>'DRAFT' and (
    new.offering_id is distinct from old.offering_id or
    new.version is distinct from old.version or
    new.billing_cycle is distinct from old.billing_cycle or
    new.due_day is distinct from old.due_day or
    new.currency_code is distinct from old.currency_code or
    new.effective_from is distinct from old.effective_from or
    new.change_reason is distinct from old.change_reason or
    new.created_by is distinct from old.created_by
  ) then
    raise exception 'Published Fee Plan terms are immutable.';
  end if;
  if old.status='RETIRED' and new.status<>'RETIRED' then
    raise exception 'Retired Fee Plan versions cannot be reactivated.';
  end if;
  if old.status='ACTIVE' and new.status not in ('ACTIVE','RETIRED') then
    raise exception 'An active Fee Plan may only be retired.';
  end if;
  if old.status='ACTIVE' and new.effective_to is distinct from old.effective_to
     and (new.status<>'RETIRED' or new.effective_to is null
          or new.effective_to<old.effective_from) then
    raise exception 'Fee Plan end date requires a valid retirement.';
  end if;
  return new;
end;
$$;

create trigger fee_plan_version_history_guard
before update or delete on public.fee_plan_versions
for each row execute function public.guard_fee_plan_history();
create trigger fee_plan_component_history_guard
before insert or update or delete on public.fee_plan_components
for each row execute function public.guard_fee_plan_history();

create or replace function public.create_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_row public.programme_offerings;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to manage Programme Offerings.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active;
  if v_org is null or not exists (
    select 1 from public.branches b
    join public.academic_years y on y.id=(p_input->>'academic_year_id')::uuid
    join public.classes c on c.id=(p_input->>'class_id')::uuid
    join public.programs p on p.id=(p_input->>'program_id')::uuid
    where b.id=(p_input->>'branch_id')::uuid and b.is_active
      and b.organization_id=v_org and y.organization_id=v_org
      and c.organization_id=v_org and c.is_active
      and p.organization_id=v_org and p.is_active
      and (nullif(p_input->>'group_id','') is null or exists (
        select 1 from public.academic_groups g
        where g.id=(p_input->>'group_id')::uuid
          and g.organization_id=v_org and g.is_active))
  ) then
    raise exception 'Offering context must use active master data from the same organization.';
  end if;
  insert into public.programme_offerings(
    organization_id,branch_id,academic_year_id,class_id,program_id,
    group_id,code,name,created_by
  ) values (
    v_org,(p_input->>'branch_id')::uuid,(p_input->>'academic_year_id')::uuid,
    (p_input->>'class_id')::uuid,(p_input->>'program_id')::uuid,
    nullif(p_input->>'group_id','')::uuid,
    upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_actor
  ) returning * into v_row;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    branch_id,entity_type,entity_id,action,reason,after_data)
  values (v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
    v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'CREATE',v_reason,to_jsonb(v_row));
  return jsonb_build_object('offering_id',v_row.id,'correlation_id',v_correlation);
end;
$$;

create or replace function public.publish_fee_plan(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_previous public.fee_plan_versions;
  v_new public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_effective date := (p_input->>'effective_from')::date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then
    raise exception 'You are not authorized to publish Fee Plans.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  if v_effective is distinct from current_date then
    raise exception 'Publishing currently requires today as the effective date.';
  end if;
  if jsonb_typeof(v_components) is distinct from 'array' then
    raise exception 'Fee Components must be an array.';
  end if;
  if jsonb_array_length(v_components)=0 or not exists (
    select 1 from jsonb_array_elements(v_components) c
    where c->>'charge_type'='TUITION' and c->>'recurrence'='PER_CYCLE'
  ) then
    raise exception 'A recurring Tuition component is required.';
  end if;
  select * into v_offering from public.programme_offerings
  where id=(p_input->>'offering_id')::uuid and status<>'RETIRED' for update;
  if v_offering.id is null then raise exception 'Offering is not available.'; end if;
  select * into v_previous from public.fee_plan_versions
  where offering_id=v_offering.id and status='ACTIVE' for update;
  if v_previous.id is not null and v_effective<=v_previous.effective_from then
    raise exception 'The next Fee Plan must start after the previous version.';
  end if;
  if v_previous.id is not null then
    update public.fee_plan_versions
    set status='RETIRED',effective_to=v_effective-1
    where id=v_previous.id;
  end if;
  insert into public.fee_plan_versions(offering_id,version,status,billing_cycle,
    due_day,currency_code,effective_from,change_reason,created_by)
  values (v_offering.id,
    (select coalesce(max(version),0)+1 from public.fee_plan_versions where offering_id=v_offering.id),
    'DRAFT',p_input->>'billing_cycle',(p_input->>'due_day')::integer,
    (select currency_code from public.organizations where id=v_offering.organization_id),
    v_effective,v_reason,v_actor)
  returning * into v_new;
  for v_component in select value from jsonb_array_elements(v_components) loop
    insert into public.fee_plan_components(fee_plan_version_id,code,name,amount,
      charge_type,recurrence,sort_order)
    values (v_new.id,upper(btrim(v_component->>'code')),btrim(v_component->>'name'),
      (v_component->>'amount')::numeric,v_component->>'charge_type',
      v_component->>'recurrence',coalesce((v_component->>'sort_order')::integer,0));
  end loop;
  update public.fee_plan_versions set status='ACTIVE' where id=v_new.id;
  v_new.status := 'ACTIVE';
  update public.programme_offerings set status='ACTIVE' where id=v_offering.id;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    branch_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
  values (v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
    v_offering.branch_id,'FEE_PLAN_VERSION',v_new.id::text,'PUBLISH',v_reason,
    case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_new),jsonb_build_object('offering_id',v_offering.id,
      'component_count',jsonb_array_length(v_components)));
  return jsonb_build_object('fee_plan_version_id',v_new.id,
    'version',v_new.version,'correlation_id',v_correlation);
end;
$$;

alter table public.academic_groups enable row level security;
alter table public.programme_offerings enable row level security;
alter table public.fee_plan_versions enable row level security;
alter table public.fee_plan_components enable row level security;

grant select on public.academic_groups,public.programme_offerings,public.fee_plan_versions,
  public.fee_plan_components to authenticated;
revoke insert,update,delete on public.programme_offerings,public.fee_plan_versions,
  public.fee_plan_components from authenticated,anon;
revoke all on function public.create_programme_offering(jsonb),
  public.publish_fee_plan(jsonb) from public,anon;
grant execute on function public.create_programme_offering(jsonb),
  public.publish_fee_plan(jsonb) to authenticated;

create policy programme_offerings_read on public.programme_offerings
for select to authenticated using (public.has_permission('academics.view')
  or public.has_permission('admissions.view') or public.has_permission('finance.view'));
create policy academic_groups_read on public.academic_groups
for select to authenticated using (public.has_permission('academics.view')
  or public.has_permission('admissions.view'));
create policy fee_plan_versions_read on public.fee_plan_versions
for select to authenticated using (public.has_permission('finance.view')
  or public.has_permission('finance.billing.manage') or public.has_permission('admissions.view'));
create policy fee_plan_components_read on public.fee_plan_components
for select to authenticated using (public.has_permission('finance.view')
  or public.has_permission('finance.billing.manage') or public.has_permission('admissions.view'));
