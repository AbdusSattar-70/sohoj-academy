-- Sohoj Academy fresh database baseline: admission billing workflows.
-- Install on an empty application schema. Each object is defined once.

CREATE OR REPLACE FUNCTION public.invoice_balance(p_invoice_id uuid)
 RETURNS TABLE(gross numeric, credits numeric, paid numeric, refunded numeric, net numeric, due numeric, credit_balance numeric, reserved_refunds numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 with x as (
 select i.total as g,
 coalesce((select sum(amount) from public.invoice_credits where invoice_id=i.id),0) c,
 coalesce((select sum(amount) from public.admission_payment_allocations where invoice_id=i.id),0) p,
 coalesce((select sum(r.amount) from public.refund_authorizations r join public.refund_payouts rp on rp.authorization_id=r.id where r.invoice_id=i.id),0) f,
 coalesce((select sum(r.amount) from public.refund_authorizations r where r.invoice_id=i.id and not exists(select 1 from public.refund_payouts rp where rp.authorization_id=r.id)),0) reserved
 from public.admission_invoices i where i.id=p_invoice_id)
 select g,c,p,f,g-c,greatest(g-c-p+f,0),greatest(p-f-(g-c),0),reserved from x;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_batch_policy()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_max integer;
begin
  select (payload->>'max_students')::integer
    into v_max
  from public.business_rule_versions
  where domain='academics'
    and rule_key='batch_capacity_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if v_max is null or v_max < 1 then
    raise exception 'Active batch capacity policy is missing or invalid.';
  end if;

  if new.capacity > v_max then
    raise exception 'Batch capacity exceeds the active academy policy maximum of %.', v_max;
  end if;

  return new;
end;
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
     or new.academic_year_id <> v_batch.academic_year_id
     or new.class_id <> v_batch.class_id
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

CREATE OR REPLACE FUNCTION public.protect_admission_invoice()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ begin raise exception 'Posted billing history is immutable; use a compensating adjustment workflow.'; end; $function$;

CREATE OR REPLACE FUNCTION public.admission_payment_satisfied(p_admission_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select bal.paid-bal.refunded>=case
 when not (r.payload->>'allow_credit_enrollment')::boolean or r.payload->>'payment_requirement'='FULL' then bal.net
 when r.payload->>'payment_requirement'='MINIMUM_PERCENT' then round(bal.net*(r.payload->>'minimum_payment_percent')::numeric/100,2)
 else 0 end
 from public.admission_cases a join public.admission_invoices i on i.admission_id=a.id and i.invoice_kind='INITIAL'
 join public.business_rule_versions r on r.id=a.activation_policy_version_id
 cross join lateral public.invoice_balance(i.id) bal where a.id=p_admission_id;
$function$;

CREATE OR REPLACE FUNCTION public.post_admission_payment(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 v_actor uuid:=auth.uid(); v_request uuid:=(p_input->>'request_id')::uuid;
 v_key public.admission_command_keys; v_case public.admission_cases; v_invoice public.admission_invoices;
 v_payment public.admission_payments; v_amount numeric:=(p_input->>'amount')::numeric;
 v_paid numeric; v_result jsonb; v_reason text:=btrim(coalesce(p_input->>'reason',''));
begin
 if v_actor is null or not public.has_permission('finance.payments.post') then raise exception 'Payment posting permission required.'; end if;
 if v_request is null or v_amount is null or v_amount<=0 or v_amount<>round(v_amount,2) or length(v_reason)<5 then raise exception 'Valid amount, request identity and reason are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 select * into v_key from public.admission_command_keys where request_id=v_request;
 if found then
   if v_key.actor_id<>v_actor or v_key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
   return v_key.result;
 end if;
 select * into v_case from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if not found or v_case.status not in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT','CANCELLED') then raise exception 'Post initial billing before collecting payment.'; end if;
 select * into v_invoice from public.admission_invoices where admission_id=v_case.id and (case when nullif(p_input->>'invoice_id','') is null then invoice_kind='INITIAL' else id=(p_input->>'invoice_id')::uuid end) for update;
 select due into v_paid from public.invoice_balance(v_invoice.id);
 if v_invoice.id is null or v_amount>v_paid then raise exception 'Payment exceeds the outstanding invoice balance.'; end if;
 if not exists(select 1 from public.payment_methods where id=(p_input->>'payment_method_id')::uuid and is_active) then raise exception 'Choose an active payment method.'; end if;
 insert into public.admission_payments(student_id,payment_method_id,amount,currency_code,external_reference,posted_by,reason)
 values(v_case.student_id,(p_input->>'payment_method_id')::uuid,v_amount,v_invoice.currency_code,nullif(btrim(p_input->>'external_reference'),''),v_actor,v_reason) returning * into v_payment;
 insert into public.admission_payment_allocations(payment_id,invoice_id,amount) values(v_payment.id,v_invoice.id,v_amount);
 v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status,'receipt_no',v_payment.receipt_no);
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(v_request,v_actor,'PAYMENT',v_payment.id::text,'POST',v_reason,to_jsonb(v_payment),jsonb_build_object('invoice_id',v_invoice.id,'admission_id',v_case.id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
 return v_result;
end; $function$;

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
      'classId',o.class_id,'className',c.name,'yearName',ay.name,'branchName',br.name))
    from public.programme_offerings o join public.classes c on c.id=o.class_id
    join public.academic_years ay on ay.id=o.academic_year_id left join public.branches br on br.id=o.branch_id
    join public.organizations org on org.id=o.organization_id
    where o.status='ACTIVE' and exists(select 1 from public.fee_plan_versions f
      where f.offering_id=o.id and f.status='ACTIVE'
        and f.effective_from<=timezone(org.timezone,now())::date)),'[]'::jsonb),
  'capacityLimit',(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'),
  'batches',coalesce((select jsonb_agg(jsonb_build_object(
    'id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,
    'offeringName',o.name,'classId',b.class_id,'className',c.name,
    'yearName',y.name,'branchName',br.name,'capacity',b.capacity,
    'isActive',b.is_active,
    'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE')
  ) order by y.starts_on desc,o.name,b.name)
    from public.batches b
    join public.programme_offerings o on o.id=b.offering_id
    join public.classes c on c.id=b.class_id
    join public.academic_years y on y.id=b.academic_year_id
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

CREATE OR REPLACE FUNCTION public.apply_invoice_discounts(p_invoice_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  i public.admission_invoices;
  d public.admission_discounts;
  tuition numeric;
  credit numeric;
begin
  select * into i
  from public.admission_invoices
  where id=p_invoice_id;

  select coalesce(sum(amount),0)
  into tuition
  from public.admission_invoice_lines
  where invoice_id=i.id
    and charge_type='TUITION';

  for d in
    select *
    from public.admission_discounts
    where admission_id=i.admission_id
      and i.billing_period between starts_on and ends_on
  loop
    credit:=least(
      tuition,
      case
        when d.kind='PERCENT' then round(tuition*d.value/100,2)
        else d.value
      end
    );

    if credit>0 then
      insert into public.invoice_credits(invoice_id, discount_id, kind, amount, applied_by)
      values(i.id, d.id, 'DISCOUNT', credit, d.authorized_by)
      on conflict (invoice_id, discount_id)
        where kind='DISCOUNT' and discount_id is not null
      do nothing;
    end if;
  end loop;
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
 join public.batches b on b.id=a.batch_id join public.academic_years y on y.id=b.academic_year_id
 join public.fee_plan_versions f on f.id=a.fee_plan_version_id
 join public.admission_invoices initial on initial.admission_id=a.id and initial.invoice_kind='INITIAL'
 cross join lateral (select coalesce(sum(amount),0) gross,coalesce(sum(amount) filter(where charge_type='TUITION'),0) tuition from public.fee_plan_components where fee_plan_version_id=f.id and recurrence='PER_CYCLE') charges
 left join public.admission_discounts d on d.admission_id=a.id and period_date between d.starts_on and d.ends_on
 where a.status='ACTIVE_ENROLLMENT' and period_date between y.starts_on and y.ends_on
 and ((p_term_id is null and f.billing_cycle='MONTHLY' and period_date>initial.billing_period)
   or (p_term_id is not null and f.billing_cycle='TERM' and b.academic_year_id=term.academic_year_id and term.starts_on>initial.issued_on))
 and not exists(select 1 from public.admission_invoices i where i.admission_id=a.id and i.billing_period=period_date)
 ) q;
 select coalesce(sum((x->>'gross')::numeric-(x->>'discount')::numeric),0) into total from jsonb_array_elements(rows) x;
 return jsonb_build_object('period',period_date,'termId',p_term_id,'rows',rows,'netTotal',total,'token',md5(rows::text||period_date::text||coalesce(p_term_id::text,'')));
end; $function$;

CREATE OR REPLACE FUNCTION public.student_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys;s public.students;target public.students;a public.admission_cases;b public.batches;dest public.batches;
 fee public.fee_plan_versions;guardian record;policy public.business_rule_versions;e public.enrollments;
 sid uuid:=(p_input->>'student_id')::uuid;tid uuid:=(p_input->>'target_id')::uuid;eid uuid;aid uuid;today date;result jsonb;snapshot jsonb;
begin
 if actor is null or not public.has_permission('students.view') then raise exception 'Student access required.'; end if;
 if req is null or length(reason) not between 5 and 500 then raise exception 'Request identity and a reason of 5–500 characters required.'; end if;
 if action='CREATE_EXISTING' then
  if not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 elsif action in('TRANSFER','MERGE') then
  if not public.has_permission('students.manage') then raise exception 'Student management permission required.'; end if;
 else raise exception 'Unsupported student action.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used.'; end if;
  return key.result;
 end if;
 if action='TRANSFER' then
  aid:=(p_input->>'admission_id')::uuid;
  select * into a from public.admission_cases where id=aid for update;
  if a.id is null or a.student_id is distinct from sid then raise exception 'Admission does not belong to this student.'; end if;
 end if;
 perform 1 from public.students where id in(sid,tid) order by id for update;
 select * into s from public.students where id=sid;
 if s.id is null or s.merged_into_id is not null or s.status='ARCHIVED' then raise exception 'Use an existing canonical student.'; end if;
 select timezone(timezone,now())::date into today from public.organizations where id=s.organization_id;
  if action='CREATE_EXISTING' then
   select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
   if b.id is null or b.organization_id<>s.organization_id or not exists(select 1 from public.programme_offerings where id=b.offering_id and status='ACTIVE') then raise exception 'Select an active offering-linked batch in this organization.';end if;
   if exists(select 1 from public.enrollments where student_id=s.id and academic_year_id=b.academic_year_id and status='ACTIVE')
    or exists(select 1 from public.admission_cases ac join public.batches ba on ba.id=ac.batch_id where ac.student_id=s.id and ba.academic_year_id=b.academic_year_id and ac.status<>'CANCELLED') then
    raise exception 'An open admission or active enrollment already exists for this academic year. Use transfer or finish cancellation first.';end if;
   select * into policy from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if policy.id is null then raise exception 'Capacity policy missing.';end if;
   if (select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE')>=least(b.capacity,(policy.payload->>'max_students')::integer) then raise exception 'Selected batch is full.';end if;
   select * into fee from public.fee_plan_versions where offering_id=b.offering_id and status='ACTIVE' and effective_from<=today;
   if fee.id is null then raise exception 'An effective Fee Plan is required.';end if;
   select g.full_name,g.mobile,sg.relationship_snapshot into guardian from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=s.id and sg.is_primary;
   if guardian.full_name is null then raise exception 'A primary guardian is required.';end if;
   insert into public.admission_cases(batch_id,fee_plan_version_id,student_id,existing_student,identity_snapshot,created_by)
   values(b.id,fee.id,s.id,true,jsonb_build_object('student_name',s.full_name,'guardian_name',guardian.full_name,'mobile',guardian.mobile,'guardian_relationship',coalesce(guardian.relationship_snapshot,'Guardian'),'school_id',s.school_id,'school_name',s.school_name_snapshot),actor) returning id into aid;
   result:=jsonb_build_object('id',aid,'message','Enrollment draft created using the existing Student ID. Review and accept it in Admissions.');
  elsif action='TRANSFER' then
   if a.status<>'ACTIVE_ENROLLMENT' then raise exception 'Only an active enrollment can transfer.';end if;
   select * into e from public.enrollments where id=a.enrollment_id and status='ACTIVE';
   if e.id is null then raise exception 'Active enrollment not found.';end if;
   eid:=(p_input->>'batch_id')::uuid;
   perform 1 from public.batches where id in(a.batch_id,eid) order by id for update;
   select * into b from public.batches where id=a.batch_id;
   select * into dest from public.batches where id=eid and is_active;
   if dest.id is null or dest.id=b.id or dest.offering_id is distinct from b.offering_id or dest.organization_id<>b.organization_id then raise exception 'Transfer requires a different active batch in the same offering. Fee terms remain unchanged.';end if;
   select * into policy from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if policy.id is null then raise exception 'Capacity policy missing.';end if;
   if (select count(*) from public.enrollments where batch_id=dest.id and status='ACTIVE')>=least(dest.capacity,(policy.payload->>'max_students')::integer) then raise exception 'Destination batch is full under the current capacity policy.';end if;
    update public.enrollments set status='WITHDRAWN',ended_on=today where id=e.id;
    insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,admission_date,status,created_by)
    values(s.id,dest.organization_id,dest.branch_id,dest.academic_year_id,dest.class_id,dest.program_id,dest.id,today,'ACTIVE',actor) returning id into eid;
    insert into public.enrollment_transfers(student_id,admission_id,from_enrollment_id,to_enrollment_id,from_batch_id,to_batch_id,authorized_by,authorization_reason,capacity_policy_version_id,transferred_on)
    values(s.id,a.id,e.id,eid,b.id,dest.id,actor,reason,policy.id,today);
    update public.admission_cases set batch_id=dest.id,enrollment_id=eid,capacity_policy_version_id=policy.id where id=a.id;
   result:=jsonb_build_object('id',a.id,'message','Batch transfer completed; financial history preserved.');
  elsif action='MERGE' then
   select * into target from public.students where id=tid;
   if target.id is null or target.id=s.id or target.organization_id<>s.organization_id or target.merged_into_id is not null or target.status='ARCHIVED' then raise exception 'Select a different canonical student in this organization.';end if;
   if exists(select 1 from public.students where merged_into_id=s.id) then raise exception 'A canonical identity with linked duplicates cannot be merged again.';end if;
   if exists(select 1 from public.enrollments where student_id=s.id and status='ACTIVE') or exists(select 1 from public.admission_cases where student_id=s.id and status<>'CANCELLED') then raise exception 'Resolve the duplicate identity’s open admissions and enrollments before merging.';end if;
   if lower(btrim(s.full_name))<>lower(btrim(target.full_name)) and not exists(
    select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians y join public.guardians gy on gy.id=y.guardian_id
    where x.student_id=s.id and y.student_id=target.id and gx.mobile=gy.mobile) then raise exception 'No matching name or guardian mobile. Verify the identities before requesting a merge.';end if;
   if p_input->>'confirmed_same_person' is distinct from 'true' then raise exception 'Confirm these identities belong to the same student.'; end if;
    insert into public.student_merges(source_id,target_id,authorized_by,authorization_reason,source_snapshot,target_snapshot) values(s.id,target.id,actor,reason,to_jsonb(s),to_jsonb(target));
    update public.students set merged_into_id=target.id,status='ARCHIVED' where id=s.id;
    -- History and guardian links retain their original IDs and appear in the canonical profile.
   result:=jsonb_build_object('id',target.id,'message','Duplicate archived; original records and financial history preserved.');
  end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,'STUDENT',s.id::text,action,reason,to_jsonb(s),result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end;
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
 'enrollments',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'studentId',e.student_id,'year',y.name,'class',c.name,'batch',b.name,'status',e.status,'startsOn',e.admission_date,'endsOn',e.ended_on) order by e.created_at desc) from public.enrollments e join public.academic_years y on y.id=e.academic_year_id join public.classes c on c.id=e.class_id left join public.batches b on b.id=e.batch_id where e.student_id=any(ids)),'[]'::jsonb),
 'admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'number',a.admission_no,'studentId',a.student_id,'batchId',a.batch_id,'offeringId',b.offering_id,'batch',b.name,'status',a.status,'createdAt',a.created_at,'feeVersion',f.version) order by a.created_at desc) from public.admission_cases a join public.batches b on b.id=a.batch_id join public.fee_plan_versions f on f.id=a.fee_plan_version_id where a.student_id=any(ids)),'[]'::jsonb),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'offeringId',b.offering_id,'offering',o.name,'year',y.name,'class',c.name,'capacity',least(b.capacity,(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE')),'occupied',(select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE'))) from public.batches b join public.programme_offerings o on o.id=b.offering_id join public.academic_years y on y.id=b.academic_year_id join public.classes c on c.id=b.class_id where b.organization_id=s.organization_id and b.is_active and o.status='ACTIVE'),'[]'::jsonb),
 'invoices',case when can_finance then coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'studentId',i.student_id,'number',i.invoice_no,'period',i.billing_period,'gross',bal.gross,'credits',bal.credits,'paid',bal.paid,'refunded',bal.refunded,'due',bal.due,'credit',bal.credit_balance) order by i.posted_at desc) from public.admission_invoices i cross join lateral public.invoice_balance(i.id) bal where i.student_id=any(ids)),'[]'::jsonb) else '[]'::jsonb end,
 'financeVisible',can_finance,
 'transfers',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'fromBatch',b.name,'toBatch',d.name,'date',t.transferred_on,'authorizedBy',t.authorized_by) order by t.created_at desc) from public.enrollment_transfers t join public.batches b on b.id=t.from_batch_id join public.batches d on d.id=t.to_batch_id where t.student_id=any(ids)),'[]'::jsonb),
 'candidates',case when public.has_permission('students.manage') then coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.full_name,'number',t.student_no,'status',t.status,'birthDate',t.date_of_birth,'school',t.school_name_snapshot,'mobile',(select g.mobile from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=t.id and sg.is_primary))) from public.students t where t.id<>s.id and t.organization_id=s.organization_id and t.merged_into_id is null and t.status<>'ARCHIVED' and (lower(btrim(t.full_name))=lower(btrim(s.full_name)) or exists(select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians z join public.guardians gz on gz.id=z.guardian_id where x.student_id=s.id and z.student_id=t.id and gx.mobile=gz.mobile))),'[]'::jsonb) else '[]'::jsonb end
 ) into result;
 return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.require_admission_referral_choice()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
 if new.status='ACCEPTED' and old.status is distinct from new.status and
    not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
   raise exception 'Record a referrer or select Organic before accepting this admission.';
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.teacher_referral_matches_admission()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
 if not exists(select 1 from public.admission_referrals ar
   join public.referral_people rp on rp.id=ar.referrer_id
   where ar.admission_id=new.admission_id and ar.source='REFERRED' and rp.staff_id=new.teacher_id) then
  raise exception 'Teacher referral must match the verified admission referral.';
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.batch_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 actor uuid:=auth.uid(); req uuid:=nullif(p_input->>'request_id','')::uuid;
 action text:=p_input->>'action'; reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys; org uuid; batch public.batches;
 offering public.programme_offerings; policy public.business_rule_versions;
 v_requested_capacity integer; occupied integer; before_data jsonb; result jsonb;
