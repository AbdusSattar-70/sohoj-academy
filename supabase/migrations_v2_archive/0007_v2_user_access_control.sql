-- Sohoj Academy ERP v2
-- Controlled user-to-operational-role assignment workflow.

create or replace function public.set_user_operational_roles(
  p_profile_id uuid,
  p_role_codes text[],
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
  v_profile public.profiles;
  v_branch public.branches;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.users.manage') then
    raise exception 'You are not authorized to manage user access.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_profile
  from public.profiles
  where id=p_profile_id
    and status='ACTIVE'
  for update;

  if v_profile.id is null then
    raise exception 'Active user profile was not found.';
  end if;

  if p_branch_id is not null then
    select * into v_branch
    from public.branches
    where id=p_branch_id and is_active;

    if v_branch.id is null then
      raise exception 'Selected branch is not available.';
    end if;
  end if;

  if 'ADMIN'=any(coalesce(p_role_codes,'{}'::text[])) then
    raise exception 'ADMIN assignment is protected and cannot be changed through the operational access editor.';
  end if;

  if exists (
    select unnest(coalesce(p_role_codes,'{}'::text[]))
    except
    select code
    from public.system_roles
    where code<>'ADMIN' and is_active
  ) then
    raise exception 'One or more operational role codes are invalid.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_before
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  update public.user_role_assignments ura
  set
    is_active=false,
    effective_to=current_date
  from public.system_roles r
  where ura.role_id=r.id
    and ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id
    and not (r.code=any(coalesce(p_role_codes,'{}'::text[])));

  insert into public.user_role_assignments(
    profile_id,
    role_id,
    branch_id,
    effective_from,
    is_active,
    assigned_by
  )
  select
    p_profile_id,
    r.id,
    p_branch_id,
    current_date,
    true,
    v_actor
  from public.system_roles r
  where r.code=any(coalesce(p_role_codes,'{}'::text[]))
    and r.code<>'ADMIN'
    and r.is_active
    and not exists (
      select 1
      from public.user_role_assignments existing
      where existing.profile_id=p_profile_id
        and existing.role_id=r.id
        and existing.branch_id is not distinct from p_branch_id
        and existing.is_active
        and existing.effective_to is null
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_after
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  if v_before=v_after then
    raise exception 'The proposed access assignment is identical to the current assignment.';
  end if;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    branch_id,
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
    p_branch_id,
    'USER_ACCESS',
    p_profile_id::text,
    'SET_OPERATIONAL_ROLES',
    btrim(p_reason),
    jsonb_build_object('roles',v_before),
    jsonb_build_object('roles',v_after),
    jsonb_build_object('scope_branch_id',p_branch_id)
  );

  return jsonb_build_object(
    'profile_id',p_profile_id,
    'branch_id',p_branch_id,
    'roles',v_after,
    'correlation_id',v_correlation_id
  );
end;
$$;

grant execute on function public.set_user_operational_roles(uuid,text[],text,uuid) to authenticated;

-- Access assignments are mutated only through controlled workflows.
revoke insert,update,delete on public.user_role_assignments from authenticated;
