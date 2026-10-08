-- Short courses use their real duration, without a fabricated school class or year.
alter table public.programme_offerings alter column academic_year_id drop not null,alter column class_id drop not null;
alter table public.batches alter column academic_year_id drop not null,alter column class_id drop not null;
alter table public.enrollments alter column academic_year_id drop not null,alter column class_id drop not null;
alter table public.programme_offerings add constraint offering_learning_context check ((operation_kind='TRAINING' and teaching_starts_on is not null and teaching_ends_on is not null and teaching_ends_on>=teaching_starts_on) or(operation_kind in('SCHOOL','COACHING') and academic_year_id is not null and class_id is not null));
-- Existing teaching plans are preserved; new writes must satisfy the context.
create unique index batch_short_course_code on public.batches(organization_id,code) where academic_year_id is null;
create unique index offering_short_course_code on public.programme_offerings(organization_id,code) where academic_year_id is null;
create unique index enrollment_active_batch_identity on public.enrollments(student_id,batch_id) where status='ACTIVE' and batch_id is not null;
create function public.valid_learning_context(p_org uuid,p_input jsonb) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.branches b join public.programs p on p.id=nullif(p_input->>'program_id','')::uuid where b.id=nullif(p_input->>'branch_id','')::uuid and b.organization_id=p_org and b.is_active and p.organization_id=p_org and p.is_active)
 and (nullif(p_input->>'group_id','') is null or exists(select 1 from public.academic_groups g where g.id=(p_input->>'group_id')::uuid and g.organization_id=p_org and g.is_active))
 and coalesce(p_input->>'operation_kind','COACHING') in('SCHOOL','COACHING','TRAINING')
 and (nullif(p_input->>'academic_year_id','') is null or exists(select 1 from public.academic_years y where y.id=(p_input->>'academic_year_id')::uuid and y.organization_id=p_org))
 and (nullif(p_input->>'class_id','') is null or exists(select 1 from public.classes c where c.id=(p_input->>'class_id')::uuid and c.organization_id=p_org and c.is_active))
 and case when p_input->>'operation_kind'='TRAINING' then nullif(p_input->>'teaching_starts_on','')::date is not null and nullif(p_input->>'teaching_ends_on','')::date is not null and nullif(p_input->>'teaching_ends_on','')::date>=nullif(p_input->>'teaching_starts_on','')::date
 else nullif(p_input->>'academic_year_id','') is not null and nullif(p_input->>'class_id','') is not null end
$$;
revoke all on function public.valid_learning_context(uuid,jsonb) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.create_programme_offering(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_row public.programme_offerings;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
 p_input:=p_input||jsonb_build_object('name',coalesce(nullif(btrim(p_input->>'name'),''),(select name from public.programs where id=(p_input->>'program_id')::uuid)));
  if v_actor is null or not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to manage Programme Offerings.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active;
  if v_org is null or not public.valid_learning_context(v_org,p_input) then
    raise exception 'Offering context must use active master data from the same organization.';
  end if;
  insert into public.programme_offerings(
    organization_id,branch_id,academic_year_id,class_id,program_id,
    group_id,code,name,created_by,operation_kind,teaching_starts_on,teaching_ends_on
  ) values (
    v_org,(p_input->>'branch_id')::uuid,(p_input->>'academic_year_id')::uuid,
    (p_input->>'class_id')::uuid,(p_input->>'program_id')::uuid,
    nullif(p_input->>'group_id','')::uuid,
    upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_actor,coalesce(p_input->>'operation_kind','COACHING'),nullif(p_input->>'teaching_starts_on','')::date,nullif(p_input->>'teaching_ends_on','')::date
  ) returning * into v_row;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    branch_id,entity_type,entity_id,action,reason,after_data)
  values (v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
    v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'CREATE',v_reason,to_jsonb(v_row));
  return jsonb_build_object('offering_id',v_row.id,'correlation_id',v_correlation);
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_programme_offering(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid:=auth.uid();
  v_request uuid:=nullif(p_input->>'request_id','')::uuid;
  v_reason text:=btrim(coalesce(p_input->>'reason',''));
  v_org uuid;
  v_row public.programme_offerings;
  v_before jsonb;
  v_result jsonb;
  v_branch uuid:=(p_input->>'branch_id')::uuid;
  v_year uuid:=(p_input->>'academic_year_id')::uuid;
  v_class uuid:=(p_input->>'class_id')::uuid;
  v_program uuid:=(p_input->>'program_id')::uuid;
  v_group uuid:=nullif(p_input->>'group_id','')::uuid;
  v_code text:=upper(btrim(coalesce(p_input->>'code','')));
  v_name text:=btrim(coalesce(p_input->>'name',''));
  v_existing public.admission_command_keys;
begin
 p_input:=p_input||jsonb_build_object('name',coalesce(nullif(btrim(p_input->>'name'),''),(select name from public.programs where id=(p_input->>'program_id')::uuid)));
  if v_actor is null or not public.has_permission('academics.manage') then raise exception 'You are not authorized to manage Programme Offerings.'; end if;
  if v_request is null then raise exception 'A request identity is required.'; end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  if length(v_code)<2 or length(v_code)>40 or v_code !~ '^[A-Z0-9_-]+$' then raise exception 'Use a valid offering code with letters, numbers, underscores or hyphens.'; end if;
  if length(v_name)<2 or length(v_name)>160 then raise exception 'Enter a recognizable offering name.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
  perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
  select * into v_existing from public.admission_command_keys where request_id=v_request;
  if found then
    if v_existing.actor_id<>v_actor or v_existing.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
    return v_existing.result;
  end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active limit 1;
  select * into v_row from public.programme_offerings where id=(p_input->>'offering_id')::uuid and organization_id=v_org for update;
  if v_row.id is null then raise exception 'Programme Offering not found.'; end if;
  
  if exists(select 1 from public.batches ba join public.class_sessions cs on cs.batch_id=ba.id where ba.offering_id=v_row.id) and (coalesce(p_input->>'operation_kind',v_row.operation_kind) is distinct from v_row.operation_kind or coalesce(nullif(p_input->>'teaching_starts_on','')::date,v_row.teaching_starts_on) is distinct from v_row.teaching_starts_on or coalesce(nullif(p_input->>'teaching_ends_on','')::date,v_row.teaching_ends_on) is distinct from v_row.teaching_ends_on) then raise exception 'Use Programme teaching plan to change dates after classes are scheduled.';end if;
  v_before:=to_jsonb(v_row);
  if v_row.status in('ACTIVE','RETIRED') and (
    v_branch is distinct from v_row.branch_id or v_year is distinct from v_row.academic_year_id
    or v_class is distinct from v_row.class_id or v_program is distinct from v_row.program_id
    or v_group is distinct from v_row.group_id
  ) then raise exception 'Academic context cannot change after activation. Create a new offering for a new year, class, branch or programme.'; end if;
  if v_row.status='DRAFT' and exists(select 1 from public.batches where offering_id=v_row.id) and (
    v_branch is distinct from v_row.branch_id or v_year is distinct from v_row.academic_year_id
    or v_class is distinct from v_row.class_id or v_program is distinct from v_row.program_id
    or v_group is distinct from v_row.group_id
  ) then raise exception 'Academic context cannot change after batches reference this offering.'; end if;
  if not public.valid_learning_context(v_org,p_input) then raise exception 'Offering context must use active master data from the same organization.'; end if;
  update public.programme_offerings set
    branch_id=case when status='DRAFT' then v_branch else branch_id end,
    academic_year_id=case when status='DRAFT' then v_year else academic_year_id end,
    class_id=case when status='DRAFT' then v_class else class_id end,
    program_id=case when status='DRAFT' then v_program else program_id end,
    group_id=case when status='DRAFT' then v_group else group_id end,
    operation_kind=coalesce(p_input->>'operation_kind',operation_kind),
    teaching_starts_on=coalesce(nullif(p_input->>'teaching_starts_on','')::date,teaching_starts_on),
    teaching_ends_on=coalesce(nullif(p_input->>'teaching_ends_on','')::date,teaching_ends_on),
    code=v_code,name=v_name
  where id=v_row.id returning * into v_row;
  v_result:=jsonb_build_object('offering_id',v_row.id,'correlation_id',v_request);
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,branch_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
  values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'UPDATE',v_reason,v_before,to_jsonb(v_row),jsonb_build_object('request_id',v_request,'status',v_row.status));
  insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
  return v_result;
end
$function$;

