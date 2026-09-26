-- Reuse permanent Student identity while preserving the normal review/billing/activation path.
create or replace function public.admission_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
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
   if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id or v_prospect.current_class_id is distinct from v_offering.class_id then
     raise exception 'Batch must match the Prospect class and an active offering.';
   end if;
   if (select count(*) from public.enrollments where batch_id=v_batch.id and status='ACTIVE')>=v_batch.capacity then raise exception 'Selected batch is full.'; end if;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_offering.organization_id;
   select * into v_fee from public.fee_plan_versions where offering_id=v_offering.id and status='ACTIVE' and effective_from<=v_today;
   if v_fee.id is null then raise exception 'No effective published Fee Plan is available.'; end if;
   insert into public.admission_cases(prospect_id,batch_id,fee_plan_version_id,identity_snapshot,created_by)
   values(v_prospect.id,v_batch.id,v_fee.id,jsonb_build_object('student_name',v_prospect.student_name,'guardian_name',v_prospect.guardian_name,
     'mobile',v_prospect.mobile,'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian'),
     'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot),v_actor) returning * into v_case;
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
     if not exists(select 1 from public.fee_plan_components where fee_plan_version_id=v_fee.id) then raise exception 'Fee Plan has no charge components.'; end if;
     insert into public.admission_invoices(admission_id,student_id,fee_plan_version_id,currency_code,total,issued_on,due_on,posted_by,billing_period)
     values(v_case.id,v_case.student_id,v_fee.id,v_fee.currency_code,v_total,v_today,
       case when v_fee.due_day is not null then greatest(v_today,date_trunc('month',v_today)::date+v_fee.due_day-1) else v_today end,v_actor,date_trunc('month',v_today)::date) returning id into v_invoice;
     insert into public.admission_invoice_lines(invoice_id,fee_component_id,name,charge_type,amount)
     select v_invoice,id,name,charge_type,amount from public.fee_plan_components where fee_plan_version_id=v_fee.id;
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
end; $$;

-- Permission-scoped read model; sensitive case/prospect data needs admissions.view.
create or replace function public.admission_workspace()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_view boolean:=public.has_permission('admissions.view'); v_result jsonb;
begin
 if auth.uid() is null or not (v_view or public.has_permission('academics.view')) then raise exception 'Workspace access denied.'; end if;
 select jsonb_build_object(
  'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'classId',o.class_id,'className',c.name)) from public.programme_offerings o join public.classes c on c.id=o.class_id where o.status='ACTIVE'),'[]'::jsonb),
  'capacityLimit',(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'),
  'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,'classId',b.class_id,'capacity',b.capacity,'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE'))) from public.batches b where b.is_active and b.offering_id is not null),'[]'::jsonb),
  'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,
  'cases',case when v_view then coalesce((select jsonb_agg(x order by x->>'createdAt' desc) from (
    select jsonb_build_object('id',a.id,'number',a.admission_no,'status',a.status,'createdAt',a.created_at,
      'existingStudent',a.existing_student,'batchId',a.batch_id,'studentNo',s.student_no,'studentId',s.id,'name',a.identity_snapshot->>'student_name','guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',
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
end; $$;
revoke all on function public.admission_workspace() from public,anon;
grant execute on function public.admission_workspace() to authenticated;
