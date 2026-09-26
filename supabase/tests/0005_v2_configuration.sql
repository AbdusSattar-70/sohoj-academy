-- ERP v2 configuration and access-control verification.

do $$
declare
  v_default text;
begin
  if to_regclass('public.setting_definitions') is null
     or to_regclass('public.setting_versions') is null then
    raise exception 'Settings Control Center tables are missing.';
  end if;

  if to_regprocedure('public.publish_setting_value(text,jsonb,text,uuid)') is null
     or to_regprocedure('public.publish_business_rule_version(text,text,jsonb,text)') is null
     or to_regprocedure('public.set_role_permissions(text,text[],text)') is null then
    raise exception 'Configuration workflow functions are incomplete.';
  end if;

  select column_default
    into v_default
  from information_schema.columns
  where table_schema='public'
    and table_name='batches'
    and column_name='capacity';

  if v_default is not null then
    raise exception 'Batch capacity still has a hard-coded database default: %', v_default;
  end if;
end;
$$;

do $$
begin
  if (
    select count(*)
    from public.business_rule_versions
    where domain='admissions'
      and rule_key='activation_policy'
      and status='ACTIVE'
  ) <> 1 then
    raise exception 'Exactly one active admission activation policy is required.';
  end if;

  if coalesce((
    select (payload->>'requires_initial_billing_posted')::boolean
    from public.business_rule_versions
    where domain='admissions'
      and rule_key='activation_policy'
      and status='ACTIVE'
  ),false) is not true then
    raise exception 'Admission activation baseline must require initial billing to be posted.';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from public.system_roles r
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions p on p.id=rp.permission_id
    where r.code='ADMIN' and p.code='system.settings.manage'
  ) then
    raise exception 'ADMIN is missing Settings management permission.';
  end if;

  if not exists (
    select 1
    from public.system_roles r
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions p on p.id=rp.permission_id
    where r.code='ADMIN' and p.code='system.roles.manage'
  ) then
    raise exception 'ADMIN is missing role/permission management permission.';
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('authenticated','public.business_rule_versions','INSERT')
     or has_table_privilege('authenticated','public.business_rule_versions','UPDATE')
     or has_table_privilege('authenticated','public.role_permissions','INSERT')
     or has_table_privilege('authenticated','public.role_permissions','UPDATE')
     or has_table_privilege('authenticated','public.role_permissions','DELETE')
     or has_table_privilege('authenticated','public.setting_versions','INSERT')
     or has_table_privilege('authenticated','public.setting_versions','UPDATE')
     or has_table_privilege('authenticated','public.setting_versions','DELETE') then
    raise exception 'Authenticated API can bypass controlled Settings workflows.';
  end if;
end;
$$;

select
  'PASS' as v2_configuration_status,
  (select count(*) from public.permissions) as permissions,
  (select count(*) from public.business_rule_versions where status='ACTIVE') as active_policies,
  (select count(*) from public.system_roles where is_active) as active_roles;