CREATE OR REPLACE FUNCTION public.execute_admission_stage(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 v_actor uuid:=auth.uid(); v_action text:=p_input->>'action';
 v_request uuid:=(p_input->>'request_id')::uuid; v_key public.admission_command_keys;
 v_reason text:=btrim(coalesce(p_input->>'reason','')); v_case public.admission_cases;
 v_before jsonb; v_result jsonb; v_batch public.batches; v_offering public.programme_offerings;
 v_prospect public.prospects; v_fee public.fee_plan_versions;
 v_policy public.business_rule_versions; v_capacity public.business_rule_versions;
 v_guardian uuid; v_student uuid; v_enrollment uuid; v_invoice uuid;
 v_today date; v_total numeric; v_occupied integer;
begin
 if v_actor is null then raise exception 'Sign in to continue.'; end if;
 if v_action='CREATE_BATCH' then
   if not public.has_permission('academics.manage') then raise exception 'Batch management permission required.'; end if;
 elsif not public.has_permission('admissions.create') then raise exception 'Admission permission required.';
 end if;
 if v_request is null or length(v_reason)<5 then raise exception 'Request identity and a reason of at least five characters are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 select * into v_key from public.admission_command_keys where request_id=v_request;
 if found then
   if v_key.actor_id<>v_actor or v_key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
   return v_key.result;
 end if;
 if v_action='CREATE_BATCH' then
   select * into v_offering from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status='ACTIVE' for update;
   if not found then raise exception 'Choose an active offering with a published Fee Plan.'; end if;
   select * into v_capacity from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;
   if coalesce((p_input->>'capacity')::integer,0)<1
      or (p_input->>'capacity')::integer>(v_capacity.payload->>'max_students')::integer then
     raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',v_capacity.payload->>'max_students';
   end if;
   if length(btrim(coalesce(p_input->>'name','')))<2 or length(btrim(coalesce(p_input->>'code','')))<2 then raise exception 'Batch name and code are required.'; end if;
   insert into public.batches(organization_id,branch_id,academic_year_id,class_id,program_id,code,name,capacity,created_by,offering_id,capacity_policy_version_id)
   values(v_offering.organization_id,v_offering.branch_id,v_offering.academic_year_id,v_offering.class_id,v_offering.program_id,
     upper(btrim(p_input->>'code')),btrim(p_input->>'name'),(p_input->>'capacity')::integer,v_actor,v_offering.id,v_capacity.id) returning * into v_batch;
   v_result:=jsonb_build_object('id',v_batch.id,'status','CREATED');
 elsif v_action='CREATE' then
   select * into v_prospect from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
   if v_prospect.id is null or v_prospect.status in ('CONVERTED','LOST') then raise exception 'Choose an unconverted, open Prospect.'; end if;
   if exists(select 1 from public.admission_cases where prospect_id=v_prospect.id and status<>'CANCELLED') then raise exception 'This Prospect already has an Admission Case. Open the existing case.'; end if;
   select * into v_batch from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
   select * into v_offering from public.programme_offerings where id=v_batch.offering_id and status='ACTIVE';
   if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id
     or v_batch.offering_id is distinct from nullif(p_input->>'offering_id','')::uuid
     or (v_offering.class_id is not null and v_prospect.current_class_id is not null and v_prospect.current_class_id is distinct from v_offering.class_id)
     or (v_prospect.current_class_id is null and v_prospect.interested_offering_id is not null
         and v_prospect.interested_offering_id is distinct from v_offering.id) then
     raise exception 'Choose an active offering and a batch that match this Prospect.';
   end if;
   if v_prospect.current_class_id is null then
     update public.prospects set current_class_id=v_offering.class_id where id=v_prospect.id;
     v_prospect.current_class_id:=v_offering.class_id;
     insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
       entity_type,entity_id,action,reason,before_data,after_data,metadata)
     values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
       'PROSPECT',v_prospect.id::text,'ASSIGN_CLASS_FROM_OFFERING',v_reason,
       jsonb_build_object('current_class_id',null,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('current_class_id',v_offering.class_id,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('offering_id',v_offering.id,'batch_id',v_batch.id));
   end if;
   if (select count(*) from public.enrollments where batch_id=v_batch.id and status='ACTIVE')>=v_batch.capacity then raise exception 'Selected batch is full.'; end if;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_offering.organization_id;
   select * into v_fee from public.fee_plan_versions where offering_id=v_offering.id and status='ACTIVE' and effective_from<=v_today;
   if v_fee.id is null then raise exception 'No effective published Fee Plan is available.'; end if;
   insert into public.admission_cases(prospect_id,batch_id,fee_plan_version_id,identity_snapshot,created_by)
   values(v_prospect.id,v_batch.id,v_fee.id,jsonb_build_object('student_name',v_prospect.student_name,'guardian_name',v_prospect.guardian_name,
     'mobile',v_prospect.mobile,'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian'),
     'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot,
     'student_name_bn',v_prospect.student_name_bn,'gender',v_prospect.gender,
     'date_of_birth',v_prospect.date_of_birth,'school_roll',v_prospect.school_roll,
     'alternate_mobile',v_prospect.alternate_mobile,
     'guardian_address',coalesce(v_prospect.guardian_address,
       v_prospect.application_snapshot->>'guardian_address'),
     'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian')),v_actor) returning * into v_case;
   v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status);
 else
   select * into v_case from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
   if not found then raise exception 'Admission Case not found.'; end if;
   v_before:=to_jsonb(v_case);
   if v_case.student_id is not null then
     perform 1 from public.students where id=v_case.student_id for update;
     if exists(select 1 from public.students where id=v_case.student_id and (merged_into_id is not null or status='ARCHIVED')) then raise exception 'Use the canonical, non-archived Student identity.';end if;
   end if;
   select * into v_batch from public.batches where id=v_case.batch_id and is_active for update;
   if v_batch.id is null then raise exception 'Batch is no longer active.'; end if;
   select * into v_fee from public.fee_plan_versions where id=v_case.fee_plan_version_id for share;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_batch.organization_id;
   if v_action='EDIT_DRAFT' and v_case.status in ('DRAFT','READY') then
     if v_case.existing_student then raise exception 'Existing Student identity is read-only in enrollment drafts.';end if;
     if length(btrim(coalesce(p_input->>'student_name','')))<2 or length(btrim(coalesce(p_input->>'guardian_name','')))<2
       or coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$' then raise exception 'Valid student, guardian and Bangladesh mobile details are required.'; end if;
     update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_build_object('student_name',btrim(p_input->>'student_name'),'guardian_name',btrim(p_input->>'guardian_name'),'mobile',p_input->>'mobile'),status='DRAFT' where id=v_case.id;
   elsif v_action='READY' and v_case.status='DRAFT' then
     if length(btrim(coalesce(v_case.identity_snapshot->>'student_name','')))<2 or length(btrim(coalesce(v_case.identity_snapshot->>'guardian_name','')))<2
       or coalesce(v_case.identity_snapshot->>'mobile','') !~ '^01[3-9][0-9]{8}$' then raise exception 'Valid student, guardian and Bangladesh mobile details are required. Correct the Prospect before starting admission.'; end if;
     if v_fee.status<>'ACTIVE' then raise exception 'The selected Fee Plan has changed. Refresh fees before review.'; end if;
     update public.admission_cases set status='READY' where id=v_case.id;
   elsif v_action='REFRESH_FEES' and v_case.status in ('DRAFT','READY') then
     select * into v_fee from public.fee_plan_versions where offering_id=v_batch.offering_id and status='ACTIVE' and effective_from<=v_today;
     if v_fee.id is null then raise exception 'No active Fee Plan.'; end if;
     update public.admission_cases set fee_plan_version_id=v_fee.id,status='DRAFT' where id=v_case.id;
   elsif v_action='ACCEPT' and v_case.status='READY' then
     select * into v_prospect from public.prospects where id=v_case.prospect_id for update;
     if not v_case.existing_student and v_prospect.status in ('CONVERTED','LOST') then raise exception 'Prospect is no longer eligible for admission.'; end if;
     if v_fee.status<>'ACTIVE' then raise exception 'Fee Plan changed. Refresh and review before acceptance.'; end if;

      if v_case.consent_required
        and not exists (select 1 from public.admission_physical_consent_receipts r where r.admission_id = v_case.id and r.identity_revision=v_case.identity_revision)
      then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;
     select * into v_policy from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE';
     if v_policy.id is null or not public.validate_business_rule_payload('admissions','activation_policy',v_policy.payload) then raise exception 'A valid activation policy is required.'; end if;
     if v_case.existing_student then
       if exists(select 1 from public.enrollments where student_id=v_case.student_id and academic_year_id=v_batch.academic_year_id and status='ACTIVE') then raise exception 'Student already has an active enrollment in this academic year.';end if;
       update public.admission_cases set activation_policy_version_id=v_policy.id,status='ACCEPTED' where id=v_case.id;
     else
     perform pg_advisory_xact_lock(hashtextextended(v_case.identity_snapshot->>'mobile',1));
     if exists(select 1 from public.students s join public.student_guardians sg on sg.student_id=s.id join public.guardians g on g.id=sg.guardian_id
       where s.organization_id=v_batch.organization_id and lower(s.full_name)=lower(v_case.identity_snapshot->>'student_name') and g.mobile=v_case.identity_snapshot->>'mobile') then
       raise exception 'Possible existing student with this name and guardian mobile. Review the existing identity before continuing.';
     end if;
     select id into v_guardian from public.guardians where organization_id=v_batch.organization_id and mobile=v_case.identity_snapshot->>'mobile'
       and lower(full_name)=lower(v_case.identity_snapshot->>'guardian_name') order by created_at limit 1;
     if v_guardian is null then
       insert into public.guardians(organization_id,full_name,mobile,created_by) values(v_batch.organization_id,v_case.identity_snapshot->>'guardian_name',v_case.identity_snapshot->>'mobile',v_actor) returning id into v_guardian;
     end if;
     insert into public.students(organization_id,branch_id,full_name,school_id,school_name_snapshot,status,created_from_prospect_id,created_by)
     values(v_batch.organization_id,v_batch.branch_id,v_case.identity_snapshot->>'student_name',(v_case.identity_snapshot->>'school_id')::uuid,
       v_case.identity_snapshot->>'school_name','INACTIVE',v_case.prospect_id,v_actor) returning id into v_student;
     insert into public.student_guardians(student_id,guardian_id,relationship_snapshot,is_primary) values(v_student,v_guardian,v_case.identity_snapshot->>'guardian_relationship',true);
     update public.admission_cases set student_id=v_student,activation_policy_version_id=v_policy.id,status='ACCEPTED' where id=v_case.id;
     update public.prospects set status='CONVERTED',converted_student_id=v_student,converted_at=now() where id=v_case.prospect_id;
     end if;
   elsif v_action='BILL' and v_case.status='ACCEPTED' then
     select coalesce(sum(amount),0) into v_total from public.fee_plan_components where fee_plan_version_id=v_fee.id;
     v_total:=v_total+coalesce((select sum((value->>'amount')::numeric) from jsonb_array_elements(v_case.additional_charges) where (value->>'is_active')::boolean),0);
     if not exists(select 1 from public.fee_plan_components where fee_plan_version_id=v_fee.id) then raise exception 'Fee Plan has no charge components.'; end if;
     insert into public.admission_invoices(admission_id,student_id,fee_plan_version_id,currency_code,total,issued_on,due_on,posted_by,billing_period)
     values(v_case.id,v_case.student_id,v_fee.id,v_fee.currency_code,v_total,v_today,
       case when v_fee.due_day is not null then greatest(v_today,date_trunc('month',v_today)::date+v_fee.due_day-1) else v_today end,v_actor,date_trunc('month',v_today)::date) returning id into v_invoice;
     insert into public.admission_invoice_lines(invoice_id,fee_component_id,name,charge_type,amount)
     select v_invoice,id,name,charge_type,amount from public.fee_plan_components where fee_plan_version_id=v_fee.id
     union all select v_invoice,null,value->>'name',value->>'charge_type',(value->>'amount')::numeric from jsonb_array_elements(v_case.additional_charges) where (value->>'is_active')::boolean;
     perform public.apply_invoice_discounts(v_invoice);
     update public.admission_cases set status='BILLING_POSTED' where id=v_case.id;
   elsif v_action='ACTIVATE' and v_case.status in ('BILLING_POSTED','PENDING_PAYMENT') then
     select * into v_policy from public.business_rule_versions where id=v_case.activation_policy_version_id;
     select total into v_total from public.admission_invoices where admission_id=v_case.id and invoice_kind='INITIAL';
     if v_total is null or v_case.student_id is null or v_policy.id is null then raise exception 'Accepted identity, initial billing and pinned activation policy are required.'; end if;
     -- Payment-backed activation is added by the following payment migration.
     if not coalesce(public.admission_payment_satisfied(v_case.id),false) then
       update public.admission_cases set status='PENDING_PAYMENT' where id=v_case.id;
     else
       select * into v_capacity from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
       if v_capacity.id is null then raise exception 'Capacity policy missing.'; end if;
       select count(*) into v_occupied from public.enrollments where batch_id=v_batch.id and status='ACTIVE';
       if v_occupied>=least(v_batch.capacity,(v_capacity.payload->>'max_students')::integer) then raise exception 'Selected batch is full under the current capacity policy.'; end if;
       if exists(select 1 from public.enrollments where student_id=v_case.student_id and academic_year_id=v_batch.academic_year_id and status='ACTIVE') then raise exception 'Student already has an active enrollment in this academic year.';end if;
       insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,status,created_by)
       values(v_case.student_id,v_batch.organization_id,v_batch.branch_id,v_batch.academic_year_id,v_batch.class_id,v_batch.program_id,v_batch.id,'ACTIVE',v_actor) returning id into v_enrollment;
       update public.admission_cases set status='ACTIVE_ENROLLMENT',enrollment_id=v_enrollment,capacity_policy_version_id=v_capacity.id where id=v_case.id;
       update public.students set status='ACTIVE' where id=v_case.student_id;
     end if;
   else raise exception 'This action is not allowed from the current admission state.';
   end if;
   select * into v_case from public.admission_cases where id=v_case.id;
   v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status);
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
   case when v_action='CREATE_BATCH' then 'BATCH' else 'ADMISSION' end,v_result->>'id',v_action,v_reason,v_before,
   case when v_action='CREATE_BATCH' then to_jsonb(v_batch) else to_jsonb(v_case) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
 return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_prospect_admission(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare chosen uuid; changed uuid; p public.prospects; o public.programme_offerings; k public.admission_command_keys;
 req uuid:=nullif(p_input->>'request_id','')::uuid; result jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or p_input->>'action' is distinct from 'CREATE' or length(btrim(coalesce(p_input->>'reason','')))<5 then
  raise exception 'A valid request and verification note are required.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if;
  return k.result;
 end if;
 select * into p from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
 select * into o from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status='ACTIVE';
 if p.id is null or p.status in('CONVERTED','LOST') or o.id is null or p.organization_id<>o.organization_id
 or not exists(select 1 from public.batches where id=(p_input->>'batch_id')::uuid and offering_id=o.id and is_active) then
  raise exception 'Choose an open enquiry, active offering and its batch.';
 end if;
 if (p.current_class_id is not null and p.current_class_id<>o.class_id)
   or (p.interested_offering_id is not null and p.interested_offering_id<>o.id) then
  if coalesce((p_input->>'confirm_placement_correction')::boolean,false) is not true then
   raise exception 'Confirm the corrected placement.';
  end if;
 end if;
 update public.prospects set current_class_id=coalesce(o.class_id,p.current_class_id),interested_offering_id=o.id,
  application_verified_at=now(),application_verified_by=auth.uid() where id=p.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'PROSPECT',p.id::text,'VERIFY_ADMISSION_PLACEMENT',p_input->>'reason',to_jsonb(p),
   jsonb_build_object('class_id',o.class_id,'offering_id',o.id));
 if not exists(select 1 from public.organizations where id=o.organization_id and setup_completed_at is not null and is_active) then raise exception 'Complete academy setup before starting admissions.'; end if;
 result:=public.admission_command(p_input);
 update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(jsonb_build_object(
 'guardian_address',coalesce(p.guardian_address,p.application_snapshot->>'guardian_address'),
 'alternate_mobile',p.alternate_mobile,'student_name_bn',p.student_name_bn,
 'date_of_birth',coalesce(p.date_of_birth::text,p.application_snapshot->>'date_of_birth'),
 'gender',coalesce(p.gender,p.application_snapshot->>'gender'),
 'school_roll',coalesce(p.school_roll,p.application_snapshot->>'school_roll'),
 'student_mobile',p.application_snapshot->>'student_mobile','student_email',p.application_snapshot->>'student_email','present_landmark',p.application_snapshot->>'present_landmark','permanent_address',p.application_snapshot->>'permanent_address','permanent_same_as_present',p.application_snapshot->>'permanent_same_as_present','birth_registration',p.application_snapshot->>'birth_registration','previous_result',p.application_snapshot->>'previous_result',
 'father_name',p.application_snapshot->>'father_name','mother_name',p.application_snapshot->>'mother_name',
 'emergency_contact',p.application_snapshot->>'emergency_contact','emergency_mobile',p.application_snapshot->>'emergency_mobile',
 'learning_needs',p.application_snapshot->>'learning_needs'))
 where id=(result->>'id')::uuid;

 select id into chosen from public.staff where profile_id=auth.uid() and status in('ACTIVE','ON_LEAVE');
 if chosen is not null then
 update public.prospects set assigned_to_staff_id=chosen where id=(p_input->>'prospect_id')::uuid and assigned_to_staff_id is null returning id into changed;
 if changed is not null then
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values((p_input->>'request_id')::uuid,auth.uid(),'PROSPECT',changed::text,'ASSIGN_FOLLOWUP_STAFF','Staff handled verified admission conversion',jsonb_build_object('staff_id',chosen));
 end if; end if;

 return result;
