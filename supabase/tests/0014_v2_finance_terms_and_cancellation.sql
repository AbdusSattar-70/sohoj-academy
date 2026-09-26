-- Development-only fixtures, entirely rolled back. Run as database owner.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); org uuid; cl uuid; program uuid; branch uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; a uuid; a2 uuid; fee uuid; method uuid;
 result jsonb; input jsonb; today date; baseline jsonb; reviewer uuid:=gen_random_uuid(); unprivileged uuid:=gen_random_uuid(); term_id uuid; invoice uuid; preview jsonb;
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
 result:=public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','TERM','effective_from',today,'reason','Verification standard fees','components',
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

 insert into auth.users(id,email,raw_user_meta_data) values(reviewer,'term-reviewer-'||reviewer||'@example.invalid','{"full_name":"Term Reviewer"}');
 perform public.bootstrap_admin('term-reviewer-'||reviewer||'@example.invalid','Term Reviewer');
 if jsonb_array_length(public.billing_preview((date_trunc('month',today)+interval '1 month')::date)->'rows')<>0 then raise exception 'Term student billed monthly'; end if;
 result:=public.finance_command(jsonb_build_object('action','CREATE_TERM','request_id',gen_random_uuid(),'academic_year_id',yr,'name','Second Term','starts_on',today+30,'ends_on',today+120,'due_on',today+35,'reason','Create second academic term'));
 term_id:=(result->>'id')::uuid;
 begin
  perform public.finance_command(jsonb_build_object('action','CREATE_TERM','request_id',gen_random_uuid(),'academic_year_id',yr,'name','Overlap Term','starts_on',today+60,'ends_on',today+130,'due_on',today+65,'reason','Test overlap protection'));
  raise exception 'Overlapping term accepted';
 exception when others then if sqlerrm not like '%overlaps%' then raise; end if; end;
 preview:=public.billing_preview(today+30,term_id);
 if jsonb_array_length(preview->'rows')<>1 or (preview->>'netTotal')::numeric<>2500 then raise exception 'Term preview incorrect'; end if;
 perform public.finance_command(jsonb_build_object('action','RUN_BILLING','request_id',gen_random_uuid(),'period',today+30,'term_id',term_id,'preview_token',preview->>'token','reason','Post reviewed term charges'));
 if jsonb_array_length(public.billing_preview(today+30,term_id)->'rows')<>0 then raise exception 'Term billed twice'; end if;
 result:=public.finance_command(jsonb_build_object('action','REQUEST_CANCEL','request_id',gen_random_uuid(),'admission_id',a,'settlement','KEEP_CHARGES','reason','Cancel while preserving receivable'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Verify keep charges cancellation'));
 select id into invoice from public.admission_invoices where admission_id=a and invoice_kind='INITIAL';
 if (select due from public.invoice_balance(invoice))<>2600 then raise exception 'Keep charges cancellation erased debt'; end if;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a,'invoice_id',invoice,'payment_method_id',method,'amount',2600,'reason','Settle debt after withdrawal'));
 if (select due from public.invoice_balance(invoice))<>0 then raise exception 'Could not settle cancelled case'; end if;
 -- Cancelled draft permits a fresh case for the still-unconverted prospect.
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id) values(org,'Replacement Draft '||u::text,'Draft Guardian','01700000995',cl) returning id into prospect;
 result:=public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'prospect_id',prospect,'batch_id',batch,'reason','Create cancellable draft'));a2:=(result->>'id')::uuid;
 result:=public.finance_command(jsonb_build_object('action','REQUEST_CANCEL','request_id',gen_random_uuid(),'admission_id',a2,'settlement','KEEP_CHARGES','reason','Cancel draft before acceptance'));
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Approve draft cancellation'));
 result:=public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'prospect_id',prospect,'batch_id',batch,'reason','Restart cancelled draft'));a2:=(result->>'id')::uuid;
 -- A fixed scholarship approved before initial billing is inherited as a credit.
 result:=public.finance_command(jsonb_build_object('action','REQUEST_DISCOUNT','request_id',gen_random_uuid(),'admission_id',a2,'kind','FIXED','value',3000,'starts_on',date_trunc('month',today)::date,'ends_on',today+365,'reason','Full tuition scholarship before billing'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Independently verify scholarship'));
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'admission_id',a2,'reason','Verify discounted admission'));
 perform public.publish_business_rule_version('admissions','activation_policy','{"requires_admission_acceptance":true,"requires_initial_billing_posted":true,"payment_requirement":"FULL","minimum_payment_percent":100,"allow_credit_enrollment":false,"count_student_active_only_when_enrollment_active":true}', 'Verify discounted full payment threshold');
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),'admission_id',a2,'reason','Accept discounted admission'));
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'admission_id',a2,'reason','Bill discounted admission'));
 select id into invoice from public.admission_invoices where admission_id=a2;
 if (select net from public.invoice_balance(invoice))<>100 then raise exception 'Fixed discount not capped at tuition'; end if;
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'admission_id',a2,'reason','Check discounted unpaid activation'));
 if (select status from public.admission_cases where id=a2)<>'PENDING_PAYMENT' then raise exception 'Unpaid net charge bypassed policy'; end if;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a2,'payment_method_id',method,'amount',100,'reason','Pay discounted net balance'));
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'admission_id',a2,'reason','Check discounted paid activation'));
 if (select status from public.admission_cases where id=a2)<>'ACTIVE_ENROLLMENT' then raise exception 'Paid net charge failed activation'; end if;
 insert into auth.users(id,email,raw_user_meta_data) values(unprivileged,'no-finance-'||unprivileged||'@example.invalid','{"full_name":"No Finance"}');
 perform set_config('request.jwt.claim.sub',unprivileged::text,true);
 begin
  perform public.finance_command(jsonb_build_object('action','REQUEST_CANCEL','request_id',gen_random_uuid(),'admission_id',a2,'settlement','KEEP_CHARGES','reason','Unauthorized cancellation attempt'));
  raise exception 'Unauthorized command accepted';
 exception when others then if sqlerrm not like '%Permission denied%' then raise; end if; end;
 begin
  perform public.billing_preview(today+30,term_id);raise exception 'Unauthorized preview accepted';
 exception when others then if sqlerrm not like '%permission required%' then raise; end if; end;
end; $$;
rollback;
