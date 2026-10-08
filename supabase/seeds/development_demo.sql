-- Explicit development/test data. Never run this against an operating academy.
-- Uses the existing bootstrap administrator; creates no Auth users/passwords.
-- All transactional examples go through the same controlled workflows as ERP.
begin;
do $demo$
declare
  actor uuid; org uuid; campus uuid; academic_year uuid; class_eight uuid;
  class_ten uuid; science uuid; ssc_program uuid; annual_program uuid;
  ssc_offering uuid; annual_offering uuid; morning uuid; evening uuid;
  annual_batch uuid; case_id uuid; detail jsonb; result jsonb;
  day date; subject_ids jsonb; payment_method uuid; index_value integer;
  title text; seed_identity constant text := 'sohoj-demo-v1';
begin
  perform pg_advisory_xact_lock(hashtextextended('sohoj-development-demo-v1',0));
  if exists(select 1 from public.audit_events where entity_type='DEVELOPMENT_SEED'
      and entity_id=seed_identity and action='COMPLETE') then
    raise notice 'Demo seed already applied. Existing examples and changes preserved.';
    return;
  end if;

  select p.id into actor from public.profiles p
  join auth.users u on u.id=p.id
  join public.user_role_assignments a on a.profile_id=p.id
  join public.system_roles r on r.id=a.role_id
  where p.status='ACTIVE' and r.code='ADMIN' and r.is_active and a.is_active
    and a.effective_from<=current_date
    and (a.effective_to is null or a.effective_to>=current_date)
  order by p.created_at,p.id limit 1;
  if actor is null then
    raise exception 'Create your Auth account and run bootstrap_admin first. Then run pnpm seed:demo. No demo password or privileged login is created by this seed.';
  end if;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
  select id,timezone(timezone,now())::date into org,day from public.organizations where code='SOHOJ' and is_active;
  select id into campus from public.branches where organization_id=org and code='MAIN' and is_active;
  if org is null or campus is null then raise exception 'Install master migrations 01–22 and keep the main campus active before seeding.';end if;
  if exists(select 1 from public.classes where organization_id=org and code like 'DEMO_%')
    or exists(select 1 from public.programs where organization_id=org and code like 'DEMO_%')
    or exists(select 1 from public.programme_offerings where organization_id=org and code like 'DEMO_%') then
    raise exception 'Reserved DEMO codes already exist without a completed seed marker. Inspect them; no records were overwritten.';
  end if;

  insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
  values(org,'DEMO '||extract(year from day)::integer,date_trunc('year',day)::date,
    (date_trunc('year',day)+interval '1 year - 1 day')::date,true) returning id into academic_year;
  insert into public.classes(organization_id,code,name,sort_order) values(org,'DEMO_CLASS_8','DEMO Class 8',8) returning id into class_eight;
  insert into public.classes(organization_id,code,name,sort_order) values(org,'DEMO_CLASS_9','DEMO Class 9',9);
  insert into public.classes(organization_id,code,name,sort_order) values(org,'DEMO_CLASS_10','DEMO Class 10',10) returning id into class_ten;
  insert into public.academic_groups(organization_id,code,name) values(org,'DEMO_SCIENCE','DEMO Science') returning id into science;
  insert into public.programs(organization_id,code,name,description)
    values(org,'DEMO_SSC','DEMO SSC Preparation','Development-only academic and admission example') returning id into ssc_program;
  insert into public.programs(organization_id,code,name,description)
    values(org,'DEMO_ANNUAL','DEMO Annual Exam Readiness','Development-only academic and admission example') returning id into annual_program;
  insert into public.subjects(organization_id,code,name) values
    (org,'DEMO_BANGLA','DEMO Bangla'),(org,'DEMO_ENGLISH','DEMO English'),
    (org,'DEMO_MATH','DEMO Mathematics'),(org,'DEMO_PHYSICS','DEMO Physics'),
    (org,'DEMO_CHEMISTRY','DEMO Chemistry'),(org,'DEMO_BIOLOGY','DEMO Biology');
  select jsonb_agg(id order by code) into subject_ids from public.subjects where organization_id=org and code like 'DEMO_%';
  insert into public.areas(organization_id,name) values(org,'DEMO Gopalpur'),(org,'DEMO Narundi');
  insert into public.schools(organization_id,name,is_verified,created_by)
    values(org,'DEMO Secondary School',true,actor),(org,'DEMO Girls School',true,actor);

  ssc_offering:=(public.create_programme_offering(jsonb_build_object('branch_id',campus,
    'academic_year_id',academic_year,'class_id',class_ten,'group_id',science,
    'program_id',ssc_program,'code','DEMO_SSC10','reason','DEMO testing programme configuration'))->>'offering_id')::uuid;
  annual_offering:=(public.create_programme_offering(jsonb_build_object('branch_id',campus,
    'academic_year_id',academic_year,'class_id',class_eight,'program_id',annual_program,
    'code','DEMO_ANNUAL8','reason','DEMO testing programme configuration'))->>'offering_id')::uuid;
  foreach case_id in array array[ssc_offering,annual_offering] loop
    perform public.save_fee_plan(jsonb_build_object('offering_id',case_id,'billing_cycle','MONTHLY',
      'due_day',10,'effective_from',day,'reason','DEMO standard fees for workflow testing',
      'components',jsonb_build_array(
        jsonb_build_object('code','TUITION','name','Tuition','amount',3000,'charge_type','TUITION','recurrence','PER_CYCLE'),
        jsonb_build_object('code','ADMISSION','name','Admission fee','amount',500,'charge_type','ADMISSION','recurrence','ONE_TIME'))));
    perform public.save_offering_discount_policy(jsonb_build_object('offering_id',case_id,'percentages',jsonb_build_array(5,10,15,20,25,30)));
    perform public.update_programme_offering_public_controls(jsonb_build_object('offering_id',case_id,
      'is_website_visible',true,'is_accepting_applications',true,'showcase_title','DEMO academic programme',
      'showcase_description','Test programme: personal attention, weekly practice and progress reporting. This is fictional development data.',
      'showcase_eyebrow','DEMO — testing only','showcase_icon','graduation-cap',
      'public_schedule','Morning or evening; staff confirm final placement.',
      'public_requirements','Verify student identity, guardian details and academic placement.',
      'admission_policy','Development example only. Printed consent and office verification required.',
      'subject_ids',subject_ids,'reason','DEMO public showcase and form selections'));
  end loop;
  morning:=(public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
    'offering_id',ssc_offering,'code','DEMO_MORNING','name','DEMO Morning A','capacity',12,
    'reason','DEMO admission placement test'))->>'id')::uuid;
  evening:=(public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
    'offering_id',ssc_offering,'code','DEMO_EVENING','name','DEMO Evening A','capacity',12,
    'reason','DEMO alternate placement test'))->>'id')::uuid;
  annual_batch:=(public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
    'offering_id',annual_offering,'code','DEMO_ANNUAL','name','DEMO Annual Readiness','capacity',12,
    'reason','DEMO class eight placement test'))->>'id')::uuid;

  if exists(select 1 from public.organizations where id=org and setup_identity_confirmed_at is null) then
    perform public.save_academy_identity(jsonb_build_object(
      'name',(select name from public.organizations where id=org),
      'branch_name',(select name from public.branches where id=campus)));
  end if;
  if exists(select 1 from public.organizations where id=org and setup_completed_at is null) then
    perform public.complete_academy_setup();
  end if;

  for index_value in 1..6 loop
    perform public.submit_public_interest(jsonb_build_object('student_name','DEMO Prospect '||index_value,
      'guardian_name','DEMO Guardian P'||index_value,'mobile','0179000000'||index_value,
      'class_id',case when index_value%2=0 then class_eight else class_ten end,
      'offering_id',ssc_offering,'subject_ids',subject_ids,
      'school_name_snapshot','DEMO Secondary School','intent',case when index_value%2=0 then 'interest' else 'admission' end,
      'guardian_address','DEMO Gopalpur, Narundi Road, Jamalpur','consent_to_contact',true));
  end loop;
  select id into payment_method from public.payment_methods where code='CASH' and is_active;
  if payment_method is null then raise exception 'Keep the essential CASH payment method active before demo seeding.';end if;
  for index_value in 1..5 loop
    title:=case index_value when 1 then 'DEMO Draft Applicant' when 2 then 'DEMO Ready Applicant'
      when 3 then 'DEMO Part Paid Student' when 4 then 'DEMO Paid Student' else 'DEMO Unpaid Student' end;
    case_id:=(public.create_staff_admission_intake(jsonb_build_object('request_id',gen_random_uuid(),
      'offering_id',ssc_offering,'batch_id',morning,'student_name',title,
      'guardian_name','DEMO Guardian A'||index_value,'guardian_relationship','Father',
      'mobile','0179000010'||index_value,'guardian_address','DEMO Gopalpur, Narundi Road, Jamalpur',
      'gender',case when index_value%2=0 then 'Female' else 'Male' end,
      'date_of_birth',(day-interval '15 years')::date,'school_name','DEMO Secondary School',
      'reason','DEMO staff-assisted admission example','consent_to_contact',true))->>'admission_id')::uuid;
    if index_value>=2 then
      perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),
        'admission_id',case_id,'reason','DEMO simulated student and guardian verification'));
    end if;
    if index_value>=3 then
      perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
        'admission_id',case_id,'source','ORGANIC','reason','DEMO simulated organic admission source'));
      perform public.record_physical_admission_consent(jsonb_build_object('request_id',gen_random_uuid(),
        'admission_id',case_id,'guardian_signed_on',day,'student_signed',false,
        'physical_copy_reference','DEMO simulated paper file — no real signature',
        'reason','DEMO simulated paper consent for development only'));
      if index_value=3 then
        perform public.admission_command(jsonb_build_object('action','SAVE_DISCOUNT','request_id',gen_random_uuid(),
          'admission_id',case_id,'discount_percent',10,'discount_reason','MERIT',
          'reason','DEMO simulated ten percent tuition reduction'));
      end if;
      perform public.admission_command(jsonb_build_object('action','FINALIZE','request_id',gen_random_uuid(),
        'admission_id',case_id,'reason','DEMO simulated final admission and initial invoice'));
      detail:=public.admission_case_detail(case_id);
      if index_value in(3,4) then
        perform public.collect_student_payment(jsonb_build_object('request_id',gen_random_uuid(),
          'admission_id',case_id,'invoice_id',detail->'invoice'->>'id',
          'amount',case when index_value=3 then 1500 else (detail->'invoice'->>'due')::numeric end,
          'adjustment_amount',0,'payment_method_id',payment_method,
          'reason','DEMO simulated cash collection — no real money'));
      end if;
      if public.admission_payment_satisfied(case_id) then
        perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),
          'admission_id',case_id,'reason','DEMO activation under configured enrollment policy'));
      end if;
    end if;
  end loop;
  perform public.request_staff_access(jsonb_build_object('full_name','DEMO Teacher Request',
    'email','demo-teacher@example.test','mobile','01790000201','requested_role','TEACHER',
    'purpose','DEMO staff onboarding verification test; fictional account'));
  perform public.request_staff_access(jsonb_build_object('full_name','DEMO Operator Request',
    'email','demo-operator@example.test','mobile','01790000202','requested_role','OPERATOR',
    'purpose','DEMO operator onboarding verification test; fictional account'));
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
  values(actor,'DEVELOPMENT_SEED',seed_identity,'COMPLETE','Explicit development-only sample data',
    jsonb_build_object('offerings',2,'batches',3,'prospects',6,'admission_cases',5,'student_identities',3,
      'staff_requests',2,'note','Fictional receipts/consent/collections: no real money or signatures'));
  raise notice 'Demo ready: 2 active public offerings, 3 batches, 6 Prospects, 5 admissions, 3 student identities and 2 staff access requests; enrollment follows the current payment policy.';
end $demo$;
commit;