end
$function$;

CREATE OR REPLACE FUNCTION public.enforce_enrollment_batch_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_batch public.batches;
  v_occupied integer;
begin
  if new.status <> 'ACTIVE' or new.batch_id is null then
    return new;
  end if;

  select * into v_batch
  from public.batches
  where id = new.batch_id
    and is_active
  for update;

  if v_batch.id is null then
    raise exception 'Selected batch is not available.';
  end if;

  if new.organization_id <> v_batch.organization_id
     or new.academic_year_id is distinct from v_batch.academic_year_id
     or new.class_id is distinct from v_batch.class_id
     or new.program_id is distinct from v_batch.program_id then
    raise exception 'Enrollment does not match the selected batch academic context.';
  end if;

  select count(*)::integer into v_occupied
  from public.enrollments e
  where e.batch_id = new.batch_id
    and e.status = 'ACTIVE'
    and e.id <> new.id;

  if v_occupied >= v_batch.capacity then
    raise exception 'Selected batch is full (%/%).', v_occupied, v_batch.capacity;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.academic_workspace(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare manager boolean:=public.has_permission('academics.sessions.manage');curriculum_manager boolean:=public.has_permission('academics.curriculum.manage');begin
 if auth.uid() is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'Choose a date range of at most 367 days.';end if;
 return jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where is_active),'[]'::jsonb),
 'batches',case when manager or curriculum_manager then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||coalesce(y.name,'Not applicable'),'branchId',b.branch_id,'capacity',b.capacity)) from public.batches b left join public.academic_years y on y.id=b.academic_year_id where b.is_active and b.offering_id is not null),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.subjects where is_active),'[]'::jsonb),
 'teachers',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id),'[]'::jsonb))) from public.staff s where s.status='ACTIVE' and exists(select 1 from public.staff_subject_assignments where staff_id=s.id)),'[]'::jsonb) else '[]'::jsonb end,
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'branchId',branch_id,'capacity',capacity)) from public.academic_rooms),'[]'::jsonb),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'batchId',v.batch_id,'subjectId',v.subject_id,'batch',b.name,'subject',s.name,'version',v.version,'title',v.title,'units',v.units) order by v.published_at desc) from public.curriculum_versions v join public.batches b on b.id=v.batch_id join public.subjects s on s.id=v.subject_id where manager or curriculum_manager or exists(select 1 from public.class_sessions x where x.curriculum_version_id=v.id and public.can_access_class_session(x.id))),'[]'::jsonb),
 'routines',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'batchId',r.batch_id,'subjectId',r.subject_id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'weekday',r.weekday,'startTime',r.start_time,'endTime',r.end_time,'startsOn',r.starts_on,'endsOn',r.ends_on,'retired',r.retired_at is not null)) from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where manager or t.profile_id=auth.uid()),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'date',x.session_date,'startTime',to_char(x.starts_at at time zone o.timezone,'HH24:MI'),'endTime',to_char(x.ends_at at time zone o.timezone,'HH24:MI'),'timezone',o.timezone,'status',x.status,'scope',x.planned_scope,'latestStatus',(select status from public.attendance_submissions where session_id=x.id order by revision desc limit 1),'approvedRevision',(select max(revision) from public.attendance_submissions where session_id=x.id and status='APPROVED')) order by x.starts_at) from public.class_sessions x join public.batches b on b.id=x.batch_id join public.organizations o on o.id=b.organization_id join public.subjects s on s.id=x.subject_id join public.staff t on t.id=x.teacher_id join public.academic_rooms rm on rm.id=x.room_id where x.session_date between p_from and p_to and public.can_access_class_session(x.id)),'[]'::jsonb)
 );
