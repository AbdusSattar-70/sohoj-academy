-- Prospect conversion can correct a recorded class or preferred offering at the point of admission.
-- The existing admission_command remains the authority for fee, capacity, organization and case creation.
create or replace function public.create_prospect_admission(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid := auth.uid();
  rid uuid := nullif(p_input->>'request_id','')::uuid;
  key_row public.admission_command_keys;
  prospect_row public.prospects;
  chosen public.programme_offerings;
  before_record jsonb;
  reason_text text := btrim(coalesce(p_input->>'reason',''));
  needs_correction boolean;
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if p_input->>'action' <> 'CREATE' or rid is null
     or length(reason_text) < 5 or length(reason_text) > 500 then
    raise exception 'A valid admission request and reason are required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into key_row from public.admission_command_keys where request_id=rid;
  if found then
    if key_row.actor_id<>actor or key_row.payload<>p_input then
      raise exception 'Request identity was already used for different input.';
    end if;
    return key_row.result;
  end if;

  select * into prospect_row from public.prospects
    where id=nullif(p_input->>'prospect_id','')::uuid for update;
  if prospect_row.id is null or prospect_row.status in ('CONVERTED','LOST') then
    raise exception 'Choose an open Prospect.';
  end if;

  select * into chosen from public.programme_offerings
    where id=nullif(p_input->>'offering_id','')::uuid and status='ACTIVE';
  if chosen.id is null or chosen.organization_id<>prospect_row.organization_id
     or not exists (
       select 1 from public.batches b where b.id=nullif(p_input->>'batch_id','')::uuid
         and b.offering_id=chosen.id and b.is_active
     ) then
    raise exception 'Choose an active offering and its available batch.';
  end if;

  needs_correction :=
    (prospect_row.current_class_id is not null
      and prospect_row.current_class_id is distinct from chosen.class_id)
    or (prospect_row.interested_offering_id is not null
      and prospect_row.interested_offering_id is distinct from chosen.id);
  if needs_correction then
    if coalesce(p_input->>'confirm_placement_correction','false') <> 'true' then
      raise exception 'Confirm the changed Prospect placement before conversion.';
    end if;
    before_record := jsonb_build_object(
      'current_class_id',prospect_row.current_class_id,
      'interested_offering_id',prospect_row.interested_offering_id
    );
    update public.prospects
       set current_class_id=chosen.class_id,
           interested_offering_id=chosen.id
     where id=prospect_row.id;
    insert into public.audit_events(
      correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,
      action,reason,before_data,after_data,metadata
    ) values (
      rid,actor,(select id from public.staff where profile_id=actor limit 1),
      'PROSPECT',prospect_row.id::text,'CORRECT_ADMISSION_PLACEMENT',reason_text,
      before_record,
      jsonb_build_object('current_class_id',chosen.class_id,'interested_offering_id',chosen.id),
      jsonb_build_object('offering_id',chosen.id,'batch_id',p_input->>'batch_id')
    );
  end if;

  return public.admission_command(p_input);
end;
$$;

revoke all on function public.create_prospect_admission(jsonb) from public,anon;
grant execute on function public.create_prospect_admission(jsonb) to authenticated;
