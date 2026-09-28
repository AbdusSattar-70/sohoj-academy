-- Rollback-only end-to-end physical paper consent and acceptance gate test.
begin;
do $$
declare
  actor uuid:=gen_random_uuid(); org uuid; branch uuid; cl uuid; program uuid; year_id uuid;
  offering uuid; batch uuid; admission uuid; result jsonb; retry jsonb; intake_result jsonb;
  today date; request_id uuid:=gen_random_uuid(); receipt_input jsonb; case_number text;
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values(actor,'paper-consent-'||actor||'@example.invalid','{"full_name":"Paper Consent Test"}');
  perform public.bootstrap_admin('paper-consent-'||actor||'@example.invalid','Paper Consent Test');
  perform set_config('request.jwt.claim.sub',actor::text,true);
  select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
  select id into branch from public.branches where organization_id=org limit 1;
  select id into cl from public.classes where organization_id=org and code='CLASS_10';
  select id into program from public.programs where organization_id=org limit 1;
  insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
  values(org,'PAPER-'||actor,today,today+365,false) returning id into year_id;
  result:=public.create_programme_offering(jsonb_build_object(
    'branch_id',branch,'academic_year_id',year_id,'class_id',cl,'program_id',program,
    'code','PAPER-'||left(actor::text,8),'name','Paper Consent Test Offering','reason','Consent acceptance test'));
  offering:=(result->>'offering_id')::uuid;
  perform public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY',
    'due_day',10,'effective_from',today,'reason','Paper consent test fee',
    'components','[{"code":"TUITION","name":"Tuition","amount":1500,"charge_type":"TUITION","recurrence":"PER_CYCLE"},{"code":"ADMISSION","name":"Admission","amount":0,"charge_type":"ADMISSION","recurrence":"ONE_TIME"}]'::jsonb));
  result:=public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
    'reason','Create consent test batch','offering_id',offering,'code','PC-'||left(actor::text,8),
    'name','Paper Consent Test Batch','capacity',10));
  batch:=(result->>'id')::uuid;

  intake_result:=public.create_staff_admission_intake(jsonb_build_object(
    'request_id',gen_random_uuid(),'offering_id',offering,'batch_id',batch,
    'student_name','Paper applicant '||actor::text,'student_name_bn',null,'date_of_birth',date '2014-04-21',
    'gender','Female','school_name','Sample School','school_roll','PAPER-1',
    'guardian_name','Paper guardian '||actor::text,'guardian_relationship','Mother',
    'mobile','017'||lpad(mod(abs(hashtext(actor::text)::bigint),100000000)::text,8,'0'),'alternate_mobile',null,'guardian_address','Paper file test',
    'consent_to_contact',true,'reason','Guardian completed paper consent test intake'));
  admission:=(intake_result->>'admission_id')::uuid;
  perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
    'admission_id',admission,'source','ORGANIC','reason','Guardian confirmed no referrer'));
  perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),
    'reason','Verified identity placement and fees','admission_id',admission));

  begin
    perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
      'reason','Attempt acceptance without signed paper','admission_id',admission));
    raise exception 'Admission was accepted without signed consent evidence.';
  exception when others then
    if position('A recorded signed consent receipt is required' in sqlerrm)=0 then raise; end if;
  end;

  -- Simulate a grandfathered admission, which may have been accepted without
  -- evidence before the consent gate existed. Billing remains blocked until
  -- staff reconciles the physically filed form.
  update public.admission_cases set consent_required=false where id=admission;
  perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
    'reason','Accept verified legacy applicant','admission_id',admission));
  if not exists(select 1 from public.admission_cases where id=admission and status='ACCEPTED' and student_id is not null) then
    raise exception 'The legacy admission fixture did not reach Accepted.';
  end if;
  begin
    perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),
      'reason','Attempt billing without consent','admission_id',admission));
    raise exception 'Billing was allowed before the missing paper consent was reconciled.';
  exception when others then
    if position('Record the signed paper consent' in sqlerrm)=0 then raise; end if;
  end;

  receipt_input:=jsonb_build_object(
    'request_id',request_id,'admission_id',admission,'guardian_signed_on',today,
    'student_signed',false,'physical_copy_reference','Admissions cabinet · test folder',
    'reason','Verified signed paper and filed original');
  result:=public.record_physical_admission_consent(receipt_input);
  retry:=public.record_physical_admission_consent(receipt_input);
  if result<>retry or (result->>'version')::integer<>1 then
    raise exception 'Physical-consent receipt retry was not idempotent.';
  end if;
  if not exists(select 1 from public.admission_physical_consent_receipts
      where admission_id=admission and received_by=actor and physical_copy_reference='Admissions cabinet · test folder') then
    raise exception 'Paper consent receipt metadata was not stored.';
  end if;

  perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),
    'reason','Post verified initial bill','admission_id',admission));
  if not exists(select 1 from public.admission_invoices where admission_id=admission and total=1500) then
    raise exception 'Initial billing did not post the expected invoice total.';
  end if;
  if (select count(*) from public.general_ledger_lines l
      join public.general_ledger_journals j on j.id=l.journal_id
      join public.admission_invoices i on i.id::text=j.source_id
      where i.admission_id=admission and j.source_type='ADMISSION_INVOICE')<>2 then
    raise exception 'Zero-value fee component was not omitted from the general ledger.';
  end if;
  if exists(select 1 from public.general_ledger_lines l
      join public.general_ledger_journals j on j.id=l.journal_id
      join public.admission_invoices i on i.id::text=j.source_id
      where i.admission_id=admission and j.source_type='ADMISSION_INVOICE'
        and l.debit=0 and l.credit=0) then
    raise exception 'General ledger contains a zero-value line.';
  end if;
  if has_table_privilege('authenticated','public.admission_physical_consent_receipts','INSERT') then
    raise exception 'Authenticated users can directly insert consent receipts.';
  end if;
end $$;
rollback;
