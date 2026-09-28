-- Academic years are explicit context, not a single global current-year switch.
-- An upcoming year can be prepared while the present year remains operational.
drop index if exists public.one_active_academic_year_per_org;

do $migration$
declare
  definition text;
  create_values text := 'values (v_org, v_name, v_starts, v_ends, false)';
  exclusive_update text := $block$      if v_is_active then
        update public.academic_years set is_active = false
        where organization_id = v_org and id <> v_id and is_active;
      end if;
$block$;
begin
  select pg_get_functiondef('public.manage_crm_master_record(jsonb)'::regprocedure)
    into definition;
  if position(create_values in definition)=0 or position(exclusive_update in definition)=0 then
    raise exception 'Cannot revise academic year management: expected function structure changed.';
  end if;
  definition:=replace(definition,create_values,
    'values (v_org, v_name, v_starts, v_ends, v_is_active)');
  definition:=replace(definition,exclusive_update,'');
  execute definition;
end;
$migration$;
