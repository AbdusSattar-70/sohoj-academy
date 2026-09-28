-- V3 transition checks for explicit admission origins.

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'admission_cases'
      and column_name = 'origin'
  ) then
    raise exception 'admission_cases.origin is missing.';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'admission_cases'
      and column_name = 'origin_prospect_id'
  ) then
    raise exception 'admission_cases.origin_prospect_id is missing.';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'staff_admission_intake_requests'
      and column_name = 'prospect_id'
      and is_nullable = 'YES'
  ) then
    raise exception 'staff intake request prospect_id must be nullable for DIRECT_STAFF.';
  end if;

  if exists (
    select 1
    from public.admission_cases
    where origin in ('PROSPECT_CONVERSION','PUBLIC_APPLICATION')
      and (
        prospect_id is null
        or origin_prospect_id is distinct from prospect_id
      )
  ) then
    raise exception 'Prospect-origin admission cases must preserve origin_prospect_id.';
  end if;

  raise notice 'V3 admission origin structure checks passed.';
end;
$$;
