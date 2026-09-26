-- ERP v2 user access-control verification.

do $$
begin
  if to_regprocedure('public.set_user_operational_roles(uuid,text[],text,uuid)') is null then
    raise exception 'Controlled user role assignment RPC is missing.';
  end if;
end;
$$;

do $$
begin
  if not has_function_privilege(
    'authenticated',
    'public.set_user_operational_roles(uuid,text[],text,uuid)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated users cannot invoke the controlled access RPC.';
  end if;

  if has_table_privilege('authenticated','public.user_role_assignments','INSERT')
     or has_table_privilege('authenticated','public.user_role_assignments','UPDATE')
     or has_table_privilege('authenticated','public.user_role_assignments','DELETE') then
    raise exception 'Authenticated API can bypass the controlled user-access workflow.';
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
    where r.code='ADMIN'
      and p.code='system.users.manage'
  ) then
    raise exception 'Protected ADMIN does not have user-access management permission.';
  end if;

  if exists (
    select 1
    from public.user_role_assignments ura
    join public.system_roles r on r.id=ura.role_id
    where r.code='ADMIN'
      and not ura.is_active
      and ura.effective_to is null
  ) then
    raise exception 'An inconsistent protected ADMIN assignment exists.';
  end if;
end;
$$;

select
  'PASS' as v2_user_access_status,
  (select count(*) from public.profiles where status='ACTIVE') as active_profiles,
  (
    select count(*)
    from public.user_role_assignments
    where is_active and effective_to is null
  ) as active_role_assignments;