begin
 if actor is null or not public.has_permission('academics.manage') then
  raise exception 'Batch management permission required.';
 end if;
 if req is null or length(reason)<5 then raise exception 'Request identity and a reason of at least five characters are required.'; end if;
 if action not in('CREATE_BATCH','EDIT_BATCH') then raise exception 'Unsupported batch action.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
  return key.result;
 end if;
 select id into org from public.organizations where code='SOHOJ' and is_active limit 1;
 select * into policy from public.business_rule_versions where domain='academics'
   and rule_key='batch_capacity_policy' and status='ACTIVE' order by version desc limit 1;
 if org is null or policy.id is null then raise exception 'Organization or active capacity policy is unavailable.'; end if;
 v_requested_capacity:=nullif(p_input->>'capacity','')::integer;
 if v_requested_capacity is null or v_requested_capacity<1 or v_requested_capacity>(policy.payload->>'max_students')::integer then
   raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',policy.payload->>'max_students';
 end if;
 if length(btrim(coalesce(p_input->>'name','')))<2 or length(btrim(coalesce(p_input->>'code','')))<2 then
   raise exception 'Enter a batch code and a recognizable batch name.';
 end if;
 if action='CREATE_BATCH' then
  select * into offering from public.programme_offerings
   where id=(p_input->>'offering_id')::uuid and organization_id=org and status='ACTIVE' for update;
  if offering.id is null then raise exception 'Choose an active offering with a published Fee Plan.'; end if;
  insert into public.batches(organization_id,branch_id,academic_year_id,class_id,program_id,
   code,name,capacity,created_by,offering_id,capacity_policy_version_id)
  values(org,offering.branch_id,offering.academic_year_id,offering.class_id,offering.program_id,
   upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_requested_capacity,actor,offering.id,policy.id)
  returning * into batch;
  result:=jsonb_build_object('id',batch.id,'status','CREATED');
 else
  select * into batch from public.batches where id=(p_input->>'batch_id')::uuid
    and organization_id=org and offering_id is not null for update;
  if batch.id is null then raise exception 'Batch not found.'; end if;
  before_data:=to_jsonb(batch);
  select count(*) into occupied from public.enrollments where batch_id=batch.id and status='ACTIVE';
  if v_requested_capacity<occupied then raise exception 'Capacity cannot be lower than the % students already enrolled.',occupied; end if;
  update public.batches b set code=upper(btrim(p_input->>'code')),
    name=btrim(p_input->>'name'),capacity=v_requested_capacity,
    capacity_policy_version_id=policy.id,updated_at=now()
  where b.id=batch.id returning b.* into batch;
  result:=jsonb_build_object('id',batch.id,'status','UPDATED');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
   entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,(select id from public.staff where profile_id=actor limit 1),
   'BATCH',batch.id::text,action,reason,
   before_data,
   to_jsonb(batch),jsonb_build_object('module','batch_register','offering_id',batch.offering_id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.sync_admission_student_details()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.student_id is not null and old.student_id is null then
    update public.students set
      name_bn=nullif(new.identity_snapshot->>'student_name_bn',''),
      gender=nullif(new.identity_snapshot->>'gender',''),
      date_of_birth=nullif(new.identity_snapshot->>'date_of_birth','')::date,
      school_roll=nullif(new.identity_snapshot->>'school_roll','')
    where id=new.student_id;
    update public.guardians g set
      alternate_mobile=coalesce(g.alternate_mobile,nullif(new.identity_snapshot->>'alternate_mobile','')),
      address=coalesce(g.address,nullif(new.identity_snapshot->>'guardian_address',''))
    from public.student_guardians sg where sg.student_id=new.student_id and sg.guardian_id=g.id;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_physical_admission_consent(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.admission_cases; r public.admission_physical_consent_receipts;
 req uuid:=(p_input->>'request_id')::uuid; signing date:=(p_input->>'guardian_signed_on')::date; today date;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or signing is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Signing date and staff note are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into r from public.admission_physical_consent_receipts where request_id=req;
 if found then
  if r.received_by<>auth.uid() or r.request_payload<>p_input then raise exception 'Request identity already used.'; end if;
  return jsonb_build_object('id',r.id);
 end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status in('DRAFT','CANCELLED') then raise exception 'Verify the application before receiving paper consent.'; end if;
 if not exists(select 1 from public.admission_referrals where admission_id=a.id) then raise exception 'Record Organic or a verified referrer first.'; end if;
 select timezone(o.timezone,now())::date into today from public.batches b join public.organizations o on o.id=b.organization_id where b.id=a.batch_id;
 if signing>today then raise exception 'Signing date cannot be in the future.'; end if;
 if exists(select 1 from public.admission_physical_consent_receipts where admission_id=a.id and identity_revision=a.identity_revision) then raise exception 'Consent for these details is already recorded.'; end if;
 insert into public.admission_physical_consent_receipts(request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,physical_copy_reference,received_by,reason,identity_revision)
 values(req,p_input,a.id,(select coalesce(max(version),0)+1 from public.admission_physical_consent_receipts where admission_id=a.id),signing,coalesce((p_input->>'student_signed')::boolean,false),nullif(btrim(p_input->>'physical_copy_reference'),''),auth.uid(),p_input->>'reason',a.identity_revision) returning * into r;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values(auth.uid(),'ADMISSION_CONSENT',r.id::text,'RECEIVE_PAPER_FORM',p_input->>'reason',to_jsonb(r));
 return jsonb_build_object('id',r.id);
end $function$;

CREATE OR REPLACE FUNCTION public.require_admission_workflow_evidence()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.status is distinct from old.status
    and new.status in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT') then
    if not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
      raise exception 'Record the admission source before continuing to billing or enrollment.';
    end if;
    if not exists(select 1 from public.admission_physical_consent_receipts p where p.admission_id=new.id and p.identity_revision=new.identity_revision) then
      raise exception 'Record the signed paper consent before continuing to billing or enrollment.';
    end if;
  end if;
  return new;
end
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
        'classId',o.class_id,'className',c.name,
        'yearName',ay.name,'branchName',br.name,
        'feeReady',exists(
          select 1 from public.fee_plan_versions f
          where f.offering_id=o.id and f.status='ACTIVE'
            and f.effective_from <= timezone(org.timezone,now())::date
        )
      ) order by ay.starts_on desc,o.name)
      from public.programme_offerings o
      join public.classes c on c.id=o.class_id
      join public.academic_years ay on ay.id=o.academic_year_id
      join public.organizations org on org.id=o.organization_id
      left join public.branches br on br.id=o.branch_id
      where o.status='ACTIVE'
    ),'[]'::jsonb)
  end;
