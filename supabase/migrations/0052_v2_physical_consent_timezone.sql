-- Resolve the organization-local consent date through the admission's batch.
-- admission_cases intentionally has no organization_id column.
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
  if c.id is null or c.status='CANCELLED' then
    raise exception 'Paper consent can be recorded only for an open admission case.';
  end if;
  if c.status='DRAFT' then
    raise exception 'Complete application verification before recording paper consent.';
  end if;
  if not exists(select 1 from public.admission_referrals r where r.admission_id=c.id) then
    raise exception 'Record the admission source before recording signed paper consent.';
  end if;

  select (now() at time zone o.timezone)::date into local_today
  from public.batches b
  join public.organizations o on o.id=b.organization_id
  where b.id=c.batch_id;
  if local_today is null then
    raise exception 'The admission batch organization timezone is unavailable.';
  end if;
  if signed_on > local_today then raise exception 'Guardian signing date cannot be in the future.'; end if;
  if exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=c.id) then
    raise exception 'A paper-consent receipt is already recorded for this case.';
  end if;

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
