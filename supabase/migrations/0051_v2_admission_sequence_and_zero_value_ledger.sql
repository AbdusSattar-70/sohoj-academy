-- Keep the staff workflow sequential, allow late filing of physical consent,
-- and omit zero-value fee components from double-entry journals.

create or replace function public.finance_sync_invoice(p_invoice_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  i public.admission_invoices;
  a public.admission_cases;
  org uuid;
  ar uuid;
  other_revenue uuid;
  lines jsonb:='[]'::jsonb;
begin
  select * into i from public.admission_invoices where id=p_invoice_id;
  if i.id is null or i.total <= 0 then return null; end if;

  select * into a from public.admission_cases where id=i.admission_id;
  select organization_id into org from public.students where id=i.student_id;

  select id into ar from public.finance_accounts
  where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into other_revenue from public.finance_accounts
  where organization_id=org and account_subtype='OTHER_FEE_REVENUE' and is_active limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'account_id',coalesce(m.account_id,other_revenue),
      'debit',0,
      'credit',l.amount,
      'memo',l.name,
      'branch_id',b.branch_id,
      'program_id',b.program_id,
      'batch_id',b.id
    )
  ),'[]'::jsonb)
  into lines
  from public.admission_invoice_lines l
  left join public.finance_fee_revenue_map m
    on m.organization_id=org and m.charge_type=l.charge_type
  join public.admission_cases ac on ac.id=i.admission_id
  join public.batches b on b.id=ac.batch_id
  where l.invoice_id=i.id and l.amount>0;

  if jsonb_array_length(lines)=0 then
    raise exception 'A positive invoice has no positive charge lines.';
  end if;

  lines:=jsonb_build_array(
    jsonb_build_object(
      'account_id',ar,
      'debit',i.total,
      'credit',0,
      'memo','Student receivable'
    )
  ) || lines;

  return public.finance_post_journal(
    org,i.issued_on,
    'INVOICE','ADMISSION_INVOICE',i.id::text,
    'Invoice '||i.invoice_no,
    i.posted_by,lines
  );
end;
$$;

-- Old accepted cases may predate the physical receipt screen. Let staff append
-- the paper-receipt evidence later so those cases can rejoin the normal process.
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
  from public.organizations o where o.id=c.organization_id;
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

-- A missing referral can also be reconciled on a legacy accepted case, but a
-- captured source cannot be changed after acceptance or reward processing.
do $migration$
declare
  definition text;
  old_guard text := $$a.id is null or a.status not in('DRAFT','READY')$$;
  new_guard text := $$a.id is null or a.status='CANCELLED'
    or (a.status not in('DRAFT','READY') and exists(
      select 1 from public.admission_referrals prior where prior.admission_id=a.id
    ))$$;
begin
  select pg_get_functiondef('public.referral_command(jsonb)'::regprocedure) into definition;
  if position('public.admission_referrals prior where prior.admission_id=a.id' in definition)>0 then return; end if;
  if position(old_guard in definition)=0 then
    raise exception 'Could not enable referral reconciliation for legacy admissions.';
  end if;
  definition:=replace(definition,old_guard,new_guard);
  definition:=replace(definition,
    'Referral choice must be recorded before admission acceptance.',
    'A referral can be added to an accepted case only when no source is already on file.');
  execute definition;
end;
$migration$;

-- A case cannot reach billing or enrollment while the referral and signed
-- consent checklist is incomplete. This also covers direct RPC/database calls.
create or replace function public.require_admission_workflow_evidence()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status is distinct from old.status
    and new.status in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT') then
    if not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
      raise exception 'Record the admission source before continuing to billing or enrollment.';
    end if;
    if not exists(select 1 from public.admission_consent_documents d where d.admission_id=new.id)
      and not exists(select 1 from public.admission_physical_consent_receipts p where p.admission_id=new.id) then
      raise exception 'Record the signed paper consent before continuing to billing or enrollment.';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists admission_workflow_evidence_gate on public.admission_cases;
create trigger admission_workflow_evidence_gate
before update of status on public.admission_cases
for each row execute function public.require_admission_workflow_evidence();
revoke execute on function public.require_admission_workflow_evidence() from public, anon, authenticated;