end; $function$;

CREATE OR REPLACE FUNCTION public.assessment_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare actor uuid:=auth.uid(); act text:=p_input->>'action'; rid uuid:=(p_input->>'request_id')::uuid;
  a public.academic_assessments; r public.assessment_result_submissions; key public.admission_command_keys;
  v_entries jsonb:=coalesce(p_input->'entries','[]'::jsonb); expected integer; result jsonb;
  v_batch uuid; v_subject uuid; v_date date; v_max numeric;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 if rid is null then raise exception 'Request identity required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
 select * into key from public.admission_command_keys where request_id=rid;
 if found then
   if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
   return key.result;
 end if;
 if act='CREATE' then
   if not public.has_permission('academics.assessments.record') then raise exception 'Assessment recording permission required.'; end if;
   v_batch:=(p_input->>'batch_id')::uuid; v_subject:=(p_input->>'subject_id')::uuid;
   if not public.can_access_assessment(v_batch,v_subject) then raise exception 'Assessment is outside your teaching scope.'; end if;
   if not exists(select 1 from public.class_sessions where batch_id=v_batch and subject_id=v_subject) then raise exception 'Schedule a class for this batch and subject first.'; end if;
   v_date:=(p_input->>'assessment_date')::date; v_max:=(p_input->>'max_marks')::numeric;
   if v_date is null or v_max is null or v_max<=0 or v_max>1000
     or length(btrim(coalesce(p_input->>'title',''))) not between 3 and 180 then raise exception 'Enter assessment title, date and valid maximum marks.'; end if;
   if not exists(select 1 from public.batches b join public.programme_offerings po on po.id=b.offering_id left join public.academic_years y on y.id=b.academic_year_id where b.id=v_batch and v_date between coalesce(po.teaching_starts_on,y.starts_on) and coalesce(po.teaching_ends_on,y.ends_on)) then raise exception 'Assessment date must be in the batch academic year.'; end if;
   insert into public.academic_assessments(batch_id,subject_id,title,assessment_date,max_marks,author_id)
   values(v_batch,v_subject,btrim(p_input->>'title'),v_date,v_max,actor) returning * into a;
 else
   select * into a from public.academic_assessments where id=(p_input->>'assessment_id')::uuid for update;
   if a.id is null or not public.can_access_assessment(a.batch_id,a.subject_id) then raise exception 'Assessment not found in your scope.'; end if;
   if act='PUBLISH' then
     if a.status<>'DRAFT' or not public.has_permission('academics.assessments.record') then raise exception 'Only a draft can be published.'; end if;
     if a.author_id<>actor and not public.has_permission('academics.sessions.manage') then raise exception 'Only the author may publish this assessment.'; end if;
     update public.academic_assessments set status='PUBLISHED',published_at=now() where id=a.id returning * into a;
   elsif act='SAVE_RESULTS' then
     if a.status<>'PUBLISHED' or not public.has_permission('academics.assessments.record') then raise exception 'Published assessment and recording permission required.'; end if;
     if jsonb_typeof(v_entries)<>'array' or jsonb_array_length(v_entries)>500 then raise exception 'Check result entries.'; end if;
     select count(*) into expected from public.enrollments e where e.batch_id=a.batch_id and e.admission_date<=a.assessment_date
       and (e.ended_on is null or e.ended_on>a.assessment_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED');
     if expected=0 or expected<>jsonb_array_length(v_entries) then raise exception 'Record exactly one result for every eligible student.'; end if;
     if exists(select 1 from jsonb_array_elements(v_entries) e where
       not (e ? 'enrollment_id' and e ? 'score') or (e->>'score') !~ '^([0-9]+)(\.[0-9]{1,2})?$'
       or (e->>'score')::numeric>a.max_marks or length(coalesce(e->>'feedback',''))>500
       or not exists(select 1 from public.enrollments x where x.id=(e->>'enrollment_id')::uuid and x.batch_id=a.batch_id
         and x.admission_date<=a.assessment_date and (x.ended_on is null or x.ended_on>a.assessment_date)
         and x.status in ('ACTIVE','WITHDRAWN','COMPLETED')))
       or (select count(distinct e->>'enrollment_id') from jsonb_array_elements(v_entries) e)<>expected
       then raise exception 'Invalid or duplicate result entries.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null then
       if exists(select 1 from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED') then raise exception 'Results are awaiting independent review.'; end if;
       insert into public.assessment_result_submissions(assessment_id,revision,entries,author_id)
       values(a.id,(select coalesce(max(revision),0)+1 from public.assessment_result_submissions where assessment_id=a.id),v_entries,actor) returning * into r;
     else
       if r.author_id<>actor then raise exception 'Only the draft author can change these results.'; end if;
       update public.assessment_result_submissions set entries=v_entries where id=r.id returning * into r;
     end if;
   elsif act='SUBMIT_RESULTS' then
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null or r.author_id<>actor then raise exception 'Save your result draft before submitting.'; end if;
     update public.assessment_result_submissions set status='SUBMITTED',submitted_at=now() where id=r.id returning * into r;
   elsif act in ('APPROVE_RESULTS','REJECT_RESULTS') then
     if not public.has_permission('academics.assessments.approve') then raise exception 'Assessment review permission required.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED' for update;
     if r.id is null then raise exception 'No submitted result revision is awaiting review.'; end if;
     if r.author_id=actor then raise exception 'Result author cannot approve or reject their own submission.'; end if;
     if length(btrim(coalesce(p_input->>'review_note','')))<5 then raise exception 'Enter a review reason.'; end if;
     update public.assessment_result_submissions set status=case when act='APPROVE_RESULTS' then 'APPROVED' else 'REJECTED' end,
       reviewer_id=actor,review_note=btrim(p_input->>'review_note'),reviewed_at=now() where id=r.id returning * into r;
   else raise exception 'Unknown assessment action.'; end if;
 end if;
 result:=jsonb_build_object('id',a.id,'status',coalesce(r.status,a.status),'revision',r.revision);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
 values(actor,'ASSESSMENT',a.id::text,act,case when r.id is null then to_jsonb(a) else to_jsonb(r) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.admission_case_detail(p_admission_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  result jsonb; charges jsonb; extras jsonb;
begin
  if auth.uid() is null or not public.has_permission('admissions.view') then
    raise exception 'Admission workspace access denied.';
  end if;

  select jsonb_build_object(
    'id', a.id,
    'number', a.admission_no,
    'status', a.status,
    'createdAt', a.created_at,
    'existingStudent', a.existing_student,
    'origin', a.origin,
    'originProspectId', a.origin_prospect_id,
    'batchId', a.batch_id,
    'batchName', b.name,
    'batchCode', b.code,
    'batchCapacity', b.capacity,
    'batchOccupied', (
      select count(*)
      from public.enrollments e
      where e.batch_id = b.id
        and e.status = 'ACTIVE'
    ),
    'offeringId', o.id,
    'offeringName', o.name,
    'className', coalesce(cl.name,'Not applicable'),
    'yearName', coalesce(ay.name,'Not applicable'),
    'branchName', br.name,
    'studentNo', s.student_no,
    'studentId', s.id,
    'name', a.identity_snapshot->>'student_name',
    'nameBn', a.identity_snapshot->>'student_name_bn',
    'gender', a.identity_snapshot->>'gender',
    'dateOfBirth', a.identity_snapshot->>'date_of_birth',
    'schoolName', a.identity_snapshot->>'school_name',
    'schoolRoll', a.identity_snapshot->>'school_roll',
    'guardianAddress', a.identity_snapshot->>'guardian_address',
    'alternateMobile', a.identity_snapshot->>'alternate_mobile',
    'guardianRelationship', a.identity_snapshot->>'guardian_relationship',
    'guardian', a.identity_snapshot->>'guardian_name',
    'mobile', a.identity_snapshot->>'mobile',
    'feeVersion', f.version,
    'feePlanId', f.id,
    'policyVersion', r.version,
    'paymentRequirement', r.payload->>'payment_requirement',
    'components', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', fc.name,
          'amount', fc.amount,
          'recurrence', fc.recurrence
        )
        order by fc.sort_order, fc.id
      )
      from public.fee_plan_components fc
      where fc.fee_plan_version_id = f.id
    ), '[]'::jsonb),
    'invoice', case
      when i.id is null then null
      else jsonb_build_object(
        'id', i.id, 'number', i.invoice_no,
        'total', i.total,
        'dueOn', i.due_on,
        'paid', bal.paid,
        'credits', bal.credits,
        'net', bal.net,
        'refunded', bal.refunded,
        'due', bal.due,
        'credit', bal.credit_balance
      )
    end,
    'receipts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'number', p.receipt_no,
          'amount', pa.amount,
          'postedAt', p.posted_at,
          'method', pm.name,
          'refunded', coalesce((
            select sum(ra.amount)
            from public.refund_authorizations ra
            join public.refund_payouts rp
              on rp.authorization_id = ra.id
            where ra.payment_id = p.id
          ), 0)
        )
        order by p.posted_at, p.receipt_no
      )
      from public.admission_payment_allocations pa
      join public.admission_payments p
        on p.id = pa.payment_id
      join public.payment_methods pm
        on pm.id = p.payment_method_id
      where pa.invoice_id = i.id
    ), '[]'::jsonb)
  )
  into result
  from public.admission_cases a
  join public.fee_plan_versions f
    on f.id = a.fee_plan_version_id
  join public.batches b
    on b.id = a.batch_id
  join public.programme_offerings o
    on o.id = b.offering_id
  left join public.classes cl
    on cl.id = b.class_id
  left join public.academic_years ay
    on ay.id = b.academic_year_id
  left join public.branches br
    on br.id = b.branch_id
  left join public.students s
    on s.id = a.student_id
  left join public.business_rule_versions r
    on r.id = a.activation_policy_version_id
  left join public.admission_invoices i
    on i.admission_id = a.id
   and i.invoice_kind = 'INITIAL'
  left join lateral public.invoice_balance(i.id) bal
    on true
  where a.id = p_admission_id;

  if result is null then
    raise exception 'Admission Case not found.';
  end if;

  result:=result||(select jsonb_build_object('academyRoll',s.academy_roll::text,'discountPercent',a.selected_discount_percent,'discountReason',a.discount_reason,'additionalDetails',
 jsonb_build_object('student_mobile',a.identity_snapshot->>'student_mobile','student_email',a.identity_snapshot->>'student_email','present_landmark',a.identity_snapshot->>'present_landmark','permanent_same_as_present',a.identity_snapshot->>'permanent_same_as_present','father_name',a.identity_snapshot->>'father_name','mother_name',a.identity_snapshot->>'mother_name',
 'birth_registration',a.identity_snapshot->>'birth_registration','permanent_address',a.identity_snapshot->>'permanent_address',
 'emergency_contact',a.identity_snapshot->>'emergency_contact','emergency_mobile',a.identity_snapshot->>'emergency_mobile',
 'previous_result',a.identity_snapshot->>'previous_result','learning_needs',a.identity_snapshot->>'learning_needs'))
 from public.admission_cases a left join public.students s on s.id=a.student_id where a.id=p_admission_id);

 select additional_charges into charges from public.admission_cases where id=p_admission_id;
 select coalesce(jsonb_agg(jsonb_build_object('name',value->>'name','amount',(value->>'amount')::numeric,'recurrence','ONE_TIME')),'[]') into extras from jsonb_array_elements(charges) where (value->>'is_active')::boolean;
 return result||jsonb_build_object('tuitionTotal',(select coalesce(sum(c.amount),0) from public.fee_plan_components c join public.admission_cases a on a.fee_plan_version_id=c.fee_plan_version_id where a.id=p_admission_id and c.charge_type='TUITION'),'additionalCharges',charges,'components',(result->'components')||extras);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admission_offering_options()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when auth.uid() is null or not public.has_permission('admissions.view')
      then '[]'::jsonb
    else coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,'name',o.name,'code',o.code,
        'classId',o.class_id,'className',coalesce(c.name,'Not applicable'),
        'yearName',coalesce(ay.name,'Not applicable'),'branchName',br.name,
        'feeReady',exists(
          select 1 from public.fee_plan_versions f
          where f.offering_id=o.id and f.status='ACTIVE'
            and f.effective_from <= timezone(org.timezone,now())::date
        )
      ) order by ay.starts_on desc,o.name)
      from public.programme_offerings o
      left join public.classes c on c.id=o.class_id
      left join public.academic_years ay on ay.id=o.academic_year_id
      join public.organizations org on org.id=o.organization_id
      left join public.branches br on br.id=o.branch_id
      where o.status='ACTIVE'
    ),'[]'::jsonb)
  end;
