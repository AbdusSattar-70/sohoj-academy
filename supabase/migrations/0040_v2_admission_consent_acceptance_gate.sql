-- Phase 1: require a recorded signed-consent receipt before accepting new cases.
-- Existing cases are grandfathered so this cutover does not block historical work.

alter table public.admission_cases
  add column if not exists consent_required boolean;

update public.admission_cases
set consent_required = false
where consent_required is null;

alter table public.admission_cases
  alter column consent_required set default true,
  alter column consent_required set not null;

create index if not exists admission_cases_consent_gate_idx
  on public.admission_cases(consent_required, status);

-- Replace the current admission command definition while preserving all existing
-- workflow behavior. The gate is deliberately in the transactional ACCEPT branch
-- so direct callers cannot bypass the policy.
do $migration$
declare
  definition text;
  old_block text := $old$      if v_fee.status<>'ACTIVE' then raise exception 'Fee Plan changed. Refresh and review before acceptance.'; end if;
      select * into v_policy$old$;
  new_block text := $new$      if v_fee.status<>'ACTIVE' then raise exception 'Fee Plan changed. Refresh and review before acceptance.'; end if;
      if v_case.consent_required and not exists (
        select 1 from public.admission_consent_documents d
        where d.admission_id = v_case.id
      ) then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;
      select * into v_policy$new$;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure)
    into definition;
  if position(old_block in definition) = 0 then
    if position(new_block in definition) > 0 then return; end if;
    raise exception 'Could not install admission consent acceptance gate; inspect admission_command before migrating.';
  end if;
  execute replace(definition, old_block, new_block);
end;
$migration$;