$function$;

CREATE OR REPLACE FUNCTION public.admission_discount_options(p_admission_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare result jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.view') then raise exception 'Admission view permission required.'; end if;
 select jsonb_build_object('allowed',o.allowed_discount_percentages,'selected',a.selected_discount_percent,'reason',a.discount_reason)
 into result from public.admission_cases a join public.batches b on b.id=a.batch_id
 join public.programme_offerings o on o.id=b.offering_id where a.id=p_admission_id;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.edit_admission_identity(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.admission_cases; identity jsonb:=p_input->'identity'; guardian_id uuid; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission management permission required.'; end if;
 if jsonb_typeof(identity) is distinct from 'object' or octet_length(identity::text)>5000
 or length(btrim(coalesce(p_input->>'reason','')))<5
 or length(btrim(coalesce(identity->>'student_name',''))) not between 2 and 160
 or length(btrim(coalesce(identity->>'guardian_name',''))) not between 2 and 160
 or coalesce(identity->>'mobile','') !~ '^01[3-9][0-9]{8}$'
 or length(btrim(coalesce(identity->>'guardian_address',''))) not between 5 and 300 then raise exception 'Enter verified student, guardian, contact and address details.'; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status='CANCELLED' then raise exception 'Choose an open admission case.'; end if;
 if a.existing_student and a.student_id is null then raise exception 'Existing student identity is unavailable.'; end if;
 before_data:=a.identity_snapshot;
 identity:=jsonb_build_object('student_name',btrim(identity->>'student_name'),'student_name_bn',nullif(btrim(identity->>'student_name_bn'),''),
 'guardian_name',btrim(identity->>'guardian_name'),'mobile',identity->>'mobile','alternate_mobile',nullif(identity->>'alternate_mobile',''),
 'guardian_address',btrim(identity->>'guardian_address'),'guardian_relationship',btrim(identity->>'guardian_relationship'),
 'date_of_birth',nullif(identity->>'date_of_birth','')::date,'gender',nullif(identity->>'gender',''),
 'school_name',btrim(identity->>'school_name'),'school_roll',btrim(identity->>'school_roll'));
 if a.student_id is not null then
  if not public.has_permission('students.manage') then raise exception 'Student correction permission required.'; end if;
  update public.students set full_name=identity->>'student_name',school_name_snapshot=identity->>'school_name' where id=a.student_id;
  -- Do not change a shared guardian identity. Link to an existing matching guardian
  -- or create the corrected guardian; keep the old guardian record intact.
  select g.id into guardian_id from public.guardians g join public.students s on s.organization_id=g.organization_id
   where s.id=a.student_id and g.mobile=identity->>'mobile' and lower(g.full_name)=lower(identity->>'guardian_name') order by g.created_at limit 1;
  if guardian_id is null then
   insert into public.guardians(organization_id,full_name,mobile,created_by)
    select organization_id,identity->>'guardian_name',identity->>'mobile',auth.uid() from public.students where id=a.student_id returning id into guardian_id;
  end if;
  update public.student_guardians set is_primary=false where student_id=a.student_id and is_primary;
  insert into public.student_guardians(student_id,guardian_id,relationship_snapshot,is_primary)
  values(a.student_id,guardian_id,identity->>'guardian_relationship',true)
  on conflict(student_id,guardian_id) do update set is_primary=true,relationship_snapshot=excluded.relationship_snapshot;
 end if;
 update public.admission_cases set identity_snapshot=identity_snapshot||identity,
  identity_revision=identity_revision+1,
  status=case when status in('DRAFT','READY') then 'DRAFT' else status end where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'CORRECT_IDENTITY',p_input->>'reason',before_data,identity);
 return jsonb_build_object('id',a.id);
end $function$;

CREATE OR REPLACE FUNCTION public.admission_review_checks(p_admission_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.has_permission('admissions.view') then raise exception 'Admission view permission required.'; end if;
 return (select jsonb_build_object('hasConsent',exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=a.id and r.identity_revision=a.identity_revision),'identityRevision',a.identity_revision) from public.admission_cases a where a.id=p_admission_id);
end $function$;

CREATE OR REPLACE FUNCTION public.create_staff_admission_intake(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid := auth.uid();
  req uuid := nullif(p_input->>'request_id','')::uuid;
  reason text := btrim(coalesce(p_input->>'reason',''));
  existing public.staff_admission_intake_requests;
  offering public.programme_offerings;
  batch public.batches;
  fee public.fee_plan_versions;
  organization public.organizations;
  admission public.admission_cases;
  open_seats integer;
  local_today date; extras jsonb;
  student_name text := btrim(coalesce(p_input->>'student_name',''));
  guardian_name text := btrim(coalesce(p_input->>'guardian_name',''));
  mobile text := regexp_replace(coalesce(p_input->>'mobile',''), '\\D', '', 'g');
  alternate_mobile text := nullif(regexp_replace(coalesce(p_input->>'alternate_mobile',''), '\\D', '', 'g'), '');
  birth_date date := nullif(p_input->>'date_of_birth','')::date;
  gender_value text := nullif(btrim(coalesce(p_input->>'gender','')), '');
  school_name text := nullif(btrim(coalesce(p_input->>'school_name','')), '');
  school_roll text := nullif(btrim(coalesce(p_input->>'school_roll','')), '');
  guardian_address text := btrim(coalesce(p_input->>'guardian_address',''));
  guardian_relationship text := nullif(btrim(coalesce(p_input->>'guardian_relationship','')), '');
  intake_note text := nullif(btrim(coalesce(p_input->>'referral_note','')), '');
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if octet_length(p_input::text)>10000 then raise exception 'Application is too long.'; end if;
 if not exists(select 1 from public.organizations where code='SOHOJ' and setup_completed_at is not null and is_active) then raise exception 'Complete academy setup before starting admissions.'; end if;
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;

  if req is null or length(reason) < 5 or length(reason) > 500 then
    raise exception 'Request identity and an audit reason of 5 to 500 characters are required.';
  end if;

  if length(student_name) < 2 or length(student_name) > 160
    or length(guardian_name) < 2 or length(guardian_name) > 160
    or mobile !~ '^01[3-9][0-9]{8}$'
    or length(guardian_address) < 5
    or coalesce((p_input->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Enter the student, guardian, valid mobile, address, and confirm permission to contact.';
  end if;

  if gender_value is not null
    and gender_value not in ('Female','Male','Other','Prefer not to say') then
    raise exception 'Choose a valid gender option or leave it blank.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text, 0));

  select *
  into existing
  from public.staff_admission_intake_requests
  where request_id = req;

  if found then
    if existing.actor_id <> actor or existing.payload <> p_input then
      raise exception 'Request identity was already used for different intake details.';
    end if;

    select *
    into admission
    from public.admission_cases
    where id = existing.admission_id;

    return jsonb_build_object(
      'admission_id', existing.admission_id,
      'admission_no', admission.admission_no
    );
  end if;

  select *
  into offering
  from public.programme_offerings
  where id = nullif(p_input->>'offering_id','')::uuid
    and status = 'ACTIVE'
  for share;

  if offering.id is null then
    raise exception 'Choose an active programme offering.';
  end if;

  select *
  into batch
  from public.batches
  where id = nullif(p_input->>'batch_id','')::uuid
    and is_active
  for update;

  if batch.id is null or batch.offering_id is distinct from offering.id then
    raise exception 'Choose an active batch belonging to the selected programme offering.';
  end if;

  select *
  into organization
  from public.organizations
  where id = offering.organization_id;

  if organization.id is null then
    raise exception 'The selected programme organization is unavailable.';
  end if;

  local_today := timezone(organization.timezone, now())::date;

  select *
  into fee
  from public.fee_plan_versions
  where offering_id = offering.id
    and status = 'ACTIVE'
    and effective_from <= local_today
  order by effective_from desc, version desc
  limit 1;

  if fee.id is null then
    raise exception 'Publish an effective Fee Plan for this offering before starting admission.';
  end if;

  select count(*)
  into open_seats
  from public.enrollments
  where batch_id = batch.id
    and status = 'ACTIVE';

  if open_seats >= least(
    batch.capacity,
    coalesce(
      (
        select (payload->>'max_students')::integer
        from public.business_rule_versions
        where domain = 'academics'
          and rule_key = 'batch_capacity_policy'
          and status = 'ACTIVE'
        order by version desc
        limit 1
      ),
      batch.capacity
    )
  ) then
    raise exception 'The selected batch is full. Choose another available batch.';
  end if;

  if exists (
    select 1
    from public.admission_cases a
    where a.origin = 'DIRECT_STAFF'
      and lower(a.identity_snapshot->>'student_name') = lower(student_name)
      and regexp_replace(a.identity_snapshot->>'mobile', '\\D', '', 'g') = mobile
      and a.status <> 'CANCELLED'
  ) then
    raise exception 'A matching direct admission draft already exists. Open Admissions and continue that case.';
  end if;

  insert into public.admission_cases (
    prospect_id,
    origin,
    origin_prospect_id,
    batch_id,
    fee_plan_version_id,
    existing_student,
    identity_snapshot,
    created_by
  )
  values (
    null,
    'DIRECT_STAFF',
    null,
    batch.id,
    fee.id,
    false,
    jsonb_build_object(
      'student_name', student_name,
      'student_name_bn', nullif(btrim(coalesce(p_input->>'student_name_bn','')), ''),
      'date_of_birth', birth_date,
      'gender', gender_value,
      'school_name', school_name,
      'school_roll', school_roll,
      'guardian_name', guardian_name,
      'guardian_relationship', guardian_relationship,
      'mobile', mobile,
      'alternate_mobile', alternate_mobile,
      'guardian_address', guardian_address,
      'intake_note', intake_note,
      'consent_to_contact', true
    ),
    actor
  )
  returning *
  into admission;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values (
    req,
    actor,
    (select s.id from public.staff s where s.profile_id = actor limit 1),
    'ADMISSION',
    admission.id::text,
    'CREATE_DIRECT_STAFF_ADMISSION',
    reason,
    null,
    to_jsonb(admission),
    jsonb_build_object(
      'origin', 'DIRECT_STAFF',
      'offering_id', offering.id,
      'batch_id', batch.id
    )
  );

  insert into public.staff_admission_intake_requests(
    request_id,
    actor_id,
    payload,
    prospect_id,
    admission_id
  )
  values (
    req,
    actor,
    p_input,
    null,
    admission.id
  );

  extras:=jsonb_build_object('father_name',left(p_input->>'father_name',160),'mother_name',left(p_input->>'mother_name',160),
 'birth_registration',left(p_input->>'birth_registration',40),'permanent_address',left(p_input->>'permanent_address',300),
 'emergency_contact',left(p_input->>'emergency_contact',160),'emergency_mobile',left(p_input->>'emergency_mobile',30),
 'previous_result',left(p_input->>'previous_result',200),'learning_needs',left(p_input->>'learning_needs',500));
 update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(extras)
 where id=admission.id;

  return jsonb_build_object(
    'admission_id', admission.id,
    'admission_no', admission.admission_no
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admission_directory_options()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null then raise exception 'Sign in required.'; end if;
 if not public.has_permission('admissions.view') then return jsonb_build_object('schools','[]'::jsonb,'relationships','[]'::jsonb); end if;
 return jsonb_build_object('schools',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.schools where is_active),'[]'::jsonb),
 'relationships',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.guardian_relationships where is_active),'[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.save_admission_extra_charge(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.admission_cases; req uuid:=(p_input->>'request_id')::uuid; k public.admission_command_keys;
 charge jsonb; result jsonb; amount numeric:=(p_input->>'amount')::numeric;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') or not public.has_permission('finance.billing.manage') then raise exception 'Admission and billing permissions required.'; end if;
 if req is null then raise exception 'Request identity required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if; return k.result; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Additional charges must be agreed before final submission.'; end if;
 if length(btrim(coalesce(p_input->>'name',''))) not between 2 and 100 or amount is null or amount<=0 or amount<>round(amount,2) or amount>99999999
 or coalesce(p_input->>'charge_type','') not in('ADMISSION','EXAM','MATERIAL','OTHER') then raise exception 'Enter a valid one-time fee and amount.'; end if;
 if jsonb_array_length(a.additional_charges)>=10 then raise exception 'No more than ten additional charges per admission.'; end if;
 charge:=jsonb_build_object('id',req,'name',btrim(p_input->>'name'),'charge_type',p_input->>'charge_type','amount',amount,'is_active',true);
 update public.admission_cases set additional_charges=additional_charges||jsonb_build_array(charge) where id=a.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'ADMISSION',a.id::text,'ADD_ONE_TIME_CHARGE','One-time charge agreed with guardian before final submission',a.additional_charges,charge);
 result:=jsonb_build_object('id',a.id);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,auth.uid(),p_input,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.deactivate_admission_extra_charge(p_admission_id uuid, p_charge_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.admission_cases; charges jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') or not public.has_permission('finance.billing.manage') then raise exception 'Admission and billing permissions required.'; end if;
 select * into a from public.admission_cases where id=p_admission_id for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Posted charges require a recorded financial correction.'; end if;
 select coalesce(jsonb_agg(case when value->>'id'=p_charge_id::text then value||'{"is_active":false}'::jsonb else value end order by ord),'[]') into charges from jsonb_array_elements(a.additional_charges) with ordinality items(value,ord);
 update public.admission_cases set additional_charges=charges where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'DEACTIVATE_DRAFT_CHARGE','Corrected draft charges before submission',a.additional_charges,charges);
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
    'className', cl.name,
    'yearName', ay.name,
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
        'number', i.invoice_no,
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
  join public.classes cl
    on cl.id = b.class_id
  join public.academic_years ay
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
 jsonb_build_object('father_name',a.identity_snapshot->>'father_name','mother_name',a.identity_snapshot->>'mother_name',
 'birth_registration',a.identity_snapshot->>'birth_registration','permanent_address',a.identity_snapshot->>'permanent_address',
 'emergency_contact',a.identity_snapshot->>'emergency_contact','emergency_mobile',a.identity_snapshot->>'emergency_mobile',
 'previous_result',a.identity_snapshot->>'previous_result','learning_needs',a.identity_snapshot->>'learning_needs'))
 from public.admission_cases a left join public.students s on s.id=a.student_id where a.id=p_admission_id);

 select additional_charges into charges from public.admission_cases where id=p_admission_id;
 select coalesce(jsonb_agg(jsonb_build_object('name',value->>'name','amount',(value->>'amount')::numeric,'recurrence','ONE_TIME')),'[]') into extras from jsonb_array_elements(charges) where (value->>'is_active')::boolean;
 return result||jsonb_build_object('tuitionTotal',(select coalesce(sum(c.amount),0) from public.fee_plan_components c join public.admission_cases a on a.fee_plan_version_id=c.fee_plan_version_id where a.id=p_admission_id and c.charge_type='TUITION'),'additionalCharges',charges,'components',(result->'components')||extras);