$function$;

CREATE OR REPLACE FUNCTION public.billing_preview(p_period date, p_term_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare period_date date:=p_period; term public.billing_terms; rows jsonb; total numeric;
begin
 if auth.uid() is null or not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
 if p_term_id is not null then
  select * into term from public.billing_terms where id=p_term_id;
  if term.id is null then raise exception 'Term not found.'; end if;
  period_date:=term.starts_on;
 elsif period_date is null or period_date<>date_trunc('month',period_date)::date then raise exception 'Select the first day of a billing month.';
 end if;
 select coalesce(jsonb_agg(x order by x->>'admissionId'),'[]'::jsonb) into rows from (
 select jsonb_build_object('admissionId',a.id,'name',s.full_name,'number',a.admission_no,'feePlanId',f.id,
 'gross',charges.gross,'discount',least(charges.tuition,coalesce(case when d.kind='PERCENT' then round(charges.tuition*d.value/100,2) else d.value end,0)),
 'dueOn',case when p_term_id is not null then term.due_on else period_date+f.due_day-1 end) x
 from public.admission_cases a join public.students s on s.id=a.student_id
 join public.enrollments e on e.id=a.enrollment_id and e.status='ACTIVE'
 join public.batches b on b.id=a.batch_id join public.programme_offerings po on po.id=b.offering_id left join public.academic_years y on y.id=b.academic_year_id
 join public.fee_plan_versions f on f.id=a.fee_plan_version_id
 join public.admission_invoices initial on initial.admission_id=a.id and initial.invoice_kind='INITIAL'
 cross join lateral (select coalesce(sum(amount),0) gross,coalesce(sum(amount) filter(where charge_type='TUITION'),0) tuition from public.fee_plan_components where fee_plan_version_id=f.id and recurrence='PER_CYCLE') charges
 left join public.admission_discounts d on d.admission_id=a.id and period_date between d.starts_on and d.ends_on
 where a.status='ACTIVE_ENROLLMENT' and period_date between coalesce(po.teaching_starts_on,y.starts_on) and coalesce(po.teaching_ends_on,y.ends_on)
 and ((p_term_id is null and f.billing_cycle='MONTHLY' and period_date>initial.billing_period)
   or (p_term_id is not null and f.billing_cycle='TERM' and b.academic_year_id=term.academic_year_id and term.starts_on>initial.issued_on))
 and not exists(select 1 from public.admission_invoices i where i.admission_id=a.id and i.billing_period=period_date)
 ) q;
 select coalesce(sum((x->>'gross')::numeric-(x->>'discount')::numeric),0) into total from jsonb_array_elements(rows) x;
 return jsonb_build_object('period',period_date,'termId',p_term_id,'rows',rows,'netTotal',total,'token',md5(rows::text||period_date::text||coalesce(p_term_id::text,'')));
end; $function$;

CREATE OR REPLACE FUNCTION public.list_public_programme_offerings()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id, coalesce(ay.name,'Not applicable') as academic_year_name,
      b.name as branch_name, coalesce(c.name,'Not applicable') as class_name, ag.name as group_name,
      o.showcase_title, o.showcase_title_bn, o.showcase_description,
      o.showcase_description_bn, o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      o.public_schedule, o.public_schedule_bn, o.public_requirements,
      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (select count(*)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as active_batch_count,
      (select coalesce(sum(bb.capacity),0)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_total_seats,
      (select coalesce(sum(greatest(bb.capacity-(select count(*) from public.enrollments e where e.batch_id=bb.id and e.status='ACTIVE'),0)),0)::integer
       from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_open_seats,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN' end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name)
        order by pos.sort_order), '[]'::jsonb)
       from public.programme_offering_subjects pos
       join public.subjects s on s.id = pos.subject_id
       where pos.offering_id = o.id and s.is_active) as subjects,
      (select jsonb_build_object('billing_cycle', fp.billing_cycle,
        'currency_code', fp.currency_code,
        'components', coalesce((select jsonb_agg(jsonb_build_object(
          'code', fc.code, 'name', fc.name, 'amount', fc.amount,
          'charge_type', fc.charge_type, 'recurrence', fc.recurrence)
          order by fc.sort_order) from public.fee_plan_components fc
          where fc.fee_plan_version_id = fp.id), '[]'::jsonb))
       from public.fee_plan_versions fp
       where fp.offering_id = o.id and fp.status = 'ACTIVE' limit 1) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    left join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    left join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at limit 24
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.student_profile_workspace(p_student_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.students;canonical uuid;ids uuid[];can_finance boolean:=public.has_permission('finance.view');result jsonb;
begin
 if auth.uid() is null or not public.has_permission('students.view') then raise exception 'Student access required.';end if;
 select * into s from public.students where id=p_student_id;
 if s.id is null then return null;end if;
 canonical:=coalesce(s.merged_into_id,s.id);
 select array_agg(id) into ids from public.students where id=canonical or merged_into_id=canonical;
 select jsonb_build_object(
 'student',jsonb_build_object('id',s.id,'number',s.student_no,'name',s.full_name,'nameBn',s.name_bn,'status',s.status,'birthDate',s.date_of_birth,'school',coalesce((select name from public.schools where id=s.school_id),s.school_name_snapshot),'createdAt',s.created_at,'canonicalId',canonical,'canonicalNumber',(select student_no from public.students where id=canonical)),
 'identities',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',full_name,'number',student_no)) from public.students where id=any(ids)),'[]'::jsonb),
 'guardians',coalesce((select jsonb_agg(jsonb_build_object('id',sg.id,'studentId',sg.student_id,'name',g.full_name,'mobile',g.mobile,'alternateMobile',g.alternate_mobile,'relationship',sg.relationship_snapshot,'primary',sg.is_primary)) from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=any(ids)),'[]'::jsonb),
 'enrollments',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'studentId',e.student_id,'year',coalesce(y.name,'Not applicable'),'class',coalesce(c.name,'Not applicable'),'batch',b.name,'status',e.status,'startsOn',e.admission_date,'endsOn',e.ended_on) order by e.created_at desc) from public.enrollments e left join public.academic_years y on y.id=e.academic_year_id left join public.classes c on c.id=e.class_id left join public.batches b on b.id=e.batch_id where e.student_id=any(ids)),'[]'::jsonb),
 'admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'number',a.admission_no,'studentId',a.student_id,'batchId',a.batch_id,'offeringId',b.offering_id,'batch',b.name,'status',a.status,'createdAt',a.created_at,'feeVersion',f.version) order by a.created_at desc) from public.admission_cases a join public.batches b on b.id=a.batch_id join public.fee_plan_versions f on f.id=a.fee_plan_version_id where a.student_id=any(ids)),'[]'::jsonb),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'offeringId',b.offering_id,'offering',o.name,'year',coalesce(y.name,'Not applicable'),'class',coalesce(c.name,'Not applicable'),'capacity',least(b.capacity,(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE')),'occupied',(select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE'))) from public.batches b join public.programme_offerings o on o.id=b.offering_id left join public.academic_years y on y.id=b.academic_year_id left join public.classes c on c.id=b.class_id where b.organization_id=s.organization_id and b.is_active and o.status='ACTIVE'),'[]'::jsonb),
 'invoices',case when can_finance then coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'studentId',i.student_id,'number',i.invoice_no,'period',i.billing_period,'gross',bal.gross,'credits',bal.credits,'paid',bal.paid,'refunded',bal.refunded,'due',bal.due,'credit',bal.credit_balance) order by i.posted_at desc) from public.admission_invoices i cross join lateral public.invoice_balance(i.id) bal where i.student_id=any(ids)),'[]'::jsonb) else '[]'::jsonb end,
 'financeVisible',can_finance,
 'transfers',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'fromBatch',b.name,'toBatch',d.name,'date',t.transferred_on,'authorizedBy',t.authorized_by) order by t.created_at desc) from public.enrollment_transfers t join public.batches b on b.id=t.from_batch_id join public.batches d on d.id=t.to_batch_id where t.student_id=any(ids)),'[]'::jsonb),
 'candidates',case when public.has_permission('students.manage') then coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.full_name,'number',t.student_no,'status',t.status,'birthDate',t.date_of_birth,'school',t.school_name_snapshot,'mobile',(select g.mobile from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=t.id and sg.is_primary))) from public.students t where t.id<>s.id and t.organization_id=s.organization_id and t.merged_into_id is null and t.status<>'ARCHIVED' and (lower(btrim(t.full_name))=lower(btrim(s.full_name)) or exists(select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians z join public.guardians gz on gz.id=z.guardian_id where x.student_id=s.id and z.student_id=t.id and gx.mobile=gz.mobile))),'[]'::jsonb) else '[]'::jsonb end
 ) into result;
 return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admission_workspace()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_view boolean:=public.has_permission('admissions.view'); v_result jsonb;
