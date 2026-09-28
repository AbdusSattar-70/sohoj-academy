begin;
do $$
declare
 actor uuid:=gen_random_uuid(); org uuid; branch uuid; cl uuid; program uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; admission uuid; person uuid; result jsonb; today date; method uuid; reviewer uuid:=gen_random_uuid();
 approval uuid; payable uuid; cash uuid;
begin
 insert into auth.users(id,email,raw_user_meta_data)
 values(actor,'referral-test-'||actor||'@example.invalid','{"full_name":"Referral Test"}');
 perform public.bootstrap_admin('referral-test-'||actor||'@example.invalid','Referral Test');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org and code='CLASS_10';
 select id into program from public.programs where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
 values(org,'REF-'||actor,today,today+365,false) returning id into yr;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',yr,'class_id',cl,
 'program_id',program,'code','REF-'||left(actor::text,8),'name','Referral Offering','reason','Referral verification'));
 offering:=(result->>'offering_id')::uuid;
 perform public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,
 'effective_from',today,'reason','Referral test fee plan','components',
 '[{"code":"TUITION","name":"Tuition","amount":2500,"charge_type":"TUITION","recurrence":"PER_CYCLE"}]'::jsonb));
 result:=public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
 'reason','Create referral test batch','offering_id',offering,'code','REF-'||left(actor::text,8),
 'name','Referral Test Batch','capacity',10)); batch:=(result->>'id')::uuid;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id)
 values(org,'Referral Student','Guardian Person','01700000981',cl) returning id into prospect;
 result:=public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),
 'reason','Create referral admission','prospect_id',prospect,'offering_id',offering,'batch_id',batch)); admission:=(result->>'id')::uuid;
 begin
   update public.admission_cases set status='ACCEPTED' where id=admission;
   raise exception 'Missing referral choice was allowed';
 exception when others then
   if position('Record a referrer or select Organic' in sqlerrm)=0 then raise; end if;
 end;
 perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
 'admission_id',admission,'source','ORGANIC','reason','Guardian confirmed organic source'));
 if not exists(select 1 from public.admission_referrals where admission_id=admission and source='ORGANIC') then
   raise exception 'Organic source was not saved'; end if;
 perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
 'admission_id',admission,'source','REFERRED','full_name','New Community Referrer',
 'mobile','01700000982','relationship_note','Neighbour','reason','Guardian verified personal referral'));
 select referrer_id into person from public.admission_referrals where admission_id=admission;
 if not exists(select 1 from public.referral_people where id=person and mobile='01700000982') then
   raise exception 'New referrer was not registered atomically'; end if;
 perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
 'admission_id',admission,'source','REFERRED','referrer_id',person,
 'reason','Existing referrer verified again'));
 if (select count(*) from public.referral_people where mobile='01700000982')<>1 then
   raise exception 'Referrer was duplicated'; end if;
 -- This fixture explicitly opts out of the separate signed-consent gate so the
 -- referral/accounting integration can be verified in isolation.
 update public.admission_cases set consent_required=false where id=admission;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),
 'reason','Verify referral case identity','admission_id',admission));

 perform public.record_physical_admission_consent(jsonb_build_object(
   'request_id',gen_random_uuid(),'admission_id',admission,
   'guardian_signed_on',current_date,'student_signed',false,
   'reason','Verified test paper consent receipt'));
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
 'reason','Accept verified referral case','admission_id',admission));
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),
 'reason','Post referral test tuition','admission_id',admission));
 select id into method from public.payment_methods where is_active limit 1;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',admission,
 'payment_method_id',method,'amount',2500,'reason','Collect referral test tuition'));
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),
 'reason','Activate paid referral case','admission_id',admission));
 result:=public.referral_command(jsonb_build_object('action','REQUEST_BONUS','request_id',gen_random_uuid(),
 'admission_id',admission,'reason','Review verified tuition acquisition reward'));
 select approval_id into approval from public.referral_bonus_awards where id=(result->>'id')::uuid;
 if approval is null then raise exception 'Reward approval was not created'; end if;
 begin
  perform public.referral_command(jsonb_build_object('action','DECIDE_BONUS','request_id',gen_random_uuid(),
  'approval_id',approval,'decision','APPROVED','reason','Self approval is prohibited'));
  raise exception 'Self approval was allowed';
 exception when others then
  if position('different authorized staff' in sqlerrm)=0 then raise; end if;
 end;
 insert into auth.users(id,email,raw_user_meta_data) values(reviewer,
 'referral-reviewer-'||reviewer||'@example.invalid','{"full_name":"Referral Reviewer"}');
 perform public.bootstrap_admin('referral-reviewer-'||reviewer||'@example.invalid','Referral Reviewer');
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.referral_command(jsonb_build_object('action','DECIDE_BONUS','request_id',gen_random_uuid(),
 'approval_id',approval,'decision','APPROVED','reason','Independent acquisition reward approval'));
 select id into payable from public.finance_payables where source_type='REFERRAL_BONUS' and source_id=admission::text;
 if payable is null or (select original_amount from public.finance_payables where id=payable)<>1250 then
   raise exception 'Expected 50 percent first-month payable missing'; end if;
 select id into cash from public.finance_accounts where organization_id=org and code='1100';
 perform public.finance_accounting_command(jsonb_build_object('action','SETTLE_PAYABLE',
 'request_id',gen_random_uuid(),'payable_id',payable,'amount',1250,'payment_account_id',cash,
 'external_reference','TEST-REFERRAL-PAYOUT','reason','Settle approved referral payable'));
 if not exists(select 1 from public.finance_payables where id=payable and status='SETTLED') then
   raise exception 'Referral payable did not settle'; end if;
 if not exists(select 1 from public.general_ledger_journals where source_type='REFERRAL_BONUS' and source_id=(result->>'id')) then
   raise exception 'Approved reward lacks acquisition journal'; end if;
end $$;
rollback;
