-- Record paper consent receipt metadata without storing a scan or photograph.
create table public.admission_physical_consent_receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  request_payload jsonb not null,
  admission_id uuid not null references public.admission_cases(id),
  version integer not null check (version > 0),
  guardian_signed_on date not null,
  student_signed boolean not null default false,
  physical_copy_reference text,
  received_by uuid not null references public.profiles(id),
  received_at timestamptz not null default now(),
  reason text not null,
  unique (admission_id, version),
  check (physical_copy_reference is null or length(physical_copy_reference) <= 160),
  check (length(trim(reason)) >= 5)
);
create index admission_physical_consent_case_idx
  on public.admission_physical_consent_receipts(admission_id, version desc);
alter table public.admission_physical_consent_receipts enable row level security;
grant select on public.admission_physical_consent_receipts to authenticated;
revoke insert, update, delete on public.admission_physical_consent_receipts from public, anon, authenticated;
create policy admission_physical_consent_staff_read
  on public.admission_physical_consent_receipts for select to authenticated
  using (public.has_permission('admissions.view'));

create or replace function public.record_physical_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  actor uuid := auth.uid();
  c public.admission_cases;
  receipt public.admission_physical_consent_receipts;
  request_key uuid := (p_input->>'request_id')::uuid;
  admission_key uuid := (p_input->>'admission_id')::uuid;
  signed_on date := (p_input->>'guardian_signed_on')::date;
  local_today date;
  student_signed boolean := coalesce((p_input->>'student_signed')::boolean, false);
  reference text := nullif(trim(p_input->>'physical_copy_reference'), '');
  reason_text text := trim(coalesce(p_input->>'reason', ''));
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if request_key is null or admission_key is null then raise exception 'Invalid consent receipt request.'; end if;
  if signed_on is null then raise exception 'Enter a valid guardian signing date.'; end if;
  if length(reason_text) < 5 or length(reason_text) > 500 then raise exception 'Enter a staff note of 5 to 500 characters.'; end if;
  if reference is not null and length(reference) > 160 then raise exception 'Paper file location must be 160 characters or fewer.'; end if;

  perform pg_advisory_xact_lock(hashtextextended(request_key::text, 0));
  select * into receipt from public.admission_physical_consent_receipts where request_id=request_key;
  if receipt.id is not null then
    if receipt.received_by<>actor or receipt.request_payload<>p_input then
      raise exception 'This request ID was already used for another consent receipt.';
    end if;
    return jsonb_build_object('id',receipt.id,'version',receipt.version);
  end if;

  select * into c from public.admission_cases where id=admission_key for update;
  if c.id is null or c.status not in ('DRAFT','READY') then
    raise exception 'Paper consent can be received only before acceptance.';
  end if;
  select (now() at time zone o.timezone)::date into local_today
  from public.organizations o where o.id=c.organization_id;
  if signed_on > local_today then raise exception 'Guardian signing date cannot be in the future.'; end if;
  insert into public.admission_physical_consent_receipts(
    request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,
    physical_copy_reference,received_by,reason
  )
  values(
    request_key,p_input,c.id,
    (select coalesce(max(r.version),0)+1 from public.admission_physical_consent_receipts r where r.admission_id=c.id),
    signed_on,student_signed,reference,actor,reason_text
  ) returning * into receipt;

  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',receipt.id::text,'RECEIVE_PHYSICAL_SIGNED_FORM',to_jsonb(receipt));
  return jsonb_build_object('id',receipt.id,'version',receipt.version);
end $$;
revoke all on function public.record_physical_admission_consent(jsonb) from public, anon;
grant execute on function public.record_physical_admission_consent(jsonb) to authenticated;

-- Make a staff-recorded paper receipt satisfy the same transactional acceptance gate.
do $migration$
declare definition text; old_gate text; new_gate text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  if position('admission_physical_consent_receipts' in definition)>0 then return; end if;
  old_gate := $old$
      if v_case.consent_required and not exists (
        select 1 from public.admission_consent_documents d
        where d.admission_id = v_case.id
      ) then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;$old$;
  new_gate := $new$
      if v_case.consent_required
        and not exists (select 1 from public.admission_consent_documents d where d.admission_id = v_case.id)
        and not exists (select 1 from public.admission_physical_consent_receipts r where r.admission_id = v_case.id)
      then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;$new$;
  if position(old_gate in definition)=0 then
    raise exception 'Could not extend the admission consent gate; inspect admission_command before migrating.';
  end if;
  execute replace(definition,old_gate,new_gate);
end;
$migration$;
