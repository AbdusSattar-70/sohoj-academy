do $$
begin
  if not exists (
    select 1
    from pg_proc
    where proname = 'admin_review_queue'
      and pg_get_function_identity_arguments(oid) = ''
  ) then
    raise exception 'Admin review queue RPC is missing.';
  end if;

  raise notice 'V3 admin review queue structure checks passed.';
end;
$$;