end;
$function$;

CREATE OR REPLACE FUNCTION public.correct_admission_placement(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.admission_cases; b public.batches; f public.fee_plan_versions; today date;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Correction reason required.'; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Only an unconfirmed draft can change placement. Use enrollment transfer after admission.'; end if;
 select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
 if b.id is null or b.offering_id is distinct from (p_input->>'offering_id')::uuid or not exists(select 1 from public.programme_offerings where id=b.offering_id and status='ACTIVE') then raise exception 'Choose an active offering and its batch.'; end if;
 if b.organization_id is distinct from (select organization_id from public.batches where id=a.batch_id) then raise exception 'Placement must remain in the same academy.'; end if;
 if (select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE')>=b.capacity then raise exception 'Selected batch is full.'; end if;
 select timezone(timezone,now())::date into today from public.organizations where id=b.organization_id;
 select * into f from public.fee_plan_versions where offering_id=b.offering_id and status='ACTIVE' and effective_from<=today order by effective_from desc,version desc limit 1;
 if f.id is null then raise exception 'Save an effective Fee Plan for this offering first.'; end if;
 if a.batch_id=b.id and a.fee_plan_version_id=f.id then return jsonb_build_object('id',a.id); end if;
 update public.admission_cases set batch_id=b.id,fee_plan_version_id=f.id,status='DRAFT',identity_revision=identity_revision+1,
 selected_discount_percent=0,discount_reason=null,
 additional_charges=coalesce((select jsonb_agg(x||jsonb_build_object('is_active',false)) from jsonb_array_elements(a.additional_charges) x),'[]'::jsonb)
 where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'CORRECT_PLACEMENT',p_input->>'reason',to_jsonb(a),jsonb_build_object('batch_id',b.id,'fee_plan_id',f.id));
 return jsonb_build_object('id',a.id);
end $function$;

CREATE OR REPLACE FUNCTION public.admission_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
<<command>>
declare previous_trace text:=current_setting('sohoj.workflow_trace',true); a public.admission_cases; o public.programme_offerings; req uuid:=nullif(p_input->>'request_id','')::uuid;
 k public.admission_command_keys; result jsonb; pct integer; today date; end_date date;
begin
 if nullif(previous_trace,'') is null then perform set_config('sohoj.workflow_trace',coalesce(p_input->>'request_id',gen_random_uuid()::text),true); end if;
 if p_input->>'action' in('CREATE','READY','ACCEPT','BILL','FINALIZE') and not exists(select 1 from public.organizations where code='SOHOJ' and is_active and setup_completed_at is not null) then raise exception 'Complete academy setup before processing admissions.'; end if;
 if p_input->>'action' in('ACCEPT','BILL') and not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
 if p_input->>'action'='ACCEPT' and not (public.admission_review_checks((p_input->>'admission_id')::uuid)->>'hasConsent')::boolean then raise exception 'Receive signed consent for the current details.'; end if;
 if p_input->>'action' not in('SAVE_DISCOUNT','FINALIZE','RETURN_TO_DRAFT') then
  result:=public.execute_admission_stage(p_input);
  perform set_config('sohoj.workflow_trace',coalesce(previous_trace,''),true);
  return result;
 end if;
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'A request identity and note are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if;
  return k.result;
 end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Only an unsubmitted draft can be changed or finalized.'; end if;
 select off.* into o from public.batches b join public.programme_offerings off on off.id=b.offering_id where b.id=a.batch_id for share of off;
 if p_input->>'action'='SAVE_DISCOUNT' then
  if not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
  pct:=coalesce((p_input->>'discount_percent')::integer,0);
  if pct<>0 and not pct=any(o.allowed_discount_percentages) then raise exception 'This discount is not allowed for the offering.'; end if;
  if pct<>0 and coalesce(p_input->>'discount_reason','') not in('FINANCIAL_HARDSHIP','SIBLING','MERIT','LAUNCH_OFFER','STAFF_FAMILY','OTHER') then raise exception 'Select a discount reason.'; end if;
  update public.admission_cases set selected_discount_percent=pct,
   discount_reason=case when pct=0 then null else p_input->>'discount_reason' end where id=a.id;
 elsif p_input->>'action'='RETURN_TO_DRAFT' then
  update public.admission_cases set status='DRAFT' where id=a.id;
 else
  if a.status<>'READY' then raise exception 'Review and verify the draft before final submission.'; end if;
  if not public.has_permission('finance.billing.manage') then raise exception 'Admission final submission requires billing permission.'; end if;
  if a.selected_discount_percent<>0 and not a.selected_discount_percent=any(o.allowed_discount_percentages) then raise exception 'The discount policy changed. Review the chosen discount.'; end if;
  if not exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=a.id and r.identity_revision=a.identity_revision) then raise exception 'Record signed paper consent for the current details before final submission.'; end if;
  -- Accept and invoice atomically. Failure rolls back student issuance as well.
  result:=public.execute_admission_stage(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
   'admission_id',a.id,'reason',p_input->>'reason'));
  if a.selected_discount_percent>0 then
   select timezone(org.timezone,now())::date into today from public.organizations org where org.id=o.organization_id;
   select greatest(ends_on,today) into end_date from public.academic_years where id=o.academic_year_id;
   perform public.finance_command(jsonb_build_object('action','APPLY_DISCOUNT','request_id',gen_random_uuid(),
    'admission_id',a.id,'kind','PERCENT','value',a.selected_discount_percent,
    'starts_on',date_trunc('month',today)::date,'ends_on',end_date,
    'reason','Admission discount: '||a.discount_reason));
  end if;
  result:=public.execute_admission_stage(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),
   'admission_id',a.id,'reason','Initial invoice posted with final admission submission'));
 end if;
 select jsonb_build_object('id',id,'status',status) into result from public.admission_cases where id=a.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'ADMISSION',a.id::text,p_input->>'action',p_input->>'reason',to_jsonb(a),result);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,auth.uid(),p_input,result);
 perform set_config('sohoj.workflow_trace',coalesce(previous_trace,''),true);
 return result;
