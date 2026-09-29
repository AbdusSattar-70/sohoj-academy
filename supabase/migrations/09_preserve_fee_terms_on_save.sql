-- Current Fee Plan saves keep finalized historical terms reproducible.
-- The operator edits one current plan; storage revisions are internal evidence.
create or replace function public.save_fee_plan(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_previous public.fee_plan_versions;
  v_current public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_cycle text := p_input->>'billing_cycle';
  v_due_day integer;
  v_correlation uuid := gen_random_uuid();
  v_prior_components jsonb;
  v_next_version integer;
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then
    raise exception 'You are not authorized to edit Fee Plans.';
  end if;
  if length(v_reason) < 5 then
    raise exception 'Explain the fee change in at least five characters.';
  end if;
  if v_cycle not in ('MONTHLY','TERM','ONE_TIME') then
    raise exception 'Choose a valid billing cycle.';
  end if;
  v_due_day := nullif(p_input->>'due_day','')::integer;
  if (v_cycle = 'MONTHLY' and (v_due_day is null or v_due_day not between 1 and 28))
     or (v_cycle <> 'MONTHLY' and v_due_day is not null) then
    raise exception 'Monthly plans require a due day from 1 to 28; other plans have no monthly due day.';
  end if;
  if jsonb_typeof(v_components) is distinct from 'array' then
    raise exception 'Fee components must be a list.';
  end if;
  if jsonb_array_length(v_components) not between 1 and 30 then
    raise exception 'Enter between one and thirty fee components.';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v_components) c
    where c->>'charge_type' = 'TUITION'
      and c->>'recurrence' = 'PER_CYCLE'
      and (c->>'amount')::numeric > 0
  ) then
    raise exception 'Enter a positive recurring Tuition charge.';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_components) c
    where (c->>'amount')::numeric < 0
      or (c->>'charge_type' = 'TUITION' and (c->>'amount')::numeric <= 0)
  ) then
    raise exception 'Fee amounts cannot be negative; Tuition must be positive.';
  end if;

  -- Lock the offering to serialize simultaneous saves and version assignment.
  select * into v_offering
  from public.programme_offerings
  where id = (p_input->>'offering_id')::uuid and status <> 'RETIRED'
  for update;
  if v_offering.id is null then raise exception 'Offering is not available.'; end if;

  select (now() at time zone timezone)::date into v_today
  from public.organizations where id = v_offering.organization_id;
  if (p_input->>'effective_from')::date is distinct from v_today then
    raise exception 'Changes to current charges take effect today in the academy timezone.';
  end if;

  select * into v_previous
  from public.fee_plan_versions
  where offering_id = v_offering.id and status = 'ACTIVE'
  for update;
  select coalesce(max(version), 0) + 1 into v_next_version
  from public.fee_plan_versions where offering_id = v_offering.id;

  if v_previous.id is not null then
    select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order), '[]'::jsonb)
      into v_prior_components
    from public.fee_plan_components c
    where c.fee_plan_version_id = v_previous.id;

    update public.fee_plan_versions
    set status = 'RETIRED',
        effective_to = greatest(v_previous.effective_from, v_today)
    where id = v_previous.id;
  end if;

  insert into public.fee_plan_versions (
    offering_id, version, status, billing_cycle, due_day, currency_code,
    effective_from, effective_to, change_reason, created_by
  ) values (
    v_offering.id, v_next_version, 'ACTIVE', v_cycle, v_due_day,
    (select currency_code from public.organizations where id = v_offering.organization_id),
    v_today, null, v_reason, v_actor
  ) returning * into v_current;

  for v_component in select value from jsonb_array_elements(v_components)
  loop
    insert into public.fee_plan_components (
      fee_plan_version_id, code, name, amount, charge_type, recurrence, sort_order
    ) values (
      v_current.id, upper(btrim(v_component->>'code')),
      btrim(v_component->>'name'), (v_component->>'amount')::numeric,
      v_component->>'charge_type', v_component->>'recurrence',
      coalesce((v_component->>'sort_order')::integer, 0)
    );
  end loop;

  update public.programme_offerings set status = 'ACTIVE'
  where id = v_offering.id;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation, v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_offering.branch_id, 'FEE_PLAN', v_current.id::text,
    case when v_previous.id is null then 'CREATE' else 'SAVE' end,
    v_reason,
    case when v_previous.id is null then null else jsonb_build_object(
      'plan', to_jsonb(v_previous), 'components', v_prior_components
    ) end,
    jsonb_build_object(
      'plan', to_jsonb(v_current), 'components', v_components
    ),
    jsonb_build_object('offering_id', v_offering.id, 'current_state', true)
  );

  return jsonb_build_object('fee_plan_id', v_current.id, 'correlation_id', v_correlation);
end;
$$;

revoke all on function public.save_fee_plan(jsonb) from public, anon;
grant execute on function public.save_fee_plan(jsonb) to authenticated;
