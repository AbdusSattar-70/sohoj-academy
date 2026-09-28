do $$
begin
  if not exists (
    select 1
    from pg_proc
    where proname = 'admission_case_detail'
      and pg_get_function_identity_arguments(oid) = 'p_admission_id uuid'
  ) then
    raise exception 'Focused admission case detail RPC is missing.';
  end if;

  raise notice 'Focused admission case detail RPC is present.';
end;
$$;
