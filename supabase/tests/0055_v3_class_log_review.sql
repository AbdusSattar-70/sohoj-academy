do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='class_logs'
      and column_name='reviewer_id'
  ) then
    raise exception 'class_logs.reviewer_id is missing.';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='class_logs'
      and column_name='review_note'
  ) then
    raise exception 'class_logs.review_note is missing.';
  end if;

  raise notice 'V3 class-log review structure checks passed.';
end;
$$;
