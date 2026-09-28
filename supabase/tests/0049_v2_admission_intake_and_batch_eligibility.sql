-- Rollback-only operator intake and incomplete-Prospect batch eligibility.
begin;
do $$
declare
  actor uuid:=gen_random_uuid(); org uuid; branch uuid; cl uuid; program uuid; year_id uuid;
  offering uuid; batch uuid; prospect uuid; admission uuid; student uuid; result jsonb; retry jsonb;
  intake jsonb; today date; profile jsonb; identity jsonb; dob date:=date '2014-04-21';
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values(actor,'admission-intake-'||actor||'@example.invalid','{"full_name":"Admission Intake Test"}');
  perform public.bootstrap_admin('admission-intake-'||actor||'@example.invalid','Admission Intake Test');
  perform set_config('request.jwt.claim.sub',actor::text,true);
  select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
  select id into branch from public.branches where organization_id=org limit 1;
  select id into cl from public.classes where organization_id=org and code='CLASS_10';
  select id into program from public.programs where organization_id=org limit 1;
  insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
  values(org,'INTAKE-'||actor,today,today+365,false) returning id into year_id;
  result:=public.create_programme_offering(jsonb_build_object(
    'branch_id',branch,'academic_year_id',year_id,'class_id',cl,'program_id',program,
    'code','INTAKE-'||left(actor::text,8),'name','Intake Verification Offering','reason','Admission intake verification'));
  offering:=(result->>'offering_id')::uuid;
  perform public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY',
    'due_day',10,'effective_from',today,'reason','Intake verification fees',
    'components','[{"code":"TUITION","name":"Tuition","amount":1500,"charge_type":"TUITION","recurrence":"PER_CYCLE"}]'::jsonb));
  result:=public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
    'reason','Create intake verification batch','offering_id',offering,'code','INT-'||left(actor::text,8),
    'name','Intake Verification Batch','capacity',10));
  batch:=(result->>'id')::uuid;

  intake:=jsonb_build_object(
    'request_id',gen_random_uuid(),'offering_id',offering,'batch_id',batch,
    'student_name','Applicant '||actor::text,'student_name_bn','শিক্ষার্থী',
    'date_of_birth',dob,'gender','Female','school_name','Sample School','school_roll','ROLL-18',
    'guardian_name','Guardian '||actor::text,'guardian_relationship','Mother',
    'mobile','01700000181','alternate_mobile','01700000182','guardian_address','12 Sample Road, Dhaka',
    'referral_note','Neighbour: Test Referrer','consent_to_contact',true,
    'reason','Guardian completed application with staff');
  result:=public.create_staff_admission_intake(intake);
  admission:=(result->>'admission_id')::uuid;
  prospect:=(result->>'prospect_id')::uuid;
  retry:=public.create_staff_admission_intake(intake);
  if retry<>result then raise exception 'Staff intake retry did not return its original admission.'; end if;
  if (select count(*) from public.prospects where id=prospect)<>1
    or (select count(*) from public.admission_cases where id=admission and prospect_id=prospect)<>1 then
    raise exception 'Staff intake did not create one Prospect and one linked admission draft.';
  end if;
  select identity_snapshot into identity from public.admission_cases where id=admission;
  if identity->>'gender'<>'Female' or identity->>'date_of_birth'<>dob::text
    or identity->>'school_roll'<>'ROLL-18' or identity->>'guardian_address'<>'12 Sample Road, Dhaka' then
    raise exception 'Admission snapshot did not retain the applicant details.';
  end if;
  profile:=public.admission_workspace();
  if not exists(select 1 from jsonb_array_elements(profile->'cases') as rows(row_data)
      where row_data->>'id'=admission::text and row_data->>'nameBn'='শিক্ষার্থী'
        and row_data->>'dateOfBirth'=dob::text and row_data->>'guardianAddress'='12 Sample Road, Dhaka') then
    raise exception 'Admission workspace did not return the captured printable particulars.';
  end if;
  if not exists(select 1 from public.audit_events where entity_type='PROSPECT'
      and entity_id=prospect::text and action='CREATE_STAFF_ADMISSION_INTAKE') then
    raise exception 'Staff intake lacks an audit record.';
  end if;

  -- Class may be completed from a matching recorded offering for an older CRM Prospect.
  insert into public.prospects(organization_id,student_name,guardian_name,mobile,interested_offering_id)
  values(org,'Unclassified '||actor::text,'Older Guardian','01700000183',offering) returning id into prospect;
  profile:=public.admission_workspace();
  if not exists(select 1 from jsonb_array_elements(profile->'prospects') as rows(row_data)
      where row_data->>'id'=prospect::text and row_data->>'interestedOfferingId'=offering::text) then
    raise exception 'Admission workspace did not return the Prospect offering used to select a batch.';
  end if;
  result:=public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),
    'reason','Assign verified programme class','prospect_id',prospect,'offering_id',offering,'batch_id',batch));
  if (select current_class_id from public.prospects where id=prospect)<>cl then
    raise exception 'Missing Prospect class was not assigned from the verified offering.';
  end if;
  if not exists(select 1 from public.audit_events where entity_type='PROSPECT'
      and entity_id=prospect::text and action='ASSIGN_CLASS_FROM_OFFERING') then
    raise exception 'Prospect class completion was not audited.';
  end if;
  insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id)
  values(org,'Wrong Offering '||actor::text,'Guardian','01700000184',cl) returning id into prospect;
  begin
    perform public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),
      'reason','Reject mismatched batch offering','prospect_id',prospect,
      'offering_id',gen_random_uuid(),'batch_id',batch));
    raise exception 'Mismatched offering was accepted.';
  exception when others then
    if position('match this Prospect' in sqlerrm)=0 then raise; end if;
  end;

  -- Acceptance carries captured demographic details into the canonical student row.
  perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),
    'admission_id',admission,'source','ORGANIC','reason','Guardian confirmed no referrer'));
  update public.admission_cases set consent_required=false where id=admission;
  perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),
    'reason','Verify applicant details and charges','admission_id',admission));
  perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
    'reason','Accept verified applicant','admission_id',admission));
  select student_id into student from public.admission_cases where id=admission;
  if not exists(select 1 from public.students where id=student and name_bn='শিক্ষার্থী'
      and gender='Female' and date_of_birth=dob and school_roll='ROLL-18') then
    raise exception 'Accepted Student row did not receive verified application details.';
  end if;
  if not exists(select 1 from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id
      where sg.student_id=student and g.address='12 Sample Road, Dhaka' and g.alternate_mobile='01700000182') then
    raise exception 'Accepted Guardian record did not receive the intake contact details.';
  end if;
end;
$$;
rollback;
