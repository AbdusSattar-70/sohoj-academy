-- Sohoj Academy ERP v2
-- Configuration control center, editable role permissions and versioned policy publishing.

create table public.setting_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  group_code text not null,
  name text not null,
  description text,
  value_type text not null check (value_type in ('BOOLEAN','INTEGER','NUMERIC','TEXT','JSON')),
  default_value jsonb,
  validation_contract jsonb not null default '{}'::jsonb,
  is_sensitive boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.setting_versions (
  id uuid primary key default gen_random_uuid(),
  setting_definition_id uuid not null references public.setting_definitions(id),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  version integer not null,
  status public.rule_status not null default 'ACTIVE',
  effective_from date not null default current_date,
  effective_to date,
  value jsonb not null,
  change_reason text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique (setting_definition_id, organization_id, branch_id, version)
);

create unique index one_active_setting_per_scope
on public.setting_versions(
  setting_definition_id,
  organization_id,
  coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid)
)
where status='ACTIVE';

insert into public.permissions(code,name,description)
values
  ('system.settings.view','View settings','View configuration and active policy values.'),
  ('system.settings.manage','Manage settings','Publish versioned configuration changes.'),
  ('system.roles.manage','Manage roles and permissions','Create/maintain role permission bundles.')
on conflict (code) do nothing;

-- Bootstrap ADMIN remains the protected recovery authority and automatically
-- receives permissions introduced by later migrations.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
cross join public.permissions p
where r.code='ADMIN'
on conflict do nothing;

-- Initial admission policy. This is a default version, not hard-coded behavior.
insert into public.business_rule_versions(
  domain,
  rule_key,
  version,
  status,
  effective_from,
  payload,
  change_reason
)
select
  'admissions',
  'activation_policy',
  1,
  'ACTIVE',
  current_date,
  '{
    "requires_admission_acceptance": true,
    "requires_initial_billing_posted": true,
    "payment_requirement": "NONE",
    "minimum_payment_percent": 0,
    "allow_credit_enrollment": true,
    "count_student_active_only_when_enrollment_active": true
  }'::jsonb,
  'Initial configurable admission activation policy.'
where not exists (
  select 1
  from public.business_rule_versions
  where domain='admissions'
    and rule_key='activation_policy'
);

create or replace function public.validate_setting_value(
  p_value_type text,
  p_value jsonb
)
returns boolean
language plpgsql
immutable
as $$
begin
  return case p_value_type
    when 'BOOLEAN' then jsonb_typeof(p_value)='boolean'
    when 'INTEGER' then jsonb_typeof(p_value)='number'
      and (p_value::text)::numeric = trunc((p_value::text)::numeric)
    when 'NUMERIC' then jsonb_typeof(p_value)='number'
    when 'TEXT' then jsonb_typeof(p_value)='string'
    when 'JSON' then p_value is not null
    else false
  end;
exception when others then
  return false;
end;
$$;

create or replace function public.publish_setting_value(
  p_setting_code text,
  p_value jsonb,
  p_reason text,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_org public.organizations;
  v_definition public.setting_definitions;
  v_previous public.setting_versions;
  v_new public.setting_versions;
  v_version integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.settings.manage') then
    raise exception 'You are not authorized to manage settings.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  select * into v_definition
  from public.setting_definitions
  where code=p_setting_code and is_active;

  if v_definition.id is null then
    raise exception 'Setting definition % was not found.', p_setting_code;
  end if;

  if not public.validate_setting_value(v_definition.value_type,p_value) then
    raise exception 'Setting value does not match the required type %.', v_definition.value_type;
  end if;

  if p_branch_id is not null and not exists (
    select 1
    from public.branches b
    where b.id=p_branch_id
      and b.organization_id=v_org.id
      and b.is_active
  ) then
    raise exception 'Selected branch is not available.';
  end if;

  select * into v_previous
  from public.setting_versions
  where setting_definition_id=v_definition.id
    and organization_id=v_org.id
    and branch_id is not distinct from p_branch_id
    and status='ACTIVE'
  for update;

  select coalesce(max(version),0)+1 into v_version
  from public.setting_versions
  where setting_definition_id=v_definition.id
    and organization_id=v_org.id
    and branch_id is not distinct from p_branch_id;

  if v_previous.id is not null then
    update public.setting_versions
    set
      status='RETIRED',
      effective_to=current_date
    where id=v_previous.id;
  end if;

  insert into public.setting_versions(
    setting_definition_id,
    organization_id,
    branch_id,
    version,
    status,
    effective_from,
    value,
    change_reason,
    created_by
  )
  values(
    v_definition.id,
    v_org.id,
    p_branch_id,
    v_version,
    'ACTIVE',
    current_date,
    p_value,
    btrim(p_reason),
    v_actor
  )
  returning * into v_new;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'SETTING',
    v_definition.code,
    'PUBLISH_VERSION',
    btrim(p_reason),
    case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_new),
    jsonb_build_object(
      'setting_code',v_definition.code,
      'branch_id',p_branch_id,
      'version',v_new.version
    )
  );

  return jsonb_build_object(
    'setting_code',v_definition.code,
    'version',v_new.version,
    'value',v_new.value,
    'correlation_id',v_correlation_id
  );
