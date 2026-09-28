-- V3 attendance command regression checks.
-- Development-only fixtures; rolled back. Run as database owner.

begin;

do $$
declare
  has_reviewer_metadata boolean;
  has_command_function boolean;
  has_unique_pending boolean;
  trigger_definition text;
begin
  select exists(
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='attendance_submissions'
      and column_name='reviewer_id'
  ) into has_reviewer_metadata;

  select exists(
    select 1
    from pg_proc
    where pronamespace='public'::regnamespace
      and proname='attendance_command'
  ) into has_command_function;

  select exists(
    select 1
    from pg_indexes
    where schemaname='public'
      and indexname='one_pending_attendance'
  ) into has_unique_pending;

  select pg_get_functiondef(p.oid)
  into trigger_definition
  from pg_proc p
  join pg_trigger t on t.tgfoid=p.oid
  where t.tgname='academic_immutable'
    and t.tgrelid='public.attendance_submissions'::regclass
  limit 1;

  if not has_reviewer_metadata then
    raise exception 'Attendance reviewer metadata columns are missing.';
  end if;

  if not has_command_function then
    raise exception 'Focused attendance command function is missing.';
  end if;

  if not has_unique_pending then
    raise exception 'One-pending-attendance constraint is missing.';
  end if;

  if trigger_definition is null
    or position('reviewer_id' in trigger_definition)=0
    or position('review_note' in trigger_definition)=0
    or position('reviewed_at' in trigger_definition)=0 then
    raise exception 'Academic attendance immutability trigger is not review-aware.';
  end if;
end;
$$;

rollback;
