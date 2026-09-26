-- Run after migration 0008. Structural/integrity checks without changing live data.
do $$
begin
  if to_regclass('public.academic_groups') is null
     or to_regclass('public.programme_offerings') is null
     or to_regclass('public.fee_plan_versions') is null
     or to_regclass('public.fee_plan_components') is null then
    raise exception 'Programme Offering / Fee Plan foundation is incomplete.';
  end if;

  if to_regprocedure('public.create_programme_offering(jsonb)') is null
     or to_regprocedure('public.publish_fee_plan(jsonb)') is null then
    raise exception 'Controlled publishing RPCs are missing.';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname='public' and tablename='fee_plan_versions'
  ) then
    raise exception 'Fee Plan versions have no RLS read policy.';
  end if;

  if has_table_privilege('authenticated','public.programme_offerings','INSERT')
     or has_table_privilege('authenticated','public.programme_offerings','UPDATE')
     or has_table_privilege('authenticated','public.fee_plan_versions','INSERT')
     or has_table_privilege('authenticated','public.fee_plan_versions','UPDATE')
     or has_table_privilege('authenticated','public.fee_plan_components','INSERT')
     or has_table_privilege('authenticated','public.fee_plan_components','UPDATE') then
    raise exception 'Authenticated API can bypass controlled offering/fee publishing.';
  end if;

  if not has_function_privilege('authenticated','public.create_programme_offering(jsonb)','EXECUTE')
     or not has_function_privilege('authenticated','public.publish_fee_plan(jsonb)','EXECUTE') then
    raise exception 'Controlled offering/fee RPC grants are missing.';
  end if;

  if not exists (select 1 from public.academic_groups where code='SCIENCE') then
    raise exception 'Canonical Science group is missing.';
  end if;
end;
$$;

select 'PASS' as v2_programme_fee_foundation_status;