end;
$$;

create or replace function public.publish_business_rule_version(
  p_domain text,
  p_rule_key text,
  p_payload jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_previous public.business_rule_versions;
  v_new public.business_rule_versions;
  v_version integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.settings.manage') then
    raise exception 'You are not authorized to manage business policies.';
  end if;

  if nullif(btrim(coalesce(p_domain,'')), '') is null
     or nullif(btrim(coalesce(p_rule_key,'')), '') is null then
    raise exception 'Policy domain and rule key are required.';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Policy payload must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_previous
  from public.business_rule_versions
  where domain=p_domain
    and rule_key=p_rule_key
    and status='ACTIVE'
  for update;

  select coalesce(max(version),0)+1 into v_version
  from public.business_rule_versions
  where domain=p_domain and rule_key=p_rule_key;

  if v_previous.id is not null then
    update public.business_rule_versions
    set
      status='RETIRED',
      effective_to=current_date
    where id=v_previous.id;
  end if;

  insert into public.business_rule_versions(
    domain,
    rule_key,
    version,
    status,
    effective_from,
    payload,
    change_reason,
    created_by
  )
  values(
    p_domain,
    p_rule_key,
    v_version,
    'ACTIVE',
    current_date,
    p_payload,
    btrim(p_reason),
    v_actor
  )
  returning * into v_new;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'BUSINESS_RULE',
    p_domain || '.' || p_rule_key,
    'PUBLISH_VERSION',
    btrim(p_reason),
    case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_new),
    jsonb_build_object('version',v_new.version)
  );

  return jsonb_build_object(
    'domain',v_new.domain,
    'rule_key',v_new.rule_key,
    'version',v_new.version,
    'payload',v_new.payload,
    'correlation_id',v_correlation_id
  );
end;
$$;

create or replace function public.set_role_permissions(
  p_role_code text,
  p_permission_codes text[],
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.system_roles;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.roles.manage') then
    raise exception 'You are not authorized to manage role permissions.';
  end if;

  select * into v_role
  from public.system_roles
  where code=upper(btrim(p_role_code))
    and is_active
  for update;

  if v_role.id is null then
    raise exception 'Role was not found.';
  end if;

  if v_role.code='ADMIN' then
    raise exception 'The bootstrap ADMIN role is protected. Create or edit operational roles instead.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  if exists (
    select unnest(coalesce(p_permission_codes,'{}'::text[]))
    except
    select code from public.permissions
  ) then
    raise exception 'One or more permission codes are invalid.';
  end if;

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_before
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  delete from public.role_permissions where role_id=v_role.id;

  insert into public.role_permissions(role_id,permission_id)
  select v_role.id,p.id
  from public.permissions p
  where p.code=any(coalesce(p_permission_codes,'{}'::text[]));

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_after
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'SYSTEM_ROLE',
    v_role.id::text,
    'SET_PERMISSIONS',
    btrim(p_reason),
    jsonb_build_object('permissions',v_before),
    jsonb_build_object('permissions',v_after)
  );

  return jsonb_build_object(
    'role_code',v_role.code,
    'permissions',v_after,
    'correlation_id',v_correlation_id
  );
end;
$$;

alter table public.setting_definitions enable row level security;
alter table public.setting_versions enable row level security;

grant select on public.system_roles,public.permissions,public.role_permissions,
  public.setting_definitions,public.setting_versions to authenticated;

grant execute on function public.publish_setting_value(text,jsonb,text,uuid) to authenticated;
grant execute on function public.publish_business_rule_version(text,text,jsonb,text) to authenticated;
grant execute on function public.set_role_permissions(text,text[],text) to authenticated;

revoke insert,update,delete on public.role_permissions from authenticated;
revoke insert,update,delete on public.business_rule_versions from authenticated;
revoke insert,update,delete on public.setting_versions from authenticated;

create policy system_roles_read
on public.system_roles for select to authenticated
using (true);

create policy permissions_read
on public.permissions for select to authenticated
using (true);

create policy role_permissions_read
on public.role_permissions for select to authenticated
using (
  public.has_permission('system.roles.manage')
  or public.has_permission('system.users.manage')
);

create policy setting_definitions_read
on public.setting_definitions for select to authenticated
using (
  public.has_permission('system.settings.view')
  or public.has_permission('system.settings.manage')
);

create policy setting_versions_read
on public.setting_versions for select to authenticated
using (
  public.has_permission('system.settings.view')
  or public.has_permission('system.settings.manage')
);

-- Business rules are published only through the audited RPC from this point on.
drop policy if exists business_rules_insert on public.business_rule_versions;
drop policy if exists business_rules_update on public.business_rule_versions;