begin
 if auth.uid() is null or not (v_view or public.has_permission('academics.view')) then raise exception 'Workspace access denied.'; end if;
 select jsonb_build_object(
  'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'code',o.code,
      'classId',o.class_id,'className',coalesce(c.name,'Not applicable'),'yearName',coalesce(ay.name,'Not applicable'),'branchName',br.name))
    from public.programme_offerings o left join public.classes c on c.id=o.class_id
    left join public.academic_years ay on ay.id=o.academic_year_id left join public.branches br on br.id=o.branch_id
    join public.organizations org on org.id=o.organization_id
    where o.status='ACTIVE' and exists(select 1 from public.fee_plan_versions f
      where f.offering_id=o.id and f.status='ACTIVE'
        and f.effective_from<=timezone(org.timezone,now())::date)),'[]'::jsonb),
  'capacityLimit',(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'),
  'batches',coalesce((select jsonb_agg(jsonb_build_object(
    'id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,
    'offeringName',o.name,'classId',b.class_id,'className',coalesce(c.name,'Not applicable'),
    'yearName',coalesce(y.name,'Not applicable'),'branchName',br.name,'capacity',b.capacity,
    'isActive',b.is_active,'scheduleSummary',public.batch_schedule_summary(b.id),
    'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE')
  ) order by y.starts_on desc,o.name,b.name)
    from public.batches b
    join public.programme_offerings o on o.id=b.offering_id
    left join public.classes c on c.id=b.class_id
    left join public.academic_years y on y.id=b.academic_year_id
    left join public.branches br on br.id=b.branch_id
  ),'[]'::jsonb),
  'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'interestedOfferingId',p.interested_offering_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,
  'cases',case when v_view then coalesce((select jsonb_agg(x order by x->>'createdAt' desc) from (
    select jsonb_build_object('id',a.id,'number',a.admission_no,'status',a.status,'createdAt',a.created_at,
      'existingStudent',a.existing_student,'batchId',a.batch_id,'studentNo',s.student_no,'studentId',s.id,'name',a.identity_snapshot->>'student_name','nameBn',a.identity_snapshot->>'student_name_bn',
      'gender',a.identity_snapshot->>'gender','dateOfBirth',a.identity_snapshot->>'date_of_birth',
      'schoolName',a.identity_snapshot->>'school_name','schoolRoll',a.identity_snapshot->>'school_roll',
      'guardianAddress',a.identity_snapshot->>'guardian_address','alternateMobile',a.identity_snapshot->>'alternate_mobile',
      'guardianRelationship',a.identity_snapshot->>'guardian_relationship',
      'guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',
      'feeVersion',f.version,'feePlanId',f.id,'policyVersion',r.version,'paymentRequirement',r.payload->>'payment_requirement',
      'components',coalesce((select jsonb_agg(jsonb_build_object('name',fc.name,'amount',fc.amount,'recurrence',fc.recurrence)) from public.fee_plan_components fc where fc.fee_plan_version_id=f.id),'[]'::jsonb),
      'invoice',case when i.id is null then null else jsonb_build_object('number',i.invoice_no,'total',i.total,'dueOn',i.due_on,'paid',bal.paid,'credits',bal.credits,'net',bal.net,'refunded',bal.refunded,'due',bal.due,'credit',bal.credit_balance) end,
      'receipts',coalesce((select jsonb_agg(jsonb_build_object('number',p.receipt_no,'amount',pa.amount,'postedAt',p.posted_at,'method',pm.name,'refunded',coalesce((select sum(ra.amount) from public.refund_authorizations ra join public.refund_payouts rp on rp.authorization_id=ra.id where ra.payment_id=p.id),0))) from public.admission_payment_allocations pa join public.admission_payments p on p.id=pa.payment_id join public.payment_methods pm on pm.id=p.payment_method_id where pa.invoice_id=i.id),'[]'::jsonb)
    ) as x
    from public.admission_cases a join public.fee_plan_versions f on f.id=a.fee_plan_version_id
    left join public.students s on s.id=a.student_id left join public.business_rule_versions r on r.id=a.activation_policy_version_id
    left join public.admission_invoices i on i.admission_id=a.id and i.invoice_kind='INITIAL'
    left join lateral public.invoice_balance(i.id) bal on true
  ) rows),'[]'::jsonb) else '[]'::jsonb end,
  'paymentMethods',case when public.has_permission('finance.payments.post') then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb) else '[]'::jsonb end
 ) into v_result;
 return v_result;