end
$function$;

CREATE OR REPLACE FUNCTION public.close_student_enrollment(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e public.enrollments; today date; mode text:=p_input->>'mode'; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('students.manage') then raise exception 'Student management permission required.'; end if;
 if mode not in('WITHDRAWN','COMPLETED') or mode is null or length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Choose withdrawal or completion and record the reason.'; end if;
 -- Match admission command lock order to keep financial and enrollment mutations consistent.
 perform 1 from public.admission_cases where enrollment_id=(p_input->>'enrollment_id')::uuid for update;
 select * into e from public.enrollments where id=(p_input->>'enrollment_id')::uuid and student_id=(p_input->>'student_id')::uuid for update;
 if e.id is null then raise exception 'Enrollment not found for this student.'; end if;
 if e.status<>'ACTIVE' then return jsonb_build_object('id',e.id,'message','Enrollment is already closed.'); end if;
 select timezone(timezone,now())::date into today from public.organizations where id=e.organization_id;
 if today<e.admission_date then raise exception 'Enrollment start is in the future. Cancel the admission instead.'; end if;
 before_data:=to_jsonb(e);
 update public.enrollments set status=mode::public.enrollment_status,ended_on=today where id=e.id;
 update public.admission_cases set status='CLOSED_ENROLLMENT' where enrollment_id=e.id and status='ACTIVE_ENROLLMENT';
 if not exists(select 1 from public.enrollments where student_id=e.student_id and status='ACTIVE') then update public.students set status='INACTIVE' where id=e.student_id; end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ENROLLMENT',e.id::text,mode,p_input->>'reason',before_data,jsonb_build_object('status',mode,'ended_on',today,'student_id',e.student_id));
 return jsonb_build_object('id',e.id,'message','Enrollment closed. Future recurring billing stops; existing invoices, payments and due balances remain.');
end $function$;

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
 update public.prospects set current_class_id=o.class_id,interested_offering_id=o.id,
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
     or (v_prospect.current_class_id is not null and v_prospect.current_class_id is distinct from v_offering.class_id)
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
