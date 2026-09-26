-- Development-only fixtures, entirely rolled back. Run as database owner.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); org uuid; cl uuid; program uuid; branch uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; a uuid; a2 uuid; fee uuid; method uuid;
 result jsonb; input jsonb; today date; baseline jsonb;
 reviewer uuid:=gen_random_uuid(); approval_id uuid; invoice uuid; pay_id uuid; authorization_id uuid; preview jsonb; period date; balance record;
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

 insert into auth.users(id,email,raw_user_meta_data) values(reviewer,'reviewer-'||reviewer||'@example.invalid','{"full_name":"Independent Reviewer"}');
 perform public.bootstrap_admin('reviewer-'||reviewer||'@example.invalid','Independent Reviewer');
 select id into invoice from public.admission_invoices where admission_id=a;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a,'payment_method_id',method,'amount',2600,'reason','Collect full actual payment'));
 select payment_id into pay_id from public.admission_payment_allocations where invoice_id=invoice;
 -- A refund requires credit; full payment alone is not refundable.
 begin
  perform public.finance_command(jsonb_build_object('action','REQUEST_REFUND','request_id',gen_random_uuid(),'payment_id',pay_id,'amount',1,'reason','No credit refund attempt'));
  raise exception 'Unbacked refund accepted';
 exception when others then if sqlerrm not like '%exceeds%' then raise; end if; end;
 input:=jsonb_build_object('action','REQUEST_DISCOUNT','request_id',gen_random_uuid(),'admission_id',a,'kind','PERCENT','value',20,'starts_on',date_trunc('month',today)::date,'ends_on',today+365,'reason','Approved scholarship verification');
 result:=public.finance_command(input); approval_id:=(result->>'id')::uuid;
 if public.finance_command(input)<>result then raise exception 'Discount request not idempotent'; end if;
 begin
  perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Attempt self approval'));
  raise exception 'Self approval accepted';
 exception when others then if sqlerrm not like '%Maker-checker%' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 input:=jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Independently verify scholarship');
 result:=public.finance_command(input);
 if public.finance_command(input)<>result then raise exception 'Approval retry not idempotent'; end if;
 select * into balance from public.invoice_balance(invoice);
 if balance.gross<>2600 or balance.credits<>500 or balance.net<>2100 or balance.credit_balance<>500 or balance.refunded<>0 then raise exception 'Discount balances wrong: %',row_to_json(balance); end if;
 -- Overlapping discount approval cannot stack the tuition concession.
 perform set_config('request.jwt.claim.sub',u::text,true);
 result:=public.finance_command(jsonb_build_object('action','REQUEST_DISCOUNT','request_id',gen_random_uuid(),'admission_id',a,'kind','FIXED','value',100,'starts_on',today,'ends_on',today+365,'reason','Overlapping discount test'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 begin
  perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Test overlapping approval'));
  raise exception 'Overlapping discount accepted';
 exception when others then if sqlerrm not like '%overlaps%' then raise; end if; end;
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','REJECTED','reason','Reject overlapping scholarship'));
 -- Monthly billing: excludes admission charge; applies approved tuition discount.
 period:=(date_trunc('month',today)+interval '1 month')::date;
 preview:=public.billing_preview(period);
 if jsonb_array_length(preview->'rows')<>1 or (preview->>'netTotal')::numeric<>2000 then raise exception 'Recurring preview wrong: %',preview; end if;
 input:=jsonb_build_object('action','RUN_BILLING','request_id',gen_random_uuid(),'period',period,'preview_token',preview->>'token','reason','Post reviewed monthly charges');
 result:=public.finance_command(input);
 if public.finance_command(input)<>result then raise exception 'Billing retry not idempotent'; end if;
 if (select count(*) from public.admission_invoices where admission_id=a)<>2 then raise exception 'Recurring invoice count wrong'; end if;
 if (select total from public.admission_invoices where admission_id=a and invoice_kind='RECURRING')<>2500 then raise exception 'One-time charge billed again'; end if;
 begin
  perform public.finance_command(input||jsonb_build_object('request_id',gen_random_uuid()));
  raise exception 'Stale preview accepted';
 exception when others then if sqlerrm not like '%preview changed%' then raise; end if; end;
 if jsonb_array_length(public.billing_preview(period)->'rows')<>0 then raise exception 'Already billed cycle repeated'; end if;
 -- Actual payment against explicit recurring invoice.
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',a,'invoice_id',(select id from public.admission_invoices where admission_id=a and invoice_kind='RECURRING'),'payment_method_id',method,'amount',100,'reason','Collect recurring payment'));
 -- Refund authorization is not a payout.
 perform set_config('request.jwt.claim.sub',u::text,true);
 result:=public.finance_command(jsonb_build_object('action','REQUEST_REFUND','request_id',gen_random_uuid(),'payment_id',pay_id,'amount',500,'reason','Return approved tuition credit'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Independently verify refund credit'));
 select id into authorization_id from public.refund_authorizations where payment_id=pay_id;
 select * into balance from public.invoice_balance(invoice);
 if balance.refunded<>0 or balance.reserved_refunds<>500 or balance.credit_balance<>500 then raise exception 'Authorization falsely records cash movement'; end if;
 begin
  perform public.finance_command(jsonb_build_object('action','REQUEST_REFUND','request_id',gen_random_uuid(),'payment_id',pay_id,'amount',1,'reason','Attempt double reservation'));
  raise exception 'Reserved credit spent again';
 exception when others then if sqlerrm not like '%exceeds%' then raise; end if; end;
 input:=jsonb_build_object('action','POST_REFUND','request_id',gen_random_uuid(),'authorization_id',authorization_id,'payment_method_id',method,'external_reference','TEST-REFUND-'||u,'reason','Confirm actual refund paid');
 result:=public.finance_command(input);
 if public.finance_command(input)<>result then raise exception 'Refund retry not idempotent'; end if;
 select * into balance from public.invoice_balance(invoice);
 if balance.refunded<>500 or balance.credit_balance<>0 or balance.reserved_refunds<>0 or balance.due<>0 then raise exception 'Refund payout balances wrong'; end if;
 begin
  perform public.finance_command(input||jsonb_build_object('request_id',gen_random_uuid()));
  raise exception 'Duplicate payout accepted';
 exception when others then if sqlerrm not like '%already paid%' then raise; end if; end;
 -- Cancellation credits preserve history, withdraw the enrollment and stop billing.
 perform set_config('request.jwt.claim.sub',u::text,true);
 result:=public.finance_command(jsonb_build_object('action','REQUEST_CANCEL','request_id',gen_random_uuid(),'admission_id',a,'settlement','CREDIT_ALL','reason','Cancel remaining tuition contract'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Approve cancellation and credit'));
 if (select status from public.admission_cases where id=a)<>'CANCELLED' or exists(select 1 from public.enrollments where id=(select enrollment_id from public.admission_cases where id=a) and status='ACTIVE') then raise exception 'Cancellation did not withdraw enrollment'; end if;
 select * into balance from public.invoice_balance(invoice);
 if balance.gross<>2600 or balance.net<>0 or balance.credit_balance<>2100 or balance.paid<>2600 then raise exception 'Cancellation erased or misstated history'; end if;
 if jsonb_array_length(public.billing_preview((period+interval '1 month')::date)->'rows')<>0 then raise exception 'Cancelled admission billed'; end if;
 if jsonb_array_length(public.finance_workspace()->'invoices')<2 then raise exception 'Finance workspace incomplete'; end if;
 if public.admission_workspace()->'cases'->0->>'status'<>'CANCELLED' then raise exception 'Admission workspace missing cancellation'; end if;
 begin
  update public.admission_payments set amount=1 where id=pay_id;
  raise exception 'Historical payment rewritten';
 exception when others then if sqlerrm not like '%immutable%' then raise; end if; end;
 if has_table_privilege('authenticated','public.refund_payouts','INSERT') or has_table_privilege('authenticated','public.approval_requests','UPDATE') then raise exception 'Controlled finance workflow bypassable'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin
  perform public.finance_workspace();raise exception 'Anonymous finance read accepted';
 exception when others then if sqlerrm not like '%denied%' then raise; end if; end;
end; $$;
rollback;