end; $function$;

CREATE OR REPLACE FUNCTION public.academic_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(coalesce(p_input->>'reason',''));key public.admission_command_keys;
 b public.batches;room public.academic_rooms;r public.academic_routines;cs public.class_sessions;cv public.curriculum_versions;teacher public.staff;year public.academic_years;
 att public.attendance_submissions;last_att public.attendance_submissions;approval public.approval_requests;
 sid uuid;rid uuid;bid uuid;subid uuid;tid uuid;roomid uuid;date_from date;date_to date;day date;st time;et time;tz text;start_at timestamptz;end_at timestamptz;
 rows jsonb;roster jsonb;entry jsonb;unit jsonb;result jsonb;created integer:=0;permission text;scope text;id_out uuid;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if req is null or length(reason)<5 or length(reason)>500 then raise exception 'A request identity and reason of 5–500 characters are required.';end if;
 permission:=case action when 'CREATE_ROOM' then 'academics.sessions.manage' when 'PUBLISH_CURRICULUM' then 'academics.curriculum.manage' when 'CREATE_ROUTINE' then 'academics.sessions.manage' when 'RETIRE_ROUTINE' then 'academics.sessions.manage' when 'GENERATE_SESSIONS' then 'academics.sessions.manage' when 'CREATE_SESSION' then 'academics.sessions.manage' when 'CANCEL_SESSION' then 'academics.sessions.manage' when 'SAVE_ATTENDANCE' then 'academics.attendance.record' when 'SUBMIT_ATTENDANCE' then 'academics.attendance.record' when 'DECIDE_ATTENDANCE' then 'academics.attendance.approve' else null end;
 if permission is null or not public.has_permission(permission) then raise exception 'Permission denied for this academic action.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 if action in('SAVE_ATTENDANCE','SUBMIT_ATTENDANCE','DECIDE_ATTENDANCE') then return public.attendance_command(p_input);end if;
 -- Serialize schedule conflict checks and attendance/session-state transitions.
 if action='CREATE_ROOM' then
  if not exists(select 1 from public.branches where id=(p_input->>'branch_id')::uuid and is_active) then raise exception 'Choose an active branch.';end if;
  insert into public.academic_rooms(branch_id,name,capacity,created_by) values((p_input->>'branch_id')::uuid,btrim(p_input->>'name'),(p_input->>'capacity')::integer,actor) returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Room created.');
 elsif action='PUBLISH_CURRICULUM' then
  select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active;
  select * into year from public.academic_years where id=b.academic_year_id;
  year.starts_on:=coalesce((select teaching_starts_on from public.programme_offerings where id=b.offering_id),year.starts_on);
  year.ends_on:=coalesce((select teaching_ends_on from public.programme_offerings where id=b.offering_id),year.ends_on);
  if b.id is null or not exists(select 1 from public.subjects where id=(p_input->>'subject_id')::uuid and organization_id=b.organization_id and is_active) then raise exception 'Choose an active batch and subject in the same organization.';end if;
  rows:=p_input->'units';
  if length(btrim(coalesce(p_input->>'title','')))<2 or rows is null or jsonb_typeof(rows)<>'array' then raise exception 'A title and curriculum units are required.';end if;
  if jsonb_array_length(rows)=0 then raise exception 'Add at least one curriculum unit.';end if;
  for unit in select x from jsonb_array_elements(rows) x loop
   if length(btrim(coalesce(unit->>'title','')))<2 or (unit->>'target_date')::date is null or (unit->>'target_date')::date not between year.starts_on and year.ends_on then raise exception 'Each unit needs a title and target date inside the academic year.';end if;
  end loop;
  insert into public.curriculum_versions(batch_id,subject_id,version,title,units,reason,published_by)
  select b.id,(p_input->>'subject_id')::uuid,coalesce(max(v.version),0)+1,btrim(p_input->>'title'),rows,btrim(p_input->>'reason'),actor from public.curriculum_versions v where v.batch_id=b.id and v.subject_id=(p_input->>'subject_id')::uuid returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Curriculum version published. Earlier versions and session references are preserved.');
 elsif action in('CREATE_ROUTINE','GENERATE_SESSIONS','CREATE_SESSION') then
  if action='GENERATE_SESSIONS' then
   select * into r from public.academic_routines where id=(p_input->>'routine_id')::uuid and retired_at is null;
   if r.id is null then raise exception 'Active routine not found.';end if;
   bid:=r.batch_id;subid:=r.subject_id;tid:=r.teacher_id;roomid:=r.room_id;st:=r.start_time;et:=r.end_time;
   date_from:=(p_input->>'starts_on')::date;date_to:=(p_input->>'ends_on')::date;
   if date_from<r.starts_on or date_to>r.ends_on then raise exception 'Generation dates must stay inside the routine period.';end if;
  else
   bid:=(p_input->>'batch_id')::uuid;subid:=(p_input->>'subject_id')::uuid;tid:=(p_input->>'teacher_id')::uuid;roomid:=(p_input->>'room_id')::uuid;
   st:=(p_input->>'start_time')::time;et:=(p_input->>'end_time')::time;
   date_from:=(p_input->>'starts_on')::date;date_to:=case when action='CREATE_SESSION' then date_from else (p_input->>'ends_on')::date end;
  end if;
  select * into b from public.batches where id=bid and is_active for update;
  select * into room from public.academic_rooms where id=roomid and is_active;
  select * into teacher from public.staff where id=tid and status='ACTIVE';
  select * into year from public.academic_years where id=b.academic_year_id;
  year.starts_on:=coalesce((select teaching_starts_on from public.programme_offerings where id=b.offering_id),year.starts_on);
  year.ends_on:=coalesce((select teaching_ends_on from public.programme_offerings where id=b.offering_id),year.ends_on);
  select timezone into tz from public.organizations where id=b.organization_id;
  if b.id is null or b.offering_id is null or room.id is null or room.branch_id is distinct from b.branch_id or teacher.id is null then raise exception 'Choose an active batch, active teacher and room in the batch branch.';end if;
  if teacher.branch_id is not null and teacher.branch_id<>b.branch_id then raise exception 'Teacher belongs to a different branch.';end if;
  if room.capacity<b.capacity then raise exception 'Room capacity is below the configured batch capacity.';end if;
  if not exists(select 1 from public.subjects where id=subid and organization_id=b.organization_id and is_active) then raise exception 'Subject is unavailable for this organization.';end if;
  if date_from is null or date_to is null or date_to<date_from or date_from<year.starts_on or date_to>year.ends_on or st is null or et is null or et<=st then raise exception 'Enter valid same-day class times and dates inside the academic year.';end if;
  if not exists(select 1 from public.staff_subject_assignments where staff_id=tid and subject_id=subid and effective_from<=date_from and (effective_to is null or effective_to>=date_to)) or not exists(select 1 from public.staff_role_assignments a join public.staff_roles sr on sr.id=a.staff_role_id where a.staff_id=tid and sr.is_teaching_role and a.effective_from<=date_from and (a.effective_to is null or a.effective_to>=date_to)) then raise exception 'Teacher must have a teaching role and subject qualification covering these dates.';end if;
  if action='CREATE_ROUTINE' then
   if (p_input->>'weekday')::integer is null or (p_input->>'weekday')::integer not between 0 and 6 then raise exception 'Choose a weekday.';end if;
   if exists(select 1 from public.academic_routines x where x.retired_at is null and x.weekday=(p_input->>'weekday')::integer and x.starts_on<=date_to and x.ends_on>=date_from and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing teacher, batch or room assignment.';end if;
   if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.session_date between date_from and date_to and extract(dow from x.session_date)=(p_input->>'weekday')::integer and (x.starts_at at time zone tz)::time<et and (x.ends_at at time zone tz)::time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing dated session.';end if;
   insert into public.academic_routines(batch_id,subject_id,teacher_id,room_id,weekday,start_time,end_time,starts_on,ends_on,created_by)
   values(bid,subid,tid,roomid,(p_input->>'weekday')::integer,st,et,date_from,date_to,actor) returning id into id_out;
   result:=jsonb_build_object('id',id_out,'message','Routine created. Generate dated sessions to make classes operational.');
  else
   if date_to-date_from>93 then raise exception 'Generate at most 94 days per request; split larger jobs.';end if;
   scope:=btrim(coalesce(p_input->>'planned_scope',''));
   if length(scope)<2 then raise exception 'Describe the planned scope for these classes.';end if;
   if nullif(p_input->>'curriculum_id','') is not null then
    select * into cv from public.curriculum_versions where id=(p_input->>'curriculum_id')::uuid and batch_id=bid and subject_id=subid;
    if cv.id is null then raise exception 'Curriculum version must match the session batch and subject.';end if;
   end if;
   for day in select d::date from generate_series(date_from::timestamp,date_to::timestamp,interval '1 day') d loop
    if action='GENERATE_SESSIONS' and extract(dow from day)<>r.weekday then continue;end if;
    if action='GENERATE_SESSIONS' and public.academic_closed(b.organization_id,b.branch_id,day) then continue;end if;
    if action='GENERATE_SESSIONS' and exists(select 1 from public.class_sessions where routine_id=r.id and session_date=day) then continue;end if;
    start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
    if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.starts_at<end_at and x.ends_at>start_at and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflict on %: teacher, batch or room is occupied. Nothing was posted.',day;end if;
    if exists(select 1 from public.academic_routines x where x.retired_at is null and x.id is distinct from coalesce(r.id,(with recursive lineage as(select id,routine_id,replacement_for_id from public.class_sessions where id=nullif(current_setting('sohoj.replacement_for',true),'')::uuid union all select ancestor.id,ancestor.routine_id,ancestor.replacement_for_id from public.class_sessions ancestor join lineage previous on ancestor.id=previous.replacement_for_id) select routine_id from lineage where routine_id is not null limit 1)) and x.weekday=extract(dow from day) and day between x.starts_on and x.ends_on and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflicts with a reserved routine on %.',day;end if;
    insert into public.class_sessions(routine_id,batch_id,subject_id,teacher_id,room_id,curriculum_version_id,planned_scope,session_date,starts_at,ends_at,created_by)
    values(r.id,bid,subid,tid,roomid,cv.id,scope,day,start_at,end_at,actor) returning id into id_out;
    created:=created+1;
   end loop;
   result:=jsonb_build_object('id',coalesce(id_out,r.id),'message',created||' dated sessions created. Existing routine dates were preserved.');
  end if;
 elsif action='RETIRE_ROUTINE' then
  update public.academic_routines set retired_at=now() where id=(p_input->>'routine_id')::uuid and retired_at is null returning id into id_out;
  if id_out is null then raise exception 'Active routine not found.';end if;
  result:=jsonb_build_object('id',id_out,'message','Routine retired. Existing dated sessions remain; cancel affected occurrences explicitly.');
 else
  if action='DECIDE_ATTENDANCE' then
   select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid and workflow_type='ATTENDANCE';
   if approval.id is null then raise exception 'Attendance approval not found.';end if;
   sid:=approval.entity_id::uuid;
  else sid:=(p_input->>'session_id')::uuid;end if;
  if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.';end if;
  select * into cs from public.class_sessions where id=sid for update;
  select * into last_att from public.attendance_submissions where session_id=sid order by revision desc limit 1;
  if action='CANCEL_SESSION' then
   if cs.status='CANCELLED' then raise exception 'Session already cancelled.';end if;
   if exists(select 1 from public.attendance_submissions where session_id=sid and status in('SUBMITTED','APPROVED')) then raise exception 'A session with submitted or approved attendance cannot be cancelled.';end if;
   update public.class_sessions set status='CANCELLED',cancellation_reason=reason,cancelled_by=actor,cancelled_at=now() where id=sid;
   result:=jsonb_build_object('id',sid,'message','Session cancelled; the original schedule and reason remain in history.');
  elsif action='SAVE_ATTENDANCE' then
   if cs.status<>'SCHEDULED' or cs.starts_at>now() then raise exception 'Attendance can be recorded only after a scheduled class has started.';end if;
   if last_att.status='SUBMITTED' then raise exception 'Attendance is awaiting a decision.';end if;
   if last_att.id is distinct from nullif(p_input->>'base_id','')::uuid then raise exception 'Attendance changed. Refresh before saving a new revision.';end if;
   -- Lock placement while the first roster is snapshotted. Later revisions retain that roster.
   perform 1 from public.batches where id=cs.batch_id for update;
   if last_att.id is null then
    select coalesce(jsonb_agg(jsonb_build_object('student_id',s.id,'enrollment_id',e.id,'number',s.student_no,'name',s.full_name) order by s.student_no),'[]'::jsonb) into roster
    from public.enrollments e join public.students s on s.id=e.student_id where e.batch_id=cs.batch_id and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date) and e.status in('ACTIVE','WITHDRAWN','COMPLETED');
   else roster:=last_att.entries;end if;
   rows:=p_input->'entries';
   if rows is null or jsonb_typeof(rows)<>'array' then raise exception 'Attendance entries are required.';end if;
   if jsonb_array_length(roster)=0 or jsonb_array_length(rows)<>jsonb_array_length(roster) or (select count(distinct x->>'enrollment_id') from jsonb_array_elements(rows) x)<>jsonb_array_length(rows) then raise exception 'Record exactly one attendance status for every roster member. Refresh if the roster changed.';end if;
   for entry in select x from jsonb_array_elements(rows) x loop
    if coalesce(entry->>'status','') not in('PRESENT','ABSENT','LATE','EXCUSED') or not exists(select 1 from jsonb_array_elements(roster) x where x->>'enrollment_id'=entry->>'enrollment_id') or length(coalesce(entry->>'note',''))>500 then raise exception 'Invalid attendance status, note or roster member.';end if;
   end loop;
   select jsonb_agg(x||jsonb_build_object('status',y->>'status','note',coalesce(y->>'note','')) order by x->>'number') into rows from jsonb_array_elements(roster) x join jsonb_array_elements(rows) y on x->>'enrollment_id'=y->>'enrollment_id';
   insert into public.attendance_submissions(session_id,revision,entries,reason,recorded_by) values(sid,coalesce(last_att.revision,0)+1,rows,reason,actor) returning id into id_out;
   result:=jsonb_build_object('id',id_out,'message','Attendance draft saved. Submit it for independent approval.');
  elsif action='SUBMIT_ATTENDANCE' then
   if cs.status<>'SCHEDULED' or last_att.id is distinct from (p_input->>'attendance_id')::uuid or last_att.status<>'DRAFT' then raise exception 'Only the latest saved draft can be submitted.';end if;
   if last_att.recorded_by<>actor then raise exception 'Only the draft author may submit it. Save your own reviewed revision first.';end if;
   insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
   values('ATTENDANCE','CLASS_SESSION',sid::text,action,jsonb_build_object('attendance_id',last_att.id,'revision',last_att.revision,'entries',last_att.entries),reason,actor,req) returning id into id_out;
   update public.attendance_submissions set status='SUBMITTED',approval_id=id_out where id=last_att.id;
   result:=jsonb_build_object('id',id_out,'message','Attendance submitted for independent approval.');
  elsif action='DECIDE_ATTENDANCE' then
   if approval.status<>'PENDING' then raise exception 'Attendance request already decided.';end if;
   select * into att from public.attendance_submissions where id=(approval.payload_snapshot->>'attendance_id')::uuid and status='SUBMITTED';
   if att.id is null then raise exception 'Submitted attendance not found.';end if;
   if actor=approval.requested_by or actor=att.recorded_by then raise exception 'Maker-checker: another authorized person must decide attendance.';end if;
   if p_input->>'decision' not in('APPROVED','REJECTED') or p_input->>'decision' is null then raise exception 'Choose Approve or Reject.';end if;
   update public.attendance_submissions set status=p_input->>'decision' where id=att.id;
   update public.approval_requests set status=(p_input->>'decision')::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
   result:=jsonb_build_object('id',att.id,'message','Attendance '||lower(p_input->>'decision')||'. Prior approved revisions remain in history.');
  end if;
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ACADEMIC_WORKFLOW',result->>'id',action,reason,result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end; $function$;

notify pgrst,'reload schema';
