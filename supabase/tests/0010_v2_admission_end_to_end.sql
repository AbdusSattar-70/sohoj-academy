-- Development-only fixtures, entirely rolled back. Run as database owner.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); org uuid; cl uuid; program uuid; branch uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; a uuid; a2 uuid; fee uuid; method uuid;
 result jsonb; input jsonb; today date; baseline jsonb;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,'admission-test-'||u||'@example.invalid','{"full_name":"Admission Test"}');
 perform public.bootstrap_admin('admission-test-'||u||'@example.invalid','Admission Test');
 perform set_config('request.jwt.claim.sub',u::text,true);
 select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org and code='CLASS_10';
 select id into program from public.programs where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active) values(org,'TEST-'||u::text,today,today+365,false) returning id into yr;
 baseline:='{"requires_admission_acceptance":true,"requires_initial_billing_posted":true,"payment_requirement":"NONE","minimum_payment_percent":0,"allow_credit_enrollment":true,"count_student_active_only_when_enrollment_active":true}'::jsonb;
 if (select payload from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE')<>baseline then
   perform public.publish_business_rule_version('admissions','activation_policy',baseline,'Establish isolated test baseline');
 end if;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',yr,'class_id',cl,'program_id',program,'code','TEST-'||left(u::text,8),'name','Test Offering','reason','Admission verification'));
 offering:=(result->>'offering_id')::uuid;
 result:=public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Verification standard fees','components',
 '[{"code":"TUITION","name":"Tuition","amount":2500,"charge_type":"TUITION","recurrence":"PER_CYCLE"},{"code":"ADMISSION","name":"Admission","amount":100,"charge_type":"ADMISSION","recurrence":"ONE_TIME"}]'::jsonb));
 fee:=(result->>'fee_plan_version_id')::uuid;
 input:=jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'reason','Create verification batch','offering_id',offering,'code','TEST-'||left(u::text,8),'name','Verification Batch','capacity',1);
 result:=public.admission_command(input); batch:=(result->>'id')::uuid;
 if public.admission_command(input)<>result then raise exception 'Batch retry was not idempotent.'; end if;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id) values(org,'Mock Admission Student '||u::text,'Mock Guardian','01700000991',cl) returning id into prospect;
 input:=jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'reason','Create verification admission','prospect_id',prospect,'batch_id',batch);
 result:=public.admission_command(input); a:=(result->>'id')::uuid;
 if public.admission_command(input)<>result then raise exception 'Admission retry was not idempotent.'; end if;
 begin
  perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'reason','Attempt invalid state','admission_id',a));
  raise exception 'Invalid state was accepted';
 exception when others then if sqlerrm not like '%not allowed%' then raise; end if; end;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'reason','Verify identity and fees','admission_id',a));
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),'reason','Accept reviewed admission','admission_id',a));
 if exists(select 1 from public.enrollments e join public.admission_cases ac on ac.student_id=e.student_id where ac.id=a) then raise exception 'Acceptance activated enrollment early.'; end if;
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'reason','Post standard initial billing','admission_id',a));
 if (select total from public.admission_invoices where admission_id=a)<>2600 then raise exception 'Inherited billing total is wrong.'; end if;
 if exists(select 1 from public.admission_payments where student_id=(select student_id from public.admission_cases where id=a)) then raise exception 'Billing fabricated a payment.'; end if;
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'reason','Evaluate admission policy','admission_id',a));
 if (select status from public.admission_cases where id=a)<>'ACTIVE_ENROLLMENT' then raise exception 'Default credit policy did not activate.'; end if;
 select id into method from public.payment_methods where is_active limit 1;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a,'payment_method_id',method,'amount',500,'reason','Collect actual test payment');
 result:=public.post_admission_payment(input);
 if public.post_admission_payment(input)<>result then raise exception 'Payment retry was not idempotent.'; end if;
 if (select count(*) from public.admission_payments where student_id=(select student_id from public.admission_cases where id=a))<>1 then raise exception 'Duplicate payment.'; end if;
 begin
  perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a,'payment_method_id',method,'amount',2600,'reason','Attempt overpayment'));
  raise exception 'Overpayment was accepted';
 exception when others then if sqlerrm not like '%exceeds%' then raise; end if; end;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id) values(org,'Mock Second Student '||u::text,'Mock Second Guardian','01700000992',cl) returning id into prospect;
 begin
  perform public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'reason','Attempt over-capacity admission','prospect_id',prospect,'batch_id',batch));
  raise exception 'Full batch was accepted';
 exception when others then if sqlerrm not like '%full%' then raise; end if; end;
 perform public.publish_business_rule_version('admissions','activation_policy','{"requires_admission_acceptance":true,"requires_initial_billing_posted":true,"payment_requirement":"FULL","minimum_payment_percent":100,"allow_credit_enrollment":false,"count_student_active_only_when_enrollment_active":true}', 'Verify full-payment policy');
 result:=public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'reason','Create second verification batch','offering_id',offering,'code','TEST2-'||left(u::text,8),'name','Second Verification Batch','capacity',1));
 batch:=(result->>'id')::uuid;
 result:=public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'reason','Create second admission','prospect_id',prospect,'batch_id',batch)); a2:=(result->>'id')::uuid;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'reason','Verify second identity','admission_id',a2));
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),'reason','Accept second admission','admission_id',a2));
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'reason','Post second invoice','admission_id',a2));
 -- Later settings must not silently rewrite the accepted case's policy.
 perform public.publish_business_rule_version('admissions','activation_policy','{"requires_admission_acceptance":true,"requires_initial_billing_posted":true,"payment_requirement":"NONE","minimum_payment_percent":0,"allow_credit_enrollment":true,"count_student_active_only_when_enrollment_active":true}', 'Restore credit policy after acceptance');
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'reason','Evaluate unpaid admission','admission_id',a2));
 if (select status from public.admission_cases where id=a2)<>'PENDING_PAYMENT' then raise exception 'Full payment policy was bypassed.'; end if;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a2,'payment_method_id',method,'amount',2600,'reason','Collect full initial payment'));
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'reason','Activate after actual payment','admission_id',a2));
 if (select status from public.admission_cases where id=a2)<>'ACTIVE_ENROLLMENT' then raise exception 'Paid admission did not activate.'; end if;
 if jsonb_array_length(public.admission_workspace()->'cases')<2 then raise exception 'Workspace read model incomplete.'; end if;
 if has_table_privilege('authenticated','public.admission_payments','INSERT') or has_table_privilege('authenticated','public.enrollments','INSERT') then raise exception 'Controlled workflow can be bypassed.'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin
  perform public.admission_workspace(); raise exception 'Anonymous read accepted';
 exception when others then if sqlerrm not like '%denied%' then raise; end if; end;
end; $$;
rollback;
