-- Fee Plan publication uses the organization local calendar date.
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
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then
    raise exception 'You are not authorized to publish Fee Plans.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
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
  select (now() at time zone timezone)::date into v_today
  from public.organizations where id=v_offering.organization_id;
  if v_effective is distinct from v_today then
    raise exception 'Publishing currently requires today as the effective date.';
  end if;
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
