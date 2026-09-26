-- ERP v2 platform verification. Safe to run after a clean reset.

do $$
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.system_roles') is null
     or to_regclass('public.permissions') is null
     or to_regclass('public.staff') is null
     or to_regclass('public.audit_events') is null
     or to_regclass('public.approval_requests') is null
     or to_regclass('public.business_rule_versions') is null then
    raise exception 'ERP v2 platform tables are incomplete.';
  end if;

  if to_regprocedure('public.has_permission(text)') is null
     or to_regprocedure('public.my_erp_context()') is null
     or to_regprocedure('public.bootstrap_admin(text,text)') is null then
    raise exception 'ERP v2 platform functions are incomplete.';
  end if;
end;
$$;

do $$
begin
  if not exists (select 1 from public.system_roles where code='ADMIN') then
    raise exception 'ADMIN system role is missing.';
  end if;

  if not exists (
    select 1 from public.permissions where code='approvals.decide'
  ) then
    raise exception 'Approval permission seed is incomplete.';
  end if;

  if exists (
    select 1
    from public.permissions p
    where not exists (
      select 1
      from public.role_permissions rp
      join public.system_roles r on r.id=rp.role_id
      where rp.permission_id=p.id and r.code='ADMIN'
    )
  ) then
    raise exception 'ADMIN does not own every configured permission.';
  end if;
end;
$$;

do $$
begin
  if (
    select count(*)
    from public.business_rule_versions
    where domain='academics'
      and rule_key='batch_capacity_policy'
      and status='ACTIVE'
  ) <> 1 then
    raise exception 'Exactly one active batch-capacity policy is required.';
  end if;

  if (
    select count(*)
    from public.business_rule_versions
    where domain='teacher_compensation'
      and rule_key='default_policy'
      and status='ACTIVE'
  ) <> 1 then
    raise exception 'Exactly one active teacher-compensation policy is required.';
  end if;

  if coalesce((
    select (payload->>'max_students')::integer
    from public.business_rule_versions
    where domain='academics'
      and rule_key='batch_capacity_policy'
      and status='ACTIVE'
  ),0) <> 12 then
    raise exception 'Current batch-capacity policy must be 12.';
  end if;
end;
$$;

do $$
begin
  if (select count(*) from public.academic_years where is_active) <> 1 then
    raise exception 'Exactly one active Academic Year is required in the baseline.';
  end if;

  if not exists (select 1 from public.classes where code='CLASS_8' and is_active)
     or not exists (select 1 from public.classes where code='CLASS_9' and is_active)
     or not exists (select 1 from public.classes where code='CLASS_10' and is_active) then
    raise exception 'Class 8-10 baseline master data is incomplete.';
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('authenticated','public.audit_events','DELETE')
     or has_table_privilege('authenticated','public.approval_requests','DELETE')
     or has_table_privilege('authenticated','public.business_rule_versions','DELETE')
     or has_table_privilege('authenticated','public.staff','DELETE') then
    raise exception 'Authenticated API still has destructive platform delete privileges.';
  end if;
end;
$$;

select
  'PASS' as v2_platform_status,
  (select count(*) from public.system_roles) as system_roles,
  (select count(*) from public.permissions) as permissions,
  (select count(*) from public.business_rule_versions where status='ACTIVE') as active_rules,
  (select count(*) from public.classes where is_active) as active_classes;
