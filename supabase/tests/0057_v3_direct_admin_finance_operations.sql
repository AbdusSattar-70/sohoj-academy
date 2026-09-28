-- V3 direct finance regression checks.
-- Development-only fixtures; rolled back. Run as database owner.

begin;

do $$
declare
  u uuid:=gen_random_uuid();
  unprivileged uuid:=gen_random_uuid();
  org uuid;
  branch uuid;
  class_id uuid;
  program uuid;
  year_id uuid;
  offering_id uuid;
  fee_id uuid;
  batch_id uuid;
  prospect_id uuid;
  finance_admission_id uuid;
  invoice_id uuid;
  payment_id uuid;
  method_id uuid;
  result jsonb;
  input jsonb;
  balance record;
  approval_count integer;
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values(
    u,
    'finance-v3-'||u||'@example.invalid',
    '{"full_name":"Finance V3 Test"}'
  );

  perform public.bootstrap_admin('finance-v3-'||u||'@example.invalid','Finance V3 Test');
  perform set_config('request.jwt.claim.sub',u::text,true);

  select id into org from public.organizations where code='SOHOJ';
  select id into branch from public.branches where organization_id=org and is_active limit 1;
  select id into class_id from public.classes where organization_id=org limit 1;
  select id into program from public.programs where organization_id=org limit 1;

  insert into public.academic_years(
    organization_id,name,starts_on,ends_on,is_active
  )
  values(
    org,'V3-FIN-'||left(u::text,8),current_date,current_date+365,false
  )
  returning id into year_id;

  result:=public.create_programme_offering(jsonb_build_object(
    'branch_id',branch,
    'academic_year_id',year_id,
    'class_id',class_id,
    'program_id',program,
    'code','V3-FIN-'||left(u::text,8),
    'name','Finance V3 Test Offering',
    'reason','Test direct finance operations'
  ));
  offering_id:=(result->>'offering_id')::uuid;

  result:=public.publish_fee_plan(jsonb_build_object(
    'offering_id',offering_id,
    'billing_cycle','TERM',
    'effective_from',current_date,
    'reason','Test finance terms',
    'components','[
      {"code":"TUITION","name":"Tuition","amount":2500,"charge_type":"TUITION","recurrence":"PER_CYCLE"},
      {"code":"ADMISSION","name":"Admission","amount":100,"charge_type":"ADMISSION","recurrence":"ONE_TIME"}
    ]'::jsonb
  ));
  fee_id:=(result->>'fee_plan_version_id')::uuid;

  result:=public.admission_command(jsonb_build_object(
    'action','CREATE_BATCH',
    'request_id',gen_random_uuid(),
    'reason','Create finance V3 batch',
    'offering_id',offering_id,
    'code','V3-FIN-'||left(u::text,8),
    'name','Finance V3 Batch',
    'capacity',10
  ));
  batch_id:=(result->>'id')::uuid;

  insert into public.prospects(
    organization_id,student_name,guardian_name,mobile,current_class_id
  )
  values(
    org,
    'Finance V3 Student '||left(u::text,8),
    'Finance V3 Guardian',
    '0170000'||right(u::text,4),
    class_id
  )
  returning id into prospect_id;

  result:=public.admission_command(jsonb_build_object(
    'action','CREATE',
    'request_id',gen_random_uuid(),
    'reason','Create finance V3 admission',
    'prospect_id',prospect_id,
    'offering_id',offering_id,
    'batch_id',batch_id
  ));
  finance_admission_id:=(result->>'id')::uuid;

  update public.admission_cases
  set consent_required=false
  where id=finance_admission_id;

  perform public.admission_command(jsonb_build_object(
    'action','READY',
    'request_id',gen_random_uuid(),
    'reason','Prepare finance V3 admission',
    'admission_id',finance_admission_id
  ));

  perform public.referral_command(jsonb_build_object(
    'action','CAPTURE',
    'request_id',gen_random_uuid(),
    'admission_id',finance_admission_id,
    'source','ORGANIC',
    'reason','Use organic source in finance test'
  ));

  perform public.record_physical_admission_consent(jsonb_build_object(
    'request_id',gen_random_uuid(),
    'admission_id',finance_admission_id,
    'guardian_signed_on',current_date,
    'student_signed',false,
    'reason','Record finance test paper consent'
  ));

  perform public.admission_command(jsonb_build_object(
    'action','ACCEPT',
    'request_id',gen_random_uuid(),
    'reason','Accept finance V3 admission',
    'admission_id',finance_admission_id
  ));

  perform public.admission_command(jsonb_build_object(
    'action','BILL',
    'request_id',gen_random_uuid(),
    'reason','Post finance V3 initial invoice',
    'admission_id',finance_admission_id
  ));

  select ai.id into invoice_id
  from public.admission_invoices ai
  where ai.admission_id=finance_admission_id
    and ai.invoice_kind='INITIAL';

  select id into method_id
  from public.payment_methods
  where is_active
  limit 1;

  perform public.post_admission_payment(jsonb_build_object(
    'request_id',gen_random_uuid(),
    'admission_id',finance_admission_id,
    'invoice_id',invoice_id,
    'payment_method_id',method_id,
    'amount',2600,
    'reason','Pay finance V3 test invoice'
  ));

  select id into payment_id
  from public.admission_payments
  where student_id=(select student_id from public.admission_cases where id=finance_admission_id)
  order by posted_at desc
  limit 1;

  select count(*) into approval_count
  from public.approval_requests;

  input:=jsonb_build_object(
    'action','APPLY_DISCOUNT',
    'request_id',gen_random_uuid(),
    'reason','Direct admin tuition correction for V3 finance test',
    'admission_id',finance_admission_id,
    'kind','FIXED',
    'value',500,
    'starts_on',current_date,
    'ends_on',current_date+365
  );

  result:=public.finance_v3_command(input);

  if (result->>'message') not like 'Discount applied%' then
    raise exception 'Direct discount did not complete.';
  end if;

  if public.finance_v3_command(input)<>result then
    raise exception 'Direct discount was not idempotent.';
  end if;

  if (select ad.approval_id from public.admission_discounts ad where ad.admission_id=finance_admission_id) is not null then
    raise exception 'V3 discount created a generic approval request.';
  end if;

  if (select ad.authorized_by from public.admission_discounts ad where ad.admission_id=finance_admission_id)<>u then
    raise exception 'Discount actor was not recorded.';
  end if;

  select * into balance from public.invoice_balance(invoice_id);

  if balance.net<>2100 or balance.paid<>2600 or balance.credit_balance<>500 then
    raise exception 'Discount changed financial facts incorrectly.';
  end if;

  input:=jsonb_build_object(
    'action','POST_REFUND',
    'request_id',gen_random_uuid(),
    'reason','Return direct customer credit in V3 finance test',
    'invoice_id',invoice_id,
    'payment_id',payment_id,
    'amount',500,
    'payment_method_id',method_id
  );

  result:=public.finance_v3_command(input);

  if (result->>'refund_no') is null then
    raise exception 'Direct refund did not create a permanent refund number.';
  end if;

  select * into balance from public.invoice_balance(invoice_id);

  if balance.refunded<>500 or balance.credit_balance<>0 then
    raise exception 'Direct refund did not reconcile the credit balance.';
  end if;

  if (select ra.approval_id from public.refund_authorizations ra where ra.payment_id=payment_id order by ra.created_at desc limit 1) is not null then
    raise exception 'V3 refund created a generic approval request.';
  end if;

  input:=jsonb_build_object(
    'action','CANCEL_ADMISSION',
    'request_id',gen_random_uuid(),
    'reason','End finance V3 test enrollment',
    'admission_id',finance_admission_id,
    'settlement','KEEP_CHARGES'
  );

  result:=public.finance_v3_command(input);

  if (select ac.approval_id from public.admission_cancellations ac where ac.admission_id=finance_admission_id) is not null then
    raise exception 'V3 cancellation created a generic approval request.';
  end if;

  if (select ac.cancelled_by from public.admission_cancellations ac where ac.admission_id=finance_admission_id)<>u then
    raise exception 'Cancellation actor was not recorded.';
  end if;

  if (select ac.status from public.admission_cases ac where ac.id=finance_admission_id)<>'CANCELLED' then
    raise exception 'Direct cancellation did not update the admission state.';
  end if;

  if (select e.status from public.enrollments e where e.id=(select ac.enrollment_id from public.admission_cases ac where ac.id=finance_admission_id))='ACTIVE' then
    raise exception 'Direct cancellation did not withdraw enrollment.';
  end if;

  if (select count(*) from public.approval_requests)=approval_count then
    -- Expected: direct operations added no approval rows. This is the actual V3 assertion.
    null;
  else
    raise exception 'Direct finance operations unexpectedly created approval requests.';
  end if;

  insert into auth.users(id,email,raw_user_meta_data)
  values(
    unprivileged,
    'finance-v3-denied-'||unprivileged||'@example.invalid',
    '{"full_name":"Finance V3 Denied"}'
  );

  perform set_config('request.jwt.claim.sub',unprivileged::text,true);

  begin
    perform public.finance_v3_command(jsonb_build_object(
      'action','CANCEL_ADMISSION',
      'request_id',gen_random_uuid(),
      'reason','Unauthorized V3 finance attempt',
      'admission_id',finance_admission_id,
      'settlement','KEEP_CHARGES'
    ));
    raise exception 'Unauthorized V3 finance command was accepted.';
  exception when others then
    if position('Admission management permission required' in sqlerrm)=0 then
      raise;
    end if;
  end;

  perform set_config('request.jwt.claim.sub',u::text,true);

  begin
    update public.admission_discounts
    set value=1
    where admission_id=finance_admission_id;
    raise exception 'Immutable finance history was writable.';
  exception when others then
    if position('immutable' in lower(sqlerrm))=0 then
      raise;
    end if;
  end;
end;
$$;

rollback;
