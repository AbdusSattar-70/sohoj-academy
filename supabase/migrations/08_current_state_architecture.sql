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
  c.sort_order,
  c.created_at
from public.fee_plan_components c
join public.current_fee_plans fp on fp.id = c.fee_plan_version_id;

-- Current-state application command. Internally this delegates to the legacy
-- storage RPC during migration, but the application no longer exposes version
-- creation/retirement as a business operation.
create or replace function public.save_fee_plan(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_result jsonb;
begin
  v_result := public.publish_fee_plan(p_input);

  return jsonb_build_object(
    'fee_plan_id', v_result->>'fee_plan_version_id'
  );
end;
$$;

revoke all on function public.save_fee_plan(jsonb) from public, anon;
grant execute on function public.save_fee_plan(jsonb) to authenticated;

-- Product-facing read access follows the same finance visibility boundary.
grant select on public.current_fee_plans, public.current_fee_plan_components to authenticated;
