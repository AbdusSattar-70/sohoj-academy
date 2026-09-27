-- Preserve unlisted school names on the prospect until staff verifies them.
-- Patch the original submit RPC without rewriting its established validation.
do $migration$
declare
  definition text;
  old_block text := $old$
  elsif v_school_name is not null then
    select * into v_school
    from public.schools
    where organization_id=v_org.id
      and lower(btrim(name))=lower(v_school_name)
      and is_active
    order by is_verified desc, created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools(
        organization_id,
        name,
        is_verified,
        is_active
      )
      values(
        v_org.id,
        v_school_name,
        false,
        true
      )
      returning * into v_school;
    end if;

    v_school_name := v_school.name;
  end if;
$old$;
  new_block text := $new$
  elsif v_school_name is not null then
    -- Keep unlisted names as prospect snapshots for staff verification.
    null;
  end if;
$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure)
  into definition;

  if position(old_block in definition) = 0 then
    if position(new_block in definition) > 0 then
      return;
    end if;
    raise exception 'Could not locate the unlisted-school block in submit_public_interest.';
  end if;

  execute replace(definition, old_block, new_block);
end;
$migration$;
