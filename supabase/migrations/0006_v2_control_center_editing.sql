-- Sohoj Academy ERP v2
-- Harden editable Control Center policies with database payload validation.

create or replace function public.validate_business_rule_payload(
  p_domain text,
  p_rule_key text,
  p_payload jsonb
)
returns boolean
language plpgsql
immutable
as $$
declare
  v_pool numeric;
  v_pool_max numeric;
  v_acquisition numeric;
  v_retention_3 numeric;
  v_retention_6 numeric;
  v_capacity numeric;
  v_payment_requirement text;
  v_minimum_payment numeric;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return false;
  end if;

  if p_domain='academics' and p_rule_key='batch_capacity_policy' then
    if jsonb_typeof(p_payload->'max_students') <> 'number' then
      return false;
    end if;

    v_capacity := (p_payload->>'max_students')::numeric;

    return v_capacity = trunc(v_capacity)
      and v_capacity between 1 and 500;
  end if;

  if p_domain='teacher_compensation' and p_rule_key='default_policy' then
    if jsonb_typeof(p_payload->'teaching_pool_percent') <> 'number'
       or jsonb_typeof(p_payload->'teaching_pool_review_max_percent') <> 'number'
       or jsonb_typeof(p_payload->'acquisition_bonus_percent') <> 'number'
       or jsonb_typeof(p_payload->'retention_3_month_percent') <> 'number'
       or jsonb_typeof(p_payload->'retention_6_month_percent') <> 'number' then
      return false;
    end if;

    v_pool := (p_payload->>'teaching_pool_percent')::numeric;
    v_pool_max := (p_payload->>'teaching_pool_review_max_percent')::numeric;
    v_acquisition := (p_payload->>'acquisition_bonus_percent')::numeric;
    v_retention_3 := (p_payload->>'retention_3_month_percent')::numeric;
    v_retention_6 := (p_payload->>'retention_6_month_percent')::numeric;

    return v_pool between 0 and 100
      and v_pool_max between 0 and 100
      and v_pool <= v_pool_max
      and v_acquisition between 0 and 100
      and v_retention_3 between 0 and 100
      and v_retention_6 between 0 and 100;
  end if;

  if p_domain='admissions' and p_rule_key='activation_policy' then
    if jsonb_typeof(p_payload->'requires_admission_acceptance') <> 'boolean'
       or jsonb_typeof(p_payload->'requires_initial_billing_posted') <> 'boolean'
       or jsonb_typeof(p_payload->'allow_credit_enrollment') <> 'boolean'
       or jsonb_typeof(p_payload->'count_student_active_only_when_enrollment_active') <> 'boolean'
       or jsonb_typeof(p_payload->'minimum_payment_percent') <> 'number'
       or jsonb_typeof(p_payload->'payment_requirement') <> 'string' then
      return false;
    end if;

    v_payment_requirement := p_payload->>'payment_requirement';
    v_minimum_payment := (p_payload->>'minimum_payment_percent')::numeric;

    if v_payment_requirement not in ('NONE','MINIMUM_PERCENT','FULL') then
      return false;
    end if;

    if v_minimum_payment < 0 or v_minimum_payment > 100 then
      return false;
    end if;

    if v_payment_requirement='NONE' and v_minimum_payment <> 0 then
      return false;
    end if;

    if v_payment_requirement='MINIMUM_PERCENT'
       and (v_minimum_payment <= 0 or v_minimum_payment >= 100) then
      return false;
    end if;

    if v_payment_requirement='FULL' and v_minimum_payment <> 100 then
      return false;
    end if;

    return true;
  end if;

  -- Unknown rules are intentionally not editable through the generic
  -- Control Center publisher until a database validation contract is added.
  return false;
exception when others then
  return false;
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

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  if not public.validate_business_rule_payload(p_domain,p_rule_key,p_payload) then
    raise exception 'Policy payload failed the database validation contract.';
  end if;

  select * into v_previous
  from public.business_rule_versions
  where domain=p_domain
    and rule_key=p_rule_key
    and status='ACTIVE'
  for update;

  if v_previous.id is null then
    raise exception 'Active policy %.% was not found.', p_domain, p_rule_key;
  end if;

  if v_previous.payload = p_payload then
    raise exception 'The proposed policy is identical to the active version.';
  end if;

  select coalesce(max(version),0)+1 into v_version
  from public.business_rule_versions
  where domain=p_domain and rule_key=p_rule_key;

  update public.business_rule_versions
  set
    status='RETIRED',
    effective_to=current_date
  where id=v_previous.id;

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
    to_jsonb(v_previous),
    to_jsonb(v_new),
    jsonb_build_object(
      'previous_version',v_previous.version,
      'new_version',v_new.version
    )
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

grant execute on function public.validate_business_rule_payload(text,text,jsonb) to authenticated;
grant execute on function public.publish_business_rule_version(text,text,jsonb,text) to authenticated;
