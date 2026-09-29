-- Current-state architecture compatibility boundary.
-- Business versioning is no longer a product concept. Legacy version tables remain
-- temporarily as storage internals while dependent admission/finance records migrate.
--
-- Product-facing reads use current_* views and the product-facing command is save_fee_plan.
-- Audit history remains mandatory.

create or replace view public.current_fee_plans
with (security_invoker = true)
as
select distinct on (fp.offering_id)
  fp.id,
  fp.offering_id,
  fp.version,
  fp.status,
  fp.billing_cycle,
  fp.due_day,
  fp.currency_code,
  fp.effective_from,
  fp.effective_to,
  fp.change_reason,
  fp.created_by,
  fp.created_at
from public.fee_plan_versions fp
where fp.status in ('ACTIVE','RETIRED','DRAFT')
order by
  fp.offering_id,
  case when fp.status = 'ACTIVE' then 0 else 1 end,
  fp.effective_from desc,
  fp.created_at desc,
  fp.version desc;

create or replace view public.current_fee_plan_components
with (security_invoker = true)
as
select
  c.id,
  c.fee_plan_version_id,
  c.code,
  c.name,
  c.amount,
  c.charge_type,
  c.recurrence,
  c.sort_order
from public.fee_plan_components c
join public.current_fee_plans fp on fp.id = c.fee_plan_version_id;

-- Current-state application command.
-- This updates the existing current Fee Plan in place. The legacy publish RPC is
-- deliberately not called: business versioning is not part of the product model.
create or replace function public.save_fee_plan(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_plan public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_effective date := (p_input->>'effective_from')::date;
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
  v_before jsonb;
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then
    raise exception 'You are not authorized to edit Fee Plans.';
  end if;
  if length(v_reason) < 5 then
    raise exception 'A change reason of at least five characters is required.';
  end if;
  if jsonb_typeof(v_components) is distinct from 'array' or jsonb_array_length(v_components) = 0 then
    raise exception 'Fee Components must be a non-empty array.';
  end if;
  if not exists (
    select 1
    from jsonb_array_elements(v_components) c
    where c->>'charge_type' = 'TUITION'
      and c->>'recurrence' = 'PER_CYCLE'
  ) then
    raise exception 'A recurring Tuition component is required.';
  end if;

  select *
  into v_offering
  from public.programme_offerings
  where id = (p_input->>'offering_id')::uuid
    and status <> 'RETIRED'
  for update;

  if v_offering.id is null then
    raise exception 'Offering is not available.';
  end if;

  select (now() at time zone timezone)::date
  into v_today
  from public.organizations
  where id = v_offering.organization_id;

  if v_effective is distinct from v_today then
    raise exception 'Fee Plan effective date must be today.';
  end if;

  select *
  into v_plan
  from public.fee_plan_versions
  where offering_id = v_offering.id
    and status = 'ACTIVE'
  order by created_at desc
  limit 1
  for update;

  if v_plan.id is not null then
    v_before := to_jsonb(v_plan);

    update public.fee_plan_versions
    set billing_cycle = p_input->>'billing_cycle',
        due_day = (p_input->>'due_day')::integer,
        currency_code = (
          select currency_code
          from public.organizations
          where id = v_offering.organization_id
        ),
        effective_from = v_effective,
        effective_to = null,
        change_reason = v_reason
    where id = v_plan.id
    returning * into v_plan;

    delete from public.fee_plan_components
    where fee_plan_version_id = v_plan.id;
  else
    insert into public.fee_plan_versions(
      offering_id, version, status, billing_cycle, due_day, currency_code,
      effective_from, effective_to, change_reason, created_by
    )
    values (
      v_offering.id, 1, 'ACTIVE', p_input->>'billing_cycle',
      (p_input->>'due_day')::integer,
      (select currency_code from public.organizations where id = v_offering.organization_id),
      v_effective, null, v_reason, v_actor
    )
    returning * into v_plan;

    v_before := null;
  end if;

  for v_component in
    select value from jsonb_array_elements(v_components)
  loop
    insert into public.fee_plan_components(
      fee_plan_version_id, code, name, amount, charge_type, recurrence, sort_order
    )
    values (
      v_plan.id,
      upper(btrim(v_component->>'code')),
      btrim(v_component->>'name'),
      (v_component->>'amount')::numeric,
      v_component->>'charge_type',
      v_component->>'recurrence',
      coalesce((v_component->>'sort_order')::integer, 0)
    );
  end loop;

  update public.programme_offerings
  set status = 'ACTIVE'
  where id = v_offering.id;

  insert into public.audit_events(
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  )
  values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_offering.branch_id,
    'FEE_PLAN',
    v_plan.id::text,
    case when v_before is null then 'CREATE' else 'SAVE' end,
    v_reason,
    v_before,
    to_jsonb(v_plan),
    jsonb_build_object(
      'offering_id', v_offering.id,
      'component_count', jsonb_array_length(v_components),
      'current_state', true
    )
  );

  return jsonb_build_object(
    'fee_plan_id', v_plan.id,
    'correlation_id', v_correlation
  );
end;
$$;

revoke all on function public.save_fee_plan(jsonb) from public, anon;
grant execute on function public.save_fee_plan(jsonb) to authenticated;

-- Product-facing read access follows the same finance visibility boundary.
grant select on public.current_fee_plans, public.current_fee_plan_components to authenticated;

-- Current-state compatibility read for management rules.
-- The version column remains internal migration metadata only; it is not
-- exposed through the current-state product contract.
create or replace view public.current_operating_rules
with (security_invoker = true)
as
select distinct on (r.domain, r.rule_key)
  r.id,
  r.domain,
  r.rule_key,
  r.status,
  r.payload
from public.business_rule_versions r
where r.status in ('ACTIVE','RETIRED','DRAFT')
order by
  r.domain,
  r.rule_key,
  case when r.status = 'ACTIVE' then 0 else 1 end,
  r.version desc;

grant select on public.current_operating_rules to authenticated;
