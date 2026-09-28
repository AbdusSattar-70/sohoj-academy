-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 02
-- Generated from the reviewed V2 schema history for a CLEAN database.
-- No data migration is included. Apply after baseline part 01.

-- ============================================================
-- SOURCE: 0014_v2_finance_workflows.sql
-- ============================================================

create or replace function public.billing_preview(p_period date,p_term_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $$
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
end; $$;
revoke all on function public.billing_preview(date,uuid) from public,anon;
grant execute on function public.billing_preview(date,uuid) to authenticated;

create or replace function public.finance_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid(); action text:=p_input->>'action'; req uuid:=(p_input->>'request_id')::uuid;
 reason text:=btrim(coalesce(p_input->>'reason','')); key public.admission_command_keys;
 a public.admission_cases; approval public.approval_requests; i public.admission_invoices; discount public.admission_discounts;
 payment public.admission_payments; refund_auth public.refund_authorizations;
 balance record; amount numeric; reserved numeric; aid uuid; approved_id uuid; payout public.refund_payouts;
 start_date date; end_date date; kind text; value numeric; preview jsonb; row jsonb; invoice_id uuid; gross numeric:=0; count_invoices integer:=0;
 result jsonb; permission text; today date; year public.academic_years; term public.billing_terms;
begin
 if actor is null then raise exception 'Sign in to continue.'; end if;
 if req is null or length(reason)<5 then raise exception 'A request identity and reason are required.'; end if;
 permission:=case action when 'REQUEST_DISCOUNT' then 'finance.billing.manage' when 'REQUEST_CANCEL' then 'admissions.create'
 when 'REQUEST_REFUND' then 'finance.payments.post' when 'POST_REFUND' then 'finance.payments.post'
 when 'RUN_BILLING' then 'finance.billing.manage' when 'CREATE_TERM' then 'finance.billing.manage' else null end;
 if action<>'DECIDE' and (permission is null or not public.has_permission(permission)) then raise exception 'Permission denied for this finance action.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
  return key.result;
 end if;
 if action='CREATE_TERM' then
  select * into year from public.academic_years where id=(p_input->>'academic_year_id')::uuid for update;
  start_date:=(p_input->>'starts_on')::date; end_date:=(p_input->>'ends_on')::date;
  if year.id is null or start_date is null or end_date is null or start_date<year.starts_on or end_date>year.ends_on or end_date<start_date
   or length(btrim(coalesce(p_input->>'name','')))<2 or (p_input->>'due_on')::date is null then raise exception 'Enter a valid term inside the academic year.'; end if;
  if exists(select 1 from public.billing_terms t where t.academic_year_id=year.id and daterange(t.starts_on,t.ends_on,'[]')&&daterange(start_date,end_date,'[]')) then raise exception 'Term overlaps an existing term.'; end if;
  insert into public.billing_terms(academic_year_id,name,starts_on,ends_on,due_on,created_by)
  values(year.id,btrim(p_input->>'name'),start_date,end_date,(p_input->>'due_on')::date,actor) returning * into term;
  result:=jsonb_build_object('id',term.id,'message','Term created.');
 elsif action='RUN_BILLING' then
  -- Serialize all relevant case changes before comparing the user's reviewed preview.
  perform 1 from public.admission_cases where status='ACTIVE_ENROLLMENT' order by id for update;
  preview:=public.billing_preview((p_input->>'period')::date,nullif(p_input->>'term_id','')::uuid);
  if preview->>'token' is distinct from p_input->>'preview_token' then raise exception 'Billing preview changed. Refresh and review it before posting.'; end if;
  if jsonb_array_length(preview->'rows')=0 then raise exception 'No unbilled eligible enrollments for this period.'; end if;
  for row in select x from jsonb_array_elements(preview->'rows') x loop
   select * into a from public.admission_cases where id=(row->>'admissionId')::uuid;
   select (now() at time zone o.timezone)::date into today from public.batches b join public.organizations o on o.id=b.organization_id where b.id=a.batch_id;
   insert into public.admission_invoices(admission_id,student_id,fee_plan_version_id,currency_code,total,issued_on,due_on,posted_by,invoice_kind,billing_period)
   select a.id,a.student_id,a.fee_plan_version_id,f.currency_code,(row->>'gross')::numeric,today,(row->>'dueOn')::date,actor,'RECURRING',(preview->>'period')::date from public.fee_plan_versions f where f.id=a.fee_plan_version_id returning id into invoice_id;
   insert into public.admission_invoice_lines(invoice_id,fee_component_id,name,charge_type,amount)
   select invoice_id,fc.id,fc.name,fc.charge_type,fc.amount from public.fee_plan_components fc where fc.fee_plan_version_id=a.fee_plan_version_id and fc.recurrence='PER_CYCLE';
   perform public.apply_invoice_discounts(invoice_id);
   gross:=gross+(row->>'gross')::numeric; count_invoices:=count_invoices+1;
  end loop;
  insert into public.billing_runs(id,period,term_id,posted_by,invoice_count,gross_total,reason)
  values(req,(preview->>'period')::date,nullif(preview->>'termId','')::uuid,actor,count_invoices,gross,reason);
  result:=jsonb_build_object('id',req,'message',count_invoices||' recurring invoices posted.');
 else
  if action='DECIDE' then
   select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid;
   if approval.workflow_type not in ('FINANCE_DISCOUNT','ADMISSION_CANCEL','FINANCE_REFUND') or approval.id is null then raise exception 'Supported approval request not found.'; end if;
   aid:=approval.entity_id::uuid;
   permission:=case approval.workflow_type when 'FINANCE_DISCOUNT' then 'finance.discounts.approve' when 'ADMISSION_CANCEL' then 'admissions.approve' else 'finance.payments.reverse' end;
   if not public.has_permission(permission) then raise exception 'Approval permission required.'; end if;
  elsif action='POST_REFUND' then
   select * into refund_auth from public.refund_authorizations where id=(p_input->>'authorization_id')::uuid;
   select admission_id into aid from public.admission_invoices where id=refund_auth.invoice_id;
  elsif action='REQUEST_REFUND' then
   select * into payment from public.admission_payments where id=(p_input->>'payment_id')::uuid;
   select inv.* into i from public.admission_invoices inv join public.admission_payment_allocations pa on pa.invoice_id=inv.id where pa.payment_id=payment.id;
   aid:=i.admission_id;
  else aid:=(p_input->>'admission_id')::uuid;
  end if;
  select * into a from public.admission_cases where id=aid for update;
  if a.id is null then raise exception 'Admission not found.'; end if;
  select (now() at time zone o.timezone)::date into today from public.batches b join public.organizations o on o.id=b.organization_id where b.id=a.batch_id;
  if action in ('REQUEST_DISCOUNT','REQUEST_CANCEL','REQUEST_REFUND') then
   if action='REQUEST_DISCOUNT' then
    kind:=p_input->>'kind'; value:=(p_input->>'value')::numeric; start_date:=(p_input->>'starts_on')::date; end_date:=(p_input->>'ends_on')::date;
    if a.status='CANCELLED' or kind not in ('PERCENT','FIXED') or kind is null or value is null or value<=0 or value>9999999999.99 or value<>round(value,2) or (kind='PERCENT' and value>100)
      or start_date is null or end_date is null or end_date<start_date then raise exception 'Enter a valid discount and effective period.'; end if;
   elsif action='REQUEST_CANCEL' then
    if a.status='CANCELLED' or p_input->>'settlement' not in ('KEEP_CHARGES','CREDIT_ALL') or p_input->>'settlement' is null then raise exception 'Choose a cancellation settlement for an open admission.'; end if;
   else
    amount:=(p_input->>'amount')::numeric;
    select * into balance from public.invoice_balance(i.id);
    select coalesce(sum(r.amount),0) into reserved from public.refund_authorizations r where r.payment_id=payment.id;
    if amount is null or amount<=0 or amount<>round(amount,2) or amount>payment.amount-reserved or amount>balance.credit_balance-balance.reserved_refunds then
     raise exception 'Refund exceeds the unreserved invoice credit or remaining original payment. Approve a discount or cancellation credit first.';
    end if;
   end if;
   insert into public.approval_requests(correlation_id,workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by)
   values(req,case action when 'REQUEST_DISCOUNT' then 'FINANCE_DISCOUNT' when 'REQUEST_CANCEL' then 'ADMISSION_CANCEL' else 'FINANCE_REFUND' end,
    'ADMISSION',a.id::text,action,p_input,reason,actor) returning id into approved_id;
   result:=jsonb_build_object('id',approved_id,'message','Request submitted for independent approval.');
  elsif action='DECIDE' then
   select * into approval from public.approval_requests where id=approval.id for update;
   if approval.status<>'PENDING' then raise exception 'Request has already been decided.'; end if;
   if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide this request.'; end if;
   if p_input->>'decision' not in ('APPROVED','REJECTED') or p_input->>'decision' is null then raise exception 'Choose Approve or Reject.'; end if;
   if p_input->>'decision'='APPROVED' then
    if approval.workflow_type='FINANCE_DISCOUNT' then
     if a.status='CANCELLED' then raise exception 'Cannot discount a cancelled admission.'; end if;
     start_date:=(approval.payload_snapshot->>'starts_on')::date; end_date:=(approval.payload_snapshot->>'ends_on')::date;
     if exists(select 1 from public.admission_discounts d where d.admission_id=a.id and daterange(d.starts_on,d.ends_on,'[]')&&daterange(start_date,end_date,'[]')) then raise exception 'Discount overlaps an approved discount. Use a non-overlapping period.'; end if;
     insert into public.admission_discounts(admission_id,approval_id,kind,value,starts_on,ends_on)
     values(a.id,approval.id,approval.payload_snapshot->>'kind',(approval.payload_snapshot->>'value')::numeric,start_date,end_date) returning * into discount;
     for i in select * from public.admission_invoices where admission_id=a.id and billing_period between start_date and end_date loop perform public.apply_invoice_discounts(i.id); end loop;
    elsif approval.workflow_type='ADMISSION_CANCEL' then
     if a.status='CANCELLED' then raise exception 'Admission already cancelled.'; end if;
     insert into public.admission_cancellations(admission_id,approval_id,settlement) values(a.id,approval.id,approval.payload_snapshot->>'settlement');
     if approval.payload_snapshot->>'settlement'='CREDIT_ALL' then
      for i in select * from public.admission_invoices where admission_id=a.id loop
       select * into balance from public.invoice_balance(i.id);
       if balance.net>0 then insert into public.invoice_credits(invoice_id,approval_id,kind,amount) values(i.id,approval.id,'CANCELLATION',balance.net); end if;
      end loop;
     end if;
     update public.admission_cases set status='CANCELLED' where id=a.id;
     update public.enrollments set status='WITHDRAWN',ended_on=today where id=a.enrollment_id and status='ACTIVE';
     if a.student_id is not null and not exists(select 1 from public.enrollments where student_id=a.student_id and status='ACTIVE') then update public.students set status='INACTIVE' where id=a.student_id; end if;
    else
     select * into payment from public.admission_payments where id=(approval.payload_snapshot->>'payment_id')::uuid;
     select inv.* into i from public.admission_invoices inv join public.admission_payment_allocations pa on pa.invoice_id=inv.id where pa.payment_id=payment.id;
     amount:=(approval.payload_snapshot->>'amount')::numeric;
     select * into balance from public.invoice_balance(i.id);
     select coalesce(sum(r.amount),0) into reserved from public.refund_authorizations r where r.payment_id=payment.id;
     if amount>payment.amount-reserved or amount>balance.credit_balance-balance.reserved_refunds then raise exception 'Refund availability changed. Requested amount is no longer available.'; end if;
     insert into public.refund_authorizations(approval_id,payment_id,invoice_id,amount) values(approval.id,payment.id,i.id,amount);
    end if;
   end if;
   update public.approval_requests set status=(p_input->>'decision')::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
   result:=jsonb_build_object('id',approval.id,'message','Request '||lower(p_input->>'decision')||'.');
  elsif action='POST_REFUND' then
   if refund_auth.id is null or exists(select 1 from public.refund_payouts where authorization_id=refund_auth.id) then raise exception 'Refund authorization is missing or already paid.'; end if;
   if not exists(select 1 from public.payment_methods where id=(p_input->>'payment_method_id')::uuid and is_active) then raise exception 'Choose an active refund payment method.'; end if;
   select * into balance from public.invoice_balance(refund_auth.invoice_id);
   if refund_auth.amount>balance.credit_balance then raise exception 'The credit balance no longer supports this payout.'; end if;
   insert into public.refund_payouts(authorization_id,payment_method_id,external_reference,posted_by,reason)
   values(refund_auth.id,(p_input->>'payment_method_id')::uuid,nullif(btrim(p_input->>'external_reference'),''),actor,reason) returning * into payout;
   result:=jsonb_build_object('id',payout.id,'message','Actual refund posted: '||payout.refund_no);
  else raise exception 'Unsupported finance action.';
  end if;
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'FINANCE_WORKFLOW',result->>'id',action,reason,result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end; $$;
revoke all on function public.finance_command(jsonb) from public,anon;
grant execute on function public.finance_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0015_v2_admission_finance_integration.sql
-- ============================================================

-- Integrate credits, refunds and multiple invoices without rewriting posted history.
create or replace function public.admission_payment_satisfied(p_admission_id uuid)
returns boolean language sql security definer set search_path=public as $$
 select bal.paid-bal.refunded>=case
 when not (r.payload->>'allow_credit_enrollment')::boolean or r.payload->>'payment_requirement'='FULL' then bal.net
 when r.payload->>'payment_requirement'='MINIMUM_PERCENT' then round(bal.net*(r.payload->>'minimum_payment_percent')::numeric/100,2)
 else 0 end
 from public.admission_cases a join public.admission_invoices i on i.admission_id=a.id and i.invoice_kind='INITIAL'
 join public.business_rule_versions r on r.id=a.activation_policy_version_id
 cross join lateral public.invoice_balance(i.id) bal where a.id=p_admission_id;
$$;
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
   select * into v_batch from public.batches where id=v_case.batch_id and is_active for update;
   if v_batch.id is null then raise exception 'Batch is no longer active.'; end if;
   select * into v_fee from public.fee_plan_versions where id=v_case.fee_plan_version_id for share;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_batch.organization_id;
   if v_action='EDIT_DRAFT' and v_case.status in ('DRAFT','READY') then
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
     if v_prospect.status in ('CONVERTED','LOST') then raise exception 'Prospect is no longer eligible for admission.'; end if;
     if v_fee.status<>'ACTIVE' then raise exception 'Fee Plan changed. Refresh and review before acceptance.'; end if;
     select * into v_policy from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE';
     if v_policy.id is null or not public.validate_business_rule_payload('admissions','activation_policy',v_policy.payload) then raise exception 'A valid activation policy is required.'; end if;
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

create or replace function public.post_admission_payment(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
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
      'batchId',a.batch_id,'studentNo',s.student_no,'studentId',s.id,'name',a.identity_snapshot->>'student_name','guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',
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



-- ============================================================
-- SOURCE: 0016_v2_finance_workspace.sql
-- ============================================================

create or replace function public.finance_workspace()
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('finance.view') then raise exception 'Finance access denied.'; end if;
 return jsonb_build_object(
 'admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.identity_snapshot->>'student_name','number',a.admission_no,'status',a.status)) from public.admission_cases a),'[]'::jsonb),
 'years',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.academic_years),'[]'::jsonb),
 'terms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'startsOn',starts_on,'endsOn',ends_on,'dueOn',due_on)) from public.billing_terms),'[]'::jsonb),
 'invoices',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'admissionId',a.id,'name',a.identity_snapshot->>'student_name','number',i.invoice_no,'kind',i.invoice_kind,'period',i.billing_period,'dueOn',i.due_on,'currency',i.currency_code,'gross',b.gross,'credits',b.credits,'net',b.net,'paid',b.paid,'refunded',b.refunded,'due',b.due,'credit',b.credit_balance,'reserved',b.reserved_refunds,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('name',name,'amount',amount)) from public.admission_invoice_lines where invoice_id=i.id),'[]'::jsonb)) order by i.posted_at desc) from public.admission_invoices i join public.admission_cases a on a.id=i.admission_id cross join lateral public.invoice_balance(i.id) b),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'invoiceId',pa.invoice_id,'number',p.receipt_no,'amount',p.amount,'postedAt',p.posted_at,'method',pm.name,'remaining',p.amount-coalesce((select sum(amount) from public.refund_authorizations where payment_id=p.id),0))) from public.admission_payments p join public.admission_payment_allocations pa on pa.payment_id=p.id join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'approvals',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'admissionId',r.entity_id,'type',r.workflow_type,'status',r.status,'requesterId',r.requested_by,'requester',p.display_name,'reason',r.request_note,'decisionNote',r.decision_note,'payload',r.payload_snapshot,'createdAt',r.requested_at) order by r.requested_at desc) from public.approval_requests r join public.profiles p on p.id=r.requested_by where r.workflow_type in ('FINANCE_DISCOUNT','ADMISSION_CANCEL','FINANCE_REFUND')),'[]'::jsonb),
 'discounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'kind',kind,'value',value,'startsOn',starts_on,'endsOn',ends_on)) from public.admission_discounts),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'invoiceId',r.invoice_id,'paymentId',r.payment_id,'amount',r.amount,'number',p.refund_no,'postedAt',p.posted_at,'method',pm.name,'reference',p.external_reference)) from public.refund_authorizations r left join public.refund_payouts p on p.authorization_id=r.id left join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'runs',coalesce((select jsonb_agg(jsonb_build_object('id',id,'period',period,'count',invoice_count,'gross',gross_total,'postedAt',posted_at) order by posted_at desc) from public.billing_runs),'[]'::jsonb),
 'paymentMethods',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb)
 );
end; $$;
revoke all on function public.finance_workspace() from public,anon;
grant execute on function public.finance_workspace() to authenticated;



-- ============================================================
-- SOURCE: 0017_v2_student_lifecycle.sql
-- ============================================================

-- Permanent identities survive enrollment changes and controlled duplicate resolution.
alter table public.admission_cases drop constraint admission_cases_student_id_key;
alter table public.admission_cases alter column prospect_id drop not null;
alter table public.admission_cases add column existing_student boolean not null default false;
alter table public.admission_cases add constraint admission_identity_source check(prospect_id is not null or (existing_student and student_id is not null));
alter table public.students add column merged_into_id uuid references public.students(id);
alter table public.students add constraint no_self_merge check(merged_into_id is null or merged_into_id<>id);
create index students_merged_into on public.students(merged_into_id) where merged_into_id is not null;
create index admission_student_history on public.admission_cases(student_id,created_at);
create table public.student_merges (
 id uuid primary key default gen_random_uuid(), source_id uuid not null unique references public.students(id),
 target_id uuid not null references public.students(id), approval_id uuid not null unique references public.approval_requests(id),
 source_snapshot jsonb not null,target_snapshot jsonb not null,created_at timestamptz not null default now(),check(source_id<>target_id)
);
create table public.enrollment_transfers (
 id uuid primary key default gen_random_uuid(),student_id uuid not null references public.students(id),admission_id uuid not null references public.admission_cases(id),
 from_enrollment_id uuid not null unique references public.enrollments(id),to_enrollment_id uuid not null unique references public.enrollments(id),
 from_batch_id uuid not null references public.batches(id),to_batch_id uuid not null references public.batches(id),
 approval_id uuid not null unique references public.approval_requests(id),capacity_policy_version_id uuid not null references public.business_rule_versions(id),
 transferred_on date not null,created_at timestamptz not null default now()
);
insert into public.permissions(code,name,description) values('students.merge.approve','Approve student identity merges','Independently approve linking a duplicate identity to its canonical student.');
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code='ADMIN' and p.code='students.merge.approve';
revoke insert,update,delete on public.students,public.guardians,public.student_guardians from authenticated,anon;
do $$ declare t text; begin
 foreach t in array array['student_merges','enrollment_transfers'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
 execute format('create policy lifecycle_read on public.%I for select to authenticated using(public.has_permission(''students.view''))',t);
 execute format('create trigger lifecycle_immutable before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 end loop;
end; $$;

create or replace function public.student_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys;s public.students;target public.students;a public.admission_cases;b public.batches;dest public.batches;
 fee public.fee_plan_versions;guardian record;policy public.business_rule_versions;approval public.approval_requests;e public.enrollments;
 sid uuid:=(p_input->>'student_id')::uuid;tid uuid:=(p_input->>'target_id')::uuid;eid uuid;aid uuid;today date;result jsonb;snapshot jsonb;
begin
 if actor is null or not public.has_permission('students.view') then raise exception 'Student access required.';end if;
 if req is null or length(reason)<5 or length(reason)>500 then raise exception 'Request identity and a reason of 5–500 characters are required.';end if;
 if action='CREATE_EXISTING' then
  if not public.has_permission('admissions.create') then raise exception 'Admission creation permission required.';end if;
 elsif action in ('REQUEST_TRANSFER','REQUEST_MERGE') then
  if not public.has_permission('students.manage') then raise exception 'Student management permission required.';end if;
 elsif action is distinct from 'DECIDE' then raise exception 'Unsupported student action.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;
  return key.result;
 end if;
 if action='DECIDE' then
  select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid;
  if approval.id is null or approval.workflow_type not in ('STUDENT_TRANSFER','STUDENT_MERGE') then raise exception 'Student approval request not found.';end if;
  if not public.has_permission(case approval.workflow_type when 'STUDENT_MERGE' then 'students.merge.approve' else 'admissions.approve' end) then raise exception 'Independent approval permission required.';end if;
  sid:=(approval.payload_snapshot->>'student_id')::uuid;tid:=(approval.payload_snapshot->>'target_id')::uuid;
 end if;
 -- Case before student before batch: same ordering as admission transitions.
 if action='REQUEST_TRANSFER' or (action='DECIDE' and approval.workflow_type='STUDENT_TRANSFER') then
  aid:=case when action='DECIDE' then (approval.payload_snapshot->>'admission_id')::uuid else (p_input->>'admission_id')::uuid end;
  select * into a from public.admission_cases where id=aid for update;
  if a.id is null or a.student_id is distinct from sid then raise exception 'Admission does not belong to this student.';end if;
 end if;
 perform 1 from public.students where id in(sid,tid) order by id for update;
 select * into s from public.students where id=sid;
 if s.id is null then raise exception 'Student not found.';end if;
 select (now() at time zone timezone)::date into today from public.organizations where id=s.organization_id;
 if action='DECIDE' then
  select * into approval from public.approval_requests where id=approval.id for update;
  if approval.status<>'PENDING' then raise exception 'Request already decided.';end if;
  if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide this request.';end if;
  if p_input->>'decision' not in ('APPROVED','REJECTED') or p_input->>'decision' is null then raise exception 'Choose Approve or Reject.';end if;
 end if;
 if action='DECIDE' and p_input->>'decision'='REJECTED' then
  null; -- Reject even if the underlying record has changed since submission.
 else
  if s.merged_into_id is not null or s.status='ARCHIVED' then raise exception 'Use the canonical, non-archived Student identity.';end if;
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
  elsif action='REQUEST_TRANSFER' or (action='DECIDE' and approval.workflow_type='STUDENT_TRANSFER') then
   if a.status<>'ACTIVE_ENROLLMENT' then raise exception 'Only an active enrollment can transfer.';end if;
   select * into e from public.enrollments where id=a.enrollment_id and status='ACTIVE';
   if e.id is null then raise exception 'Active enrollment not found.';end if;
   if action='DECIDE' and (approval.payload_snapshot->>'enrollment_id')::uuid<>e.id then raise exception 'Enrollment changed. Submit a fresh transfer request.';end if;
   eid:=case when action='DECIDE' then (approval.payload_snapshot->>'batch_id')::uuid else (p_input->>'batch_id')::uuid end;
   perform 1 from public.batches where id in(a.batch_id,eid) order by id for update;
   select * into b from public.batches where id=a.batch_id;
   select * into dest from public.batches where id=eid and is_active;
   if dest.id is null or dest.id=b.id or dest.offering_id is distinct from b.offering_id or dest.organization_id<>b.organization_id then raise exception 'Transfer requires a different active batch in the same offering. Fee terms remain unchanged.';end if;
   select * into policy from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if policy.id is null then raise exception 'Capacity policy missing.';end if;
   if (select count(*) from public.enrollments where batch_id=dest.id and status='ACTIVE')>=least(dest.capacity,(policy.payload->>'max_students')::integer) then raise exception 'Destination batch is full under the current capacity policy.';end if;
   if action='REQUEST_TRANSFER' then
    snapshot:=p_input||jsonb_build_object('enrollment_id',e.id,'from_batch_id',b.id,'from_batch_name',b.name,'to_batch_name',dest.name,'student_name',s.full_name,'student_no',s.student_no);
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
    values('STUDENT_TRANSFER','STUDENT',s.id::text,action,snapshot,reason,actor,req) returning id into aid;
    result:=jsonb_build_object('id',aid,'message','Transfer submitted for independent approval. No seat is reserved yet.');
   else
    update public.enrollments set status='WITHDRAWN',ended_on=today where id=e.id;
    insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,admission_date,status,created_by)
    values(s.id,dest.organization_id,dest.branch_id,dest.academic_year_id,dest.class_id,dest.program_id,dest.id,today,'ACTIVE',actor) returning id into eid;
    insert into public.enrollment_transfers(student_id,admission_id,from_enrollment_id,to_enrollment_id,from_batch_id,to_batch_id,approval_id,capacity_policy_version_id,transferred_on)
    values(s.id,a.id,e.id,eid,b.id,dest.id,approval.id,policy.id,today);
    update public.admission_cases set batch_id=dest.id,enrollment_id=eid,capacity_policy_version_id=policy.id where id=a.id;
   end if;
  elsif action='REQUEST_MERGE' or (action='DECIDE' and approval.workflow_type='STUDENT_MERGE') then
   select * into target from public.students where id=tid;
   if target.id is null or target.id=s.id or target.organization_id<>s.organization_id or target.merged_into_id is not null or target.status='ARCHIVED' then raise exception 'Select a different canonical student in this organization.';end if;
   if exists(select 1 from public.students where merged_into_id=s.id) then raise exception 'A canonical identity with linked duplicates cannot be merged again.';end if;
   if exists(select 1 from public.enrollments where student_id=s.id and status='ACTIVE') or exists(select 1 from public.admission_cases where student_id=s.id and status<>'CANCELLED') then raise exception 'Resolve the duplicate identity’s open admissions and enrollments before merging.';end if;
   if lower(btrim(s.full_name))<>lower(btrim(target.full_name)) and not exists(
    select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians y join public.guardians gy on gy.id=y.guardian_id
    where x.student_id=s.id and y.student_id=target.id and gx.mobile=gy.mobile) then raise exception 'No matching name or guardian mobile. Verify the identities before requesting a merge.';end if;
   if action='REQUEST_MERGE' then
    if (p_input->>'confirmed_same_person') is distinct from 'true' then raise exception 'Explicitly verify these records belong to the same student.';end if;
    snapshot:=p_input||jsonb_build_object('source_snapshot',to_jsonb(s),'target_snapshot',to_jsonb(target));
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
    values('STUDENT_MERGE','STUDENT',s.id::text,action,snapshot,reason,actor,req) returning id into aid;
    result:=jsonb_build_object('id',aid,'message','Duplicate resolution submitted. An independent reviewer must verify both identities.');
   else
    if to_jsonb(s)<>approval.payload_snapshot->'source_snapshot' or to_jsonb(target)<>approval.payload_snapshot->'target_snapshot' then raise exception 'Student records changed. Submit a fresh duplicate review.';end if;
    insert into public.student_merges(source_id,target_id,approval_id,source_snapshot,target_snapshot) values(s.id,target.id,approval.id,to_jsonb(s),to_jsonb(target));
    update public.students set merged_into_id=target.id,status='ARCHIVED' where id=s.id;
    -- History and guardian links retain their original IDs and appear in the canonical profile.
   end if;
  end if;
 end if;
 if action='DECIDE' then
  update public.approval_requests set status=(p_input->>'decision')::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
  result:=jsonb_build_object('id',approval.id,'message','Request '||lower(p_input->>'decision')||'.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,'STUDENT',s.id::text,action,reason,to_jsonb(s),result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end; $$;
revoke all on function public.student_command(jsonb) from public,anon;
grant execute on function public.student_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0018_v2_existing_student_admission.sql
-- ============================================================

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



-- ============================================================
-- SOURCE: 0019_v2_student_profile_workspace.sql
-- ============================================================

create or replace function public.student_profile_workspace(p_student_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
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
 'transfers',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'fromBatch',b.name,'toBatch',d.name,'date',t.transferred_on,'approvalId',t.approval_id) order by t.created_at desc) from public.enrollment_transfers t join public.batches b on b.id=t.from_batch_id join public.batches d on d.id=t.to_batch_id where t.student_id=any(ids)),'[]'::jsonb),
 'candidates',case when public.has_permission('students.manage') then coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.full_name,'number',t.student_no,'status',t.status,'birthDate',t.date_of_birth,'school',t.school_name_snapshot,'mobile',(select g.mobile from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=t.id and sg.is_primary))) from public.students t where t.id<>s.id and t.organization_id=s.organization_id and t.merged_into_id is null and t.status<>'ARCHIVED' and (lower(btrim(t.full_name))=lower(btrim(s.full_name)) or exists(select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians z join public.guardians gz on gz.id=z.guardian_id where x.student_id=s.id and z.student_id=t.id and gx.mobile=gz.mobile))),'[]'::jsonb) else '[]'::jsonb end,
 'approvals',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'type',r.workflow_type,'status',r.status,'requesterId',r.requested_by,'requester',p.display_name,'reason',r.request_note,'decisionNote',r.decision_note,'createdAt',r.requested_at,'payload',r.payload_snapshot) order by r.requested_at desc) from public.approval_requests r join public.profiles p on p.id=r.requested_by where r.workflow_type in ('STUDENT_TRANSFER','STUDENT_MERGE') and (r.entity_id=any(ids::text[]) or r.payload_snapshot->>'target_id'=any(ids::text[]))),'[]'::jsonb)
 ) into result;
 return result;
end; $$;
revoke all on function public.student_profile_workspace(uuid) from public,anon;
grant execute on function public.student_profile_workspace(uuid) to authenticated;



-- ============================================================
-- SOURCE: 0020_v2_academic_operations.sql
-- ============================================================

-- Academic plans and scheduled occurrences are separate from attendance evidence.
create table public.academic_rooms (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),name text not null check(length(btrim(name))>=2),capacity integer not null check(capacity>0),created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),unique(branch_id,name)
);
create table public.curriculum_versions (
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),version integer not null,title text not null,units jsonb not null,reason text not null,published_by uuid not null references public.profiles(id),published_at timestamptz not null default now(),unique(batch_id,subject_id,version)
);
create table public.academic_routines (
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),teacher_id uuid not null references public.staff(id),room_id uuid not null references public.academic_rooms(id),weekday integer not null check(weekday between 0 and 6),start_time time not null,end_time time not null,starts_on date not null,ends_on date not null,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),retired_at timestamptz,check(end_time>start_time),check(ends_on>=starts_on)
);
create table public.class_sessions (
 id uuid primary key default gen_random_uuid(),routine_id uuid references public.academic_routines(id),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),teacher_id uuid not null references public.staff(id),room_id uuid not null references public.academic_rooms(id),curriculum_version_id uuid references public.curriculum_versions(id),planned_scope text not null,session_date date not null,starts_at timestamptz not null,ends_at timestamptz not null,status text not null default 'SCHEDULED' check(status in('SCHEDULED','CANCELLED')),cancellation_reason text,cancelled_by uuid references public.profiles(id),cancelled_at timestamptz,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),check(ends_at>starts_at),unique(routine_id,session_date)
);
create index sessions_schedule on public.class_sessions(starts_at,ends_at) where status='SCHEDULED';
create table public.attendance_submissions (
 id uuid primary key default gen_random_uuid(),session_id uuid not null references public.class_sessions(id),revision integer not null,entries jsonb not null,reason text not null,status text not null default 'DRAFT' check(status in('DRAFT','SUBMITTED','APPROVED','REJECTED')),recorded_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),approval_id uuid unique references public.approval_requests(id),unique(session_id,revision)
);
create unique index one_pending_attendance on public.attendance_submissions(session_id) where status='SUBMITTED';

create or replace function public.can_access_class_session(p_session uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and public.has_permission('academics.view') and exists(select 1 from public.class_sessions cs join public.staff st on st.id=cs.teacher_id where cs.id=p_session and (public.has_permission('academics.sessions.manage') or public.has_permission('academics.attendance.approve') or st.profile_id=auth.uid()));
$$;
revoke all on function public.can_access_class_session(uuid) from public,anon;
grant execute on function public.can_access_class_session(uuid) to authenticated;

create or replace function public.academic_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
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
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 -- Serialize schedule conflict checks and attendance/session-state transitions.
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if action='CREATE_ROOM' then
  if not exists(select 1 from public.branches where id=(p_input->>'branch_id')::uuid and is_active) then raise exception 'Choose an active branch.';end if;
  insert into public.academic_rooms(branch_id,name,capacity,created_by) values((p_input->>'branch_id')::uuid,btrim(p_input->>'name'),(p_input->>'capacity')::integer,actor) returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Room created.');
 elsif action='PUBLISH_CURRICULUM' then
  select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active;
  select * into year from public.academic_years where id=b.academic_year_id;
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
  select * into room from public.academic_rooms where id=roomid;
  select * into teacher from public.staff where id=tid and status='ACTIVE';
  select * into year from public.academic_years where id=b.academic_year_id;
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
    if action='GENERATE_SESSIONS' and exists(select 1 from public.class_sessions where routine_id=r.id and session_date=day) then continue;end if;
    start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
    if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.starts_at<end_at and x.ends_at>start_at and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflict on %: teacher, batch or room is occupied. Nothing was posted.',day;end if;
    if exists(select 1 from public.academic_routines x where x.retired_at is null and x.id is distinct from r.id and x.weekday=extract(dow from day) and day between x.starts_on and x.ends_on and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflicts with a reserved routine on %.',day;end if;
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
end; $$;
revoke all on function public.academic_command(jsonb) from public,anon;
grant execute on function public.academic_command(jsonb) to authenticated;

-- Final records are immutable; state transitions retain the original payload.
create or replace function public.protect_academic_record()
returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='DELETE' then raise exception 'Academic history cannot be deleted.';end if;
 if tg_table_name='academic_routines' then
  if (to_jsonb(new)-'retired_at') is distinct from (to_jsonb(old)-'retired_at') or old.retired_at is not null or new.retired_at is null then raise exception 'Routine terms are immutable; retire and create a replacement.';end if;
 elsif tg_table_name='class_sessions' then
  if (to_jsonb(new)-array['status','cancellation_reason','cancelled_by','cancelled_at']) is distinct from (to_jsonb(old)-array['status','cancellation_reason','cancelled_by','cancelled_at']) or old.status<>'SCHEDULED' or new.status<>'CANCELLED' then raise exception 'Session schedule is immutable; cancel and create a replacement occurrence.';end if;
 else
  if (to_jsonb(new)-array['status','approval_id']) is distinct from (to_jsonb(old)-array['status','approval_id']) or not ((old.status='DRAFT' and new.status='SUBMITTED' and new.approval_id is not null) or(old.status='SUBMITTED' and new.status in('APPROVED','REJECTED') and new.approval_id=old.approval_id)) then raise exception 'Attendance evidence is immutable; create a new revision.';end if;
 end if;
 return new;
end; $$;
do $$ declare t text;begin
 foreach t in array array['academic_rooms','curriculum_versions','academic_routines','class_sessions','attendance_submissions'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
 if t in('academic_rooms','curriculum_versions') then
 execute format('create trigger academic_immutable before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 else execute format('create trigger academic_immutable before update or delete on public.%I for each row execute function public.protect_academic_record()',t);end if;
 end loop;
end; $$;
create policy academic_room_read on public.academic_rooms for select to authenticated using(public.has_permission('academics.view'));
create policy curriculum_read on public.curriculum_versions for select to authenticated using(public.has_permission('academics.curriculum.manage') or public.has_permission('academics.sessions.manage') or exists(select 1 from public.class_sessions s where s.curriculum_version_id=curriculum_versions.id and public.can_access_class_session(s.id)));
create policy routine_read on public.academic_routines for select to authenticated using(public.has_permission('academics.sessions.manage') or exists(select 1 from public.staff where id=academic_routines.teacher_id and profile_id=auth.uid()));
create policy session_read on public.class_sessions for select to authenticated using(public.can_access_class_session(id));
create policy attendance_read on public.attendance_submissions for select to authenticated using(public.can_access_class_session(session_id));



-- ============================================================
-- SOURCE: 0021_v2_academic_workspaces.sql
-- ============================================================

create or replace function public.academic_workspace(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare manager boolean:=public.has_permission('academics.sessions.manage');curriculum_manager boolean:=public.has_permission('academics.curriculum.manage');begin
 if auth.uid() is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'Choose a date range of at most 367 days.';end if;
 return jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where is_active),'[]'::jsonb),
 'batches',case when manager or curriculum_manager then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||y.name,'branchId',b.branch_id,'capacity',b.capacity)) from public.batches b join public.academic_years y on y.id=b.academic_year_id where b.is_active and b.offering_id is not null),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.subjects where is_active),'[]'::jsonb),
 'teachers',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id),'[]'::jsonb))) from public.staff s where s.status='ACTIVE' and exists(select 1 from public.staff_subject_assignments where staff_id=s.id)),'[]'::jsonb) else '[]'::jsonb end,
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'branchId',branch_id,'capacity',capacity)) from public.academic_rooms),'[]'::jsonb),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'batchId',v.batch_id,'subjectId',v.subject_id,'batch',b.name,'subject',s.name,'version',v.version,'title',v.title,'units',v.units) order by v.published_at desc) from public.curriculum_versions v join public.batches b on b.id=v.batch_id join public.subjects s on s.id=v.subject_id where manager or curriculum_manager or exists(select 1 from public.class_sessions x where x.curriculum_version_id=v.id and public.can_access_class_session(x.id))),'[]'::jsonb),
 'routines',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'batchId',r.batch_id,'subjectId',r.subject_id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'weekday',r.weekday,'startTime',r.start_time,'endTime',r.end_time,'startsOn',r.starts_on,'endsOn',r.ends_on,'retired',r.retired_at is not null)) from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where manager or t.profile_id=auth.uid()),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'date',x.session_date,'startTime',to_char(x.starts_at at time zone o.timezone,'HH24:MI'),'endTime',to_char(x.ends_at at time zone o.timezone,'HH24:MI'),'timezone',o.timezone,'status',x.status,'scope',x.planned_scope,'latestStatus',(select status from public.attendance_submissions where session_id=x.id order by revision desc limit 1),'approvedRevision',(select max(revision) from public.attendance_submissions where session_id=x.id and status='APPROVED')) order by x.starts_at) from public.class_sessions x join public.batches b on b.id=x.batch_id join public.organizations o on o.id=b.organization_id join public.subjects s on s.id=x.subject_id join public.staff t on t.id=x.teacher_id join public.academic_rooms rm on rm.id=x.room_id where x.session_date between p_from and p_to and public.can_access_class_session(x.id)),'[]'::jsonb)
 );
end; $$;
create or replace function public.class_session_workspace(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare cs public.class_sessions;latest public.attendance_submissions;roster jsonb;begin
 if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.';end if;
 select * into cs from public.class_sessions where id=p_session_id;
 select * into latest from public.attendance_submissions where session_id=cs.id order by revision desc limit 1;
 if latest.id is null then
  select coalesce(jsonb_agg(jsonb_build_object('enrollment_id',e.id,'student_id',s.id,'number',s.student_no,'name',s.full_name) order by s.student_no),'[]'::jsonb) into roster from public.enrollments e join public.students s on s.id=e.student_id where e.batch_id=cs.batch_id and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date) and e.status in('ACTIVE','WITHDRAWN','COMPLETED');
 else roster:=latest.entries;end if;
 return jsonb_build_object(
 'session',(select jsonb_build_object('id',cs.id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'teacherProfileId',t.profile_id,'room',r.name,'date',cs.session_date,'canRecordNow',cs.starts_at<=now(),'startsAt',cs.starts_at,'endsAt',cs.ends_at,'timezone',o.timezone,'status',cs.status,'scope',cs.planned_scope,'cancellationReason',cs.cancellation_reason,'curriculumTitle',v.title,'curriculumVersion',v.version,'units',coalesce(v.units,'[]'::jsonb)) from public.batches b join public.organizations o on o.id=b.organization_id cross join public.subjects s cross join public.staff t cross join public.academic_rooms r left join public.curriculum_versions v on v.id=cs.curriculum_version_id where b.id=cs.batch_id and s.id=cs.subject_id and t.id=cs.teacher_id and r.id=cs.room_id),
 'roster',roster,
 'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'revision',a.revision,'status',a.status,'entries',a.entries,'reason',a.reason,'recordedBy',a.recorded_by,'recorder',p.display_name,'createdAt',a.created_at,'approvalId',a.approval_id,'decisionNote',r.decision_note) order by a.revision desc) from public.attendance_submissions a join public.profiles p on p.id=a.recorded_by left join public.approval_requests r on r.id=a.approval_id where a.session_id=cs.id),'[]'::jsonb)
 );
end; $$;
revoke all on function public.academic_workspace(date,date),public.class_session_workspace(uuid) from public,anon;
grant execute on function public.academic_workspace(date,date),public.class_session_workspace(uuid) to authenticated;



-- ============================================================
-- SOURCE: 0023_v2_manage_crm_master_data.sql
-- ============================================================

-- Manage CRM: audited create/update for shared master data used by public forms and offerings.
-- Permission: system.master_data.manage. No hard deletes — deactivate only.

-- Allow manage policy on academic groups (select-only until now).
grant select, insert, update on public.academic_groups to authenticated;

drop policy if exists master_data_manage_academic_groups on public.academic_groups;
create policy master_data_manage_academic_groups
on public.academic_groups for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create or replace function public.manage_crm_master_record(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_entity text := lower(btrim(coalesce(p_input->>'entity', '')));
  v_reason text := btrim(coalesce(p_input->>'reason', ''));
  v_id uuid := nullif(p_input->>'id', '')::uuid;
  v_correlation uuid := gen_random_uuid();
  v_before jsonb;
  v_after jsonb;
  v_action text;
  v_code text;
  v_name text;
  v_is_active boolean;
  v_sort integer;
  v_starts date;
  v_ends date;
  v_description text;
  v_area_id uuid;
  v_verified boolean;
begin
  if v_actor is null or not public.has_permission('system.master_data.manage') then
    raise exception 'You are not authorized to manage CRM master data.';
  end if;
  if length(v_reason) < 5 then
    raise exception 'A change reason of at least five characters is required.';
  end if;

  select id into v_org from public.organizations where code = 'SOHOJ' and is_active limit 1;
  if v_org is null then
    raise exception 'Organization is not available.';
  end if;

  v_name := nullif(btrim(coalesce(p_input->>'name', '')), '');
  v_code := nullif(upper(btrim(coalesce(p_input->>'code', ''))), '');
  v_is_active := coalesce((p_input->>'is_active')::boolean, true);
  v_sort := coalesce((p_input->>'sort_order')::integer, 0);
  v_description := nullif(btrim(coalesce(p_input->>'description', '')), '');
  v_starts := nullif(p_input->>'starts_on', '')::date;
  v_ends := nullif(p_input->>'ends_on', '')::date;
  v_area_id := nullif(p_input->>'area_id', '')::uuid;
  v_verified := coalesce((p_input->>'is_verified')::boolean, false);

  if v_entity = 'academic_year' then
    if v_name is null or length(v_name) < 2 then
      raise exception 'Academic year name is required.';
    end if;
    if v_starts is null or v_ends is null or v_ends < v_starts then
      raise exception 'Academic year needs a valid start and end date.';
    end if;
    if v_id is null then
      insert into public.academic_years (organization_id, name, starts_on, ends_on, is_active)
      values (v_org, v_name, v_starts, v_ends, false)
      returning to_jsonb(academic_years.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(y.*) into v_before from public.academic_years y where y.id = v_id and y.organization_id = v_org for update;
      if v_before is null then raise exception 'Academic year not found.'; end if;
      if v_is_active then
        update public.academic_years set is_active = false
        where organization_id = v_org and id <> v_id and is_active;
      end if;
      update public.academic_years
      set name = v_name, starts_on = v_starts, ends_on = v_ends, is_active = v_is_active
      where id = v_id
      returning to_jsonb(academic_years.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'class' then
    if v_code is null or length(v_code) < 1 then raise exception 'Class code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Class name is required.'; end if;
    if v_id is null then
      insert into public.classes (organization_id, code, name, sort_order, is_active)
      values (v_org, v_code, v_name, v_sort, v_is_active)
      returning to_jsonb(classes.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(c.*) into v_before from public.classes c where c.id = v_id and c.organization_id = v_org for update;
      if v_before is null then raise exception 'Class not found.'; end if;
      update public.classes
      set code = v_code, name = v_name, sort_order = v_sort, is_active = v_is_active
      where id = v_id
      returning to_jsonb(classes.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'group' then
    if v_code is null or length(v_code) < 1 then raise exception 'Group code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Group name is required.'; end if;
    if v_id is null then
      insert into public.academic_groups (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(academic_groups.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(g.*) into v_before from public.academic_groups g where g.id = v_id and g.organization_id = v_org for update;
      if v_before is null then raise exception 'Group not found.'; end if;
      update public.academic_groups
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(academic_groups.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'subject' then
    if v_code is null or length(v_code) < 1 then raise exception 'Subject code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Subject name is required.'; end if;
    if v_id is null then
      insert into public.subjects (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(subjects.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(s.*) into v_before from public.subjects s where s.id = v_id and s.organization_id = v_org for update;
      if v_before is null then raise exception 'Subject not found.'; end if;
      update public.subjects
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(subjects.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'program' then
    if v_code is null or length(v_code) < 1 then raise exception 'Programme code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Programme name is required.'; end if;
    if v_id is null then
      insert into public.programs (organization_id, code, name, description, is_active)
      values (v_org, v_code, v_name, v_description, v_is_active)
      returning to_jsonb(programs.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(p.*) into v_before from public.programs p where p.id = v_id and p.organization_id = v_org for update;
      if v_before is null then raise exception 'Programme not found.'; end if;
      update public.programs
      set code = v_code, name = v_name, description = v_description, is_active = v_is_active
      where id = v_id
      returning to_jsonb(programs.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'school' then
    if v_name is null or length(v_name) < 2 then raise exception 'School name is required.'; end if;
    if v_area_id is not null and not exists (
      select 1 from public.areas a where a.id = v_area_id and a.organization_id = v_org
    ) then
      raise exception 'Selected area is not available.';
    end if;
    if v_id is null then
      insert into public.schools (organization_id, area_id, name, is_verified, is_active, created_by)
      values (v_org, v_area_id, v_name, v_verified, v_is_active, v_actor)
      returning to_jsonb(schools.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(s.*) into v_before from public.schools s where s.id = v_id and s.organization_id = v_org for update;
      if v_before is null then raise exception 'School not found.'; end if;
      update public.schools
      set area_id = v_area_id, name = v_name, is_verified = v_verified, is_active = v_is_active, updated_at = now()
      where id = v_id
      returning to_jsonb(schools.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'lead_source' then
    if v_code is null or length(v_code) < 1 then raise exception 'Lead source code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Lead source name is required.'; end if;
    if v_id is null then
      insert into public.lead_sources (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(lead_sources.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(l.*) into v_before from public.lead_sources l where l.id = v_id and l.organization_id = v_org for update;
      if v_before is null then raise exception 'Lead source not found.'; end if;
      update public.lead_sources
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(lead_sources.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'guardian_relationship' then
    if v_code is null or length(v_code) < 1 then raise exception 'Relationship code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Relationship name is required.'; end if;
    if v_id is null then
      insert into public.guardian_relationships (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(guardian_relationships.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(r.*) into v_before from public.guardian_relationships r where r.id = v_id and r.organization_id = v_org for update;
      if v_before is null then raise exception 'Relationship not found.'; end if;
      update public.guardian_relationships
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(guardian_relationships.*) into v_after;
      v_action := 'UPDATE';
    end if;

  else
    raise exception 'Unsupported master-data entity.';
  end if;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    null,
    upper(v_entity),
    v_id::text,
    v_action,
    v_reason,
    v_before,
    v_after,
    jsonb_build_object('source', 'manage_crm', 'entity', v_entity)
  );

  return jsonb_build_object(
    'id', v_id,
    'entity', v_entity,
    'action', v_action,
    'correlation_id', v_correlation
  );
exception
  when unique_violation then
    raise exception 'A record with the same code or name already exists.';
end;
$$;

revoke all on function public.manage_crm_master_record(jsonb) from public, anon;
grant execute on function public.manage_crm_master_record(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0024_v2_offering_public_controls.sql
-- ============================================================

-- Programme offering public controls: showcase copy, website visibility,
-- accepting applications (independent of operational ACTIVE status).

alter table public.programme_offerings
  add column if not exists showcase_title text,
  add column if not exists showcase_title_bn text,
  add column if not exists showcase_description text,
  add column if not exists showcase_description_bn text,
  add column if not exists showcase_eyebrow text,
  add column if not exists showcase_eyebrow_bn text,
  add column if not exists showcase_icon text,
  add column if not exists showcase_sort_order integer not null default 100,
  add column if not exists is_website_visible boolean not null default false,
  add column if not exists is_accepting_applications boolean not null default false,
  add column if not exists applications_open_on date,
  add column if not exists applications_close_on date;

comment on column public.programme_offerings.is_website_visible is
  'When true and status=ACTIVE, offering may appear on the public homepage.';
comment on column public.programme_offerings.is_accepting_applications is
  'When true, public interest/admission forms may select this offering. Independent of operational status.';
comment on column public.programme_offerings.showcase_sort_order is
  'Lower numbers appear first on the public homepage.';

create index if not exists programme_offerings_website_visible_idx
  on public.programme_offerings (showcase_sort_order, created_at)
  where is_website_visible = true and status = 'ACTIVE';

create table if not exists public.programme_offering_subjects (
  offering_id uuid not null references public.programme_offerings(id) on delete cascade,
  subject_id uuid not null references public.subjects(id),
  sort_order integer not null default 0,
  primary key (offering_id, subject_id)
);

alter table public.programme_offering_subjects enable row level security;

grant select on public.programme_offering_subjects to authenticated, anon;
revoke insert, update, delete on public.programme_offering_subjects from authenticated, anon;

drop policy if exists offering_subjects_read on public.programme_offering_subjects;
create policy offering_subjects_read on public.programme_offering_subjects
for select to authenticated, anon
using (
  exists (
    select 1 from public.programme_offerings o
    where o.id = offering_id
      and (
        o.is_website_visible
        or public.has_permission('academics.view')
        or public.has_permission('admissions.view')
      )
  )
);

create or replace function public.update_programme_offering_public_controls(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_correlation uuid := gen_random_uuid();
  v_offering_id uuid;
  v_reason text;
  v_row public.programme_offerings%rowtype;
  v_before jsonb;
  v_title text;
  v_title_bn text;
  v_desc text;
  v_desc_bn text;
  v_eyebrow text;
  v_eyebrow_bn text;
  v_icon text;
  v_sort integer;
  v_visible boolean;
  v_accepting boolean;
  v_open date;
  v_close date;
  v_subjects jsonb;
  v_subject_id uuid;
  v_idx integer := 0;
begin
  if v_actor is null then
    raise exception 'Authentication required.';
  end if;
  if not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to curate programme public controls.';
  end if;

  v_offering_id := nullif(p_input->>'offering_id', '')::uuid;
  v_reason := nullif(trim(coalesce(p_input->>'reason', '')), '');
  v_title := nullif(trim(coalesce(p_input->>'showcase_title', '')), '');
  v_title_bn := nullif(trim(coalesce(p_input->>'showcase_title_bn', '')), '');
  v_desc := nullif(trim(coalesce(p_input->>'showcase_description', '')), '');
  v_desc_bn := nullif(trim(coalesce(p_input->>'showcase_description_bn', '')), '');
  v_eyebrow := nullif(trim(coalesce(p_input->>'showcase_eyebrow', '')), '');
  v_eyebrow_bn := nullif(trim(coalesce(p_input->>'showcase_eyebrow_bn', '')), '');
  v_icon := nullif(trim(coalesce(p_input->>'showcase_icon', '')), '');
  v_sort := coalesce((p_input->>'showcase_sort_order')::integer, 100);
  v_visible := coalesce((p_input->>'is_website_visible')::boolean, false);
  v_accepting := coalesce((p_input->>'is_accepting_applications')::boolean, false);
  v_open := nullif(p_input->>'applications_open_on', '')::date;
  v_close := nullif(p_input->>'applications_close_on', '')::date;
  v_subjects := coalesce(p_input->'subject_ids', '[]'::jsonb);

  if v_offering_id is null then
    raise exception 'Offering is required.';
  end if;
  if v_reason is null or length(v_reason) < 5 then
    raise exception 'A short reason (at least 5 characters) is required for the audit trail.';
  end if;
  if v_sort < 0 or v_sort > 9999 then
    raise exception 'Sort order must be between 0 and 9999.';
  end if;
  if v_icon is not null and v_icon not in (
    'clipboard-check', 'graduation-cap', 'users-round',
    'book-open-check', 'line-chart', 'shield-check'
  ) then
    raise exception 'Unsupported showcase icon.';
  end if;
  if v_open is not null and v_close is not null and v_close < v_open then
    raise exception 'Applications close date must be on or after the open date.';
  end if;

  select * into v_row from public.programme_offerings where id = v_offering_id for update;
  if not found then
    raise exception 'Programme offering not found.';
  end if;

  if v_visible and v_row.status <> 'ACTIVE' then
    raise exception 'Only ACTIVE offerings (with a published Fee Plan) can be shown on the website.';
  end if;
  if v_visible and v_title is null then
    raise exception 'Showcase title (English) is required when website visibility is enabled.';
  end if;
  if v_visible and v_desc is null then
    raise exception 'Showcase description (English) is required when website visibility is enabled.';
  end if;
  if v_accepting and v_row.status = 'RETIRED' then
    raise exception 'Retired offerings cannot accept new applications.';
  end if;

  v_before := to_jsonb(v_row);

  update public.programme_offerings set
    showcase_title = v_title,
    showcase_title_bn = v_title_bn,
    showcase_description = v_desc,
    showcase_description_bn = v_desc_bn,
    showcase_eyebrow = v_eyebrow,
    showcase_eyebrow_bn = v_eyebrow_bn,
    showcase_icon = v_icon,
    showcase_sort_order = v_sort,
    is_website_visible = v_visible,
    is_accepting_applications = v_accepting,
    applications_open_on = v_open,
    applications_close_on = v_close,
    updated_at = now()
  where id = v_offering_id
  returning * into v_row;

  delete from public.programme_offering_subjects where offering_id = v_offering_id;
  if jsonb_typeof(v_subjects) = 'array' then
    for v_idx in 0 .. greatest(jsonb_array_length(v_subjects) - 1, -1) loop
      v_subject_id := nullif(v_subjects->>v_idx, '')::uuid;
      if v_subject_id is null then
        continue;
      end if;
      if not exists (
        select 1 from public.subjects s
        where s.id = v_subject_id and s.is_active
      ) then
        raise exception 'One selected subject is not available.';
      end if;
      insert into public.programme_offering_subjects (offering_id, subject_id, sort_order)
      values (v_offering_id, v_subject_id, v_idx);
    end loop;
  end if;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_row.branch_id,
    'PROGRAMME_OFFERING',
    v_row.id::text,
    'UPDATE_PUBLIC_CONTROLS',
    v_reason,
    v_before,
    to_jsonb(v_row),
    jsonb_build_object(
      'is_website_visible', v_visible,
      'is_accepting_applications', v_accepting,
      'showcase_sort_order', v_sort,
      'subject_count', coalesce(jsonb_array_length(v_subjects), 0)
    )
  );

  return jsonb_build_object(
    'offering_id', v_row.id,
    'is_website_visible', v_row.is_website_visible,
    'is_accepting_applications', v_row.is_accepting_applications,
    'correlation_id', v_correlation
  );
end;
$$;

create or replace function public.list_public_programme_offerings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select
      o.id,
      o.code,
      o.name,
      o.showcase_title,
      o.showcase_title_bn,
      o.showcase_description,
      o.showcase_description_bn,
      o.showcase_eyebrow,
      o.showcase_eyebrow_bn,
      o.showcase_icon,
      o.showcase_sort_order,
      o.is_accepting_applications,
      o.applications_open_on,
      o.applications_close_on,
      o.created_at,
      (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', s.id,
          'code', s.code,
          'name', s.name
        ) order by pos.sort_order), '[]'::jsonb)
        from public.programme_offering_subjects pos
        join public.subjects s on s.id = pos.subject_id
        where pos.offering_id = o.id
      ) as subjects,
      (
        select jsonb_build_object(
          'billing_cycle', fp.billing_cycle,
          'currency_code', fp.currency_code,
          'components', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', c.code,
              'name', c.name,
              'amount', c.amount,
              'charge_type', c.charge_type,
              'recurrence', c.recurrence
            ) order by c.sort_order)
            from public.fee_plan_components c
            where c.fee_plan_version_id = fp.id
          ), '[]'::jsonb)
        )
        from public.fee_plan_versions fp
        where fp.offering_id = o.id and fp.status = 'ACTIVE'
        limit 1
      ) as fee_plan
    from public.programme_offerings o
    where o.is_website_visible = true
      and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at
    limit 24
  ) x;
$$;

revoke all on function public.update_programme_offering_public_controls(jsonb) from public, anon;
grant execute on function public.update_programme_offering_public_controls(jsonb) to authenticated;

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;



-- ============================================================
-- SOURCE: 0025_v2_public_interest_open_offerings.sql
-- ============================================================

-- Public interest/admission constrained to open programme offerings.
-- Adds offering + intent on prospects and hard validation in submit_public_interest.

alter table public.prospects
  add column if not exists interested_offering_id uuid references public.programme_offerings(id),
  add column if not exists submission_intent text not null default 'interest'
    check (submission_intent in ('interest', 'admission'));

create index if not exists prospects_interested_offering_idx
  on public.prospects(interested_offering_id)
  where interested_offering_id is not null;

comment on column public.prospects.interested_offering_id is
  'Optional programme offering selected on the public interest/admission form.';
comment on column public.prospects.submission_intent is
  'interest = short enquiry; admission = fuller application intent.';

-- Extend public listing with academic context used by forms.
create or replace function public.list_public_programme_offerings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select
      o.id,
      o.code,
      o.name,
      o.class_id,
      o.program_id,
      o.group_id,
      o.branch_id,
      o.academic_year_id,
      o.showcase_title,
      o.showcase_title_bn,
      o.showcase_description,
      o.showcase_description_bn,
      o.showcase_eyebrow,
      o.showcase_eyebrow_bn,
      o.showcase_icon,
      o.showcase_sort_order,
      o.is_accepting_applications,
      o.applications_open_on,
      o.applications_close_on,
      o.created_at,
      (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', s.id,
          'code', s.code,
          'name', s.name
        ) order by pos.sort_order), '[]'::jsonb)
        from public.programme_offering_subjects pos
        join public.subjects s on s.id = pos.subject_id
        where pos.offering_id = o.id
      ) as subjects,
      (
        select jsonb_build_object(
          'billing_cycle', fp.billing_cycle,
          'currency_code', fp.currency_code,
          'components', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', c.code,
              'name', c.name,
              'amount', c.amount,
              'charge_type', c.charge_type,
              'recurrence', c.recurrence
            ) order by c.sort_order)
            from public.fee_plan_components c
            where c.fee_plan_version_id = fp.id
          ), '[]'::jsonb)
        )
        from public.fee_plan_versions fp
        where fp.offering_id = o.id and fp.status = 'ACTIVE'
        limit 1
      ) as fee_plan
    from public.programme_offerings o
    where o.is_website_visible = true
      and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at
    limit 24
  ) x;
$$;

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;



-- ============================================================
-- SOURCE: 0026_v2_submit_public_interest_offering.sql
-- ============================================================

-- Completes open-offering validation inside submit_public_interest.
-- Replace submit RPC with offering validation while preserving existing behaviour.
create or replace function public.submit_public_interest(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org public.organizations;
  v_branch public.branches;
  v_prospect public.prospects;
  v_class public.classes;
  v_school public.schools;
  v_source public.lead_sources;
  v_relationship public.guardian_relationships;
  v_offering public.programme_offerings;
  v_program_id uuid;
  v_subject_id uuid;
  v_school_name text;
  v_relationship_text text;
  v_mobile text;
  v_correlation_id uuid := gen_random_uuid();
  v_offering_id uuid;
  v_intent text;
  v_today date := (timezone('utc', now()))::date;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Interest request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'student_name','')), '') is null then
    raise exception 'Student name is required.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'guardian_name','')), '') is null then
    raise exception 'Guardian name is required.';
  end if;

  v_mobile := nullif(btrim(coalesce(p_payload->>'mobile','')), '');

  if v_mobile is null or length(regexp_replace(v_mobile, '\D', '', 'g')) < 10 then
    raise exception 'A valid mobile number is required.';
  end if;

  if coalesce((p_payload->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Consent to contact is required.';
  end if;

  v_intent := lower(coalesce(nullif(btrim(p_payload->>'intent'), ''), 'interest'));
  if v_intent not in ('interest', 'admission') then
    raise exception 'Invalid submission intent.';
  end if;

  select * into v_org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  select * into v_branch
  from public.branches
  where organization_id=v_org.id and code='MAIN' and is_active
  limit 1;

  v_offering_id := nullif(btrim(coalesce(p_payload->>'offering_id','')), '')::uuid;
  if v_offering_id is not null then
    select * into v_offering
    from public.programme_offerings
    where id = v_offering_id
      and organization_id = v_org.id
      and status = 'ACTIVE';

    if v_offering.id is null then
      raise exception 'Selected programme offering is not available.';
    end if;

    if coalesce(v_offering.is_accepting_applications, false) is not true then
      raise exception 'Applications are closed for this programme offering.';
    end if;

    if v_offering.applications_open_on is not null and v_today < v_offering.applications_open_on then
      raise exception 'Applications are not open yet for this programme offering.';
    end if;

    if v_offering.applications_close_on is not null and v_today > v_offering.applications_close_on then
      raise exception 'Applications are closed for this programme offering.';
    end if;

    if v_offering.branch_id is not null then
      select * into v_branch
      from public.branches
      where id = v_offering.branch_id and is_active;
    end if;
  elsif v_intent = 'admission' then
    raise exception 'An open programme offering is required for admission applications.';
  end if;

  begin
    select * into v_class
    from public.classes
    where id=(p_payload->>'class_id')::uuid
      and organization_id=v_org.id
      and is_active;
  exception when others then
    raise exception 'Selected class is not available.';
  end;

  if v_class.id is null then
    raise exception 'Selected class is not available.';
  end if;

  if v_offering.id is not null and v_class.id is distinct from v_offering.class_id then
    raise exception 'Selected class does not match the chosen programme offering.';
  end if;

  if exists (
    select 1
    from public.prospects p
    where regexp_replace(p.mobile, '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and p.current_class_id=v_class.id
      and p.created_at > now() - interval '10 minutes'
  ) then
    raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
  end if;

  v_school_name := nullif(btrim(coalesce(p_payload->>'school_name_snapshot','')), '');

  if nullif(p_payload->>'school_id','') is not null then
    begin
      select * into v_school
      from public.schools
      where id=(p_payload->>'school_id')::uuid
        and organization_id=v_org.id
        and is_active;
    exception when others then
      raise exception 'Selected school is not available.';
    end;

    if v_school.id is null then
      raise exception 'Selected school is not available.';
    end if;

    v_school_name := coalesce(v_school_name, v_school.name);
  elsif v_school_name is not null then
    select * into v_school
    from public.schools
    where organization_id=v_org.id
      and lower(btrim(name))=lower(v_school_name)
      and is_active
    order by is_verified desc, created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools(
        organization_id,
        name,
        is_verified,
        is_active
      )
      values(
        v_org.id,
        v_school_name,
        false,
        true
      )
      returning * into v_school;
    end if;

    v_school_name := v_school.name;
  end if;

  if nullif(p_payload->>'source_code','') is not null then
    select * into v_source
    from public.lead_sources
    where organization_id=v_org.id
      and code=upper(p_payload->>'source_code')
      and is_active;

    if v_source.id is null then
      raise exception 'Selected source is not available.';
    end if;
  end if;

  v_relationship_text := nullif(btrim(coalesce(p_payload->>'guardian_relationship','')), '');

  if v_relationship_text is not null then
    select * into v_relationship
    from public.guardian_relationships
    where organization_id=v_org.id
      and (
        upper(code)=upper(replace(v_relationship_text,' ','_'))
        or lower(name)=lower(v_relationship_text)
      )
      and is_active
    limit 1;
  end if;

  insert into public.prospects(
    organization_id,
    branch_id,
    student_name,
    student_name_bn,
    guardian_name,
    guardian_relationship_id,
    guardian_relationship_snapshot,
    mobile,
    alternate_mobile,
    current_class_id,
    school_id,
    school_name_snapshot,
    area_snapshot,
    preferred_schedule,
    preferred_days,
    trial_interest,
    source_id,
    referral_note,
    notes,
    consent_to_contact,
    submitted_via,
    interested_offering_id,
    submission_intent
  )
  values(
    v_org.id,
    v_branch.id,
    btrim(p_payload->>'student_name'),
    nullif(btrim(coalesce(p_payload->>'student_name_bn','')), ''),
    btrim(p_payload->>'guardian_name'),
    v_relationship.id,
    v_relationship_text,
    v_mobile,
    nullif(btrim(coalesce(p_payload->>'alternate_mobile','')), ''),
    v_class.id,
    v_school.id,
    v_school_name,
    nullif(btrim(coalesce(p_payload->>'area','')), ''),
    nullif(btrim(coalesce(p_payload->>'preferred_schedule','')), ''),
    case
      when nullif(btrim(coalesce(p_payload->>'preferred_days','')), '') is null
        then '{}'::text[]
      else string_to_array(p_payload->>'preferred_days', ',')
    end,
    coalesce((p_payload->>'trial_interest')::boolean, false),
    v_source.id,
    nullif(btrim(coalesce(p_payload->>'referral_note','')), ''),
    nullif(btrim(coalesce(p_payload->>'notes','')), ''),
    true,
    'PUBLIC_WEB',
    v_offering.id,
    v_intent
  )
  returning * into v_prospect;

  for v_program_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'program_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.programs
      where id=v_program_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected program is not available.';
    end if;

    insert into public.prospect_program_interests(prospect_id,program_id)
    values(v_prospect.id,v_program_id)
    on conflict do nothing;
  end loop;

  if v_offering.id is not null then
    insert into public.prospect_program_interests(prospect_id,program_id)
    values(v_prospect.id, v_offering.program_id)
    on conflict do nothing;
  end if;

  for v_subject_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'subject_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.subjects
      where id=v_subject_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected subject is not available.';
    end if;

    if v_offering.id is not null and not exists (
      select 1 from public.programme_offering_subjects
      where offering_id = v_offering.id and subject_id = v_subject_id
    ) then
      raise exception 'One selected subject is not part of the chosen programme offering.';
    end if;

    insert into public.prospect_subject_interests(prospect_id,subject_id)
    values(v_prospect.id,v_subject_id)
    on conflict do nothing;
  end loop;

  insert into public.audit_events(
    correlation_id,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    'PROSPECT',
    v_prospect.id::text,
    'CREATE_PUBLIC_INTEREST',
    jsonb_build_object(
      'prospect_no',v_prospect.prospect_no,
      'student_name',v_prospect.student_name,
      'current_class_id',v_prospect.current_class_id,
      'source_id',v_prospect.source_id,
      'trial_interest',v_prospect.trial_interest,
      'interested_offering_id',v_prospect.interested_offering_id,
      'submission_intent',v_prospect.submission_intent
    ),
    jsonb_build_object('submitted_via','PUBLIC_WEB')
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no
  );
end;
$$;

revoke all on function public.submit_public_interest(jsonb) from public;
grant execute on function public.submit_public_interest(jsonb) to anon, authenticated;



-- ============================================================
-- SOURCE: 0028_v2_class_logs.sql
-- ============================================================

-- Actual taught content and homework are immutable, session-linked evidence.
create table public.class_logs (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.class_sessions(id),
 revision integer not null check(revision>0),
 previous_log_id uuid references public.class_logs(id),
 status text not null check(status in ('DRAFT','SUBMITTED')),
 unit_progress jsonb not null default '[]'::jsonb,
 class_summary text not null,
 unfinished_reason text not null default '',
 homework text not null default '',
 next_session_plan text not null default '',
 reason text not null,
 authored_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 submitted_at timestamptz,
 unique(session_id,revision),
 check((status='DRAFT' and submitted_at is null) or (status='SUBMITTED' and submitted_at is not null))
);
create unique index one_class_log_draft_per_session on public.class_logs(session_id) where status='DRAFT';
create index class_logs_session_history on public.class_logs(session_id,revision desc);
alter table public.class_logs enable row level security;
revoke all on public.class_logs from anon,authenticated;

create function public.guard_submitted_class_log() returns trigger language plpgsql as $$
begin
 if tg_op='DELETE' then raise exception 'Class-log history cannot be deleted.'; end if;
 if old.status='SUBMITTED' then raise exception 'Submitted class-log evidence is immutable.'; end if;
 if new.status='SUBMITTED' and (to_jsonb(new)-'status'-'submitted_at') is distinct from (to_jsonb(old)-'status'-'submitted_at') then raise exception 'Submit the saved draft without changing its contents.'; end if;
 return new;
end $$;
create trigger class_log_history_guard before update or delete on public.class_logs for each row execute function public.guard_submitted_class_log();

create function public.class_log_workspace(p_session_id uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.'; end if;
 select jsonb_build_object(
  'logs',coalesce((select jsonb_agg(to_jsonb(l) order by revision desc) from public.class_logs l where l.session_id=p_session_id),'[]'::jsonb),
  'units',coalesce((select cv.units from public.class_sessions cs join public.curriculum_versions cv on cv.id=cs.curriculum_version_id where cs.id=p_session_id),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create function public.class_log_command(p_input jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid(); rid uuid:=nullif(p_input->>'request_id','')::uuid; sid uuid:=nullif(p_input->>'session_id','')::uuid;
 act text:=p_input->>'action'; why text:=trim(coalesce(p_input->>'reason','')); key public.admission_command_keys;
 cs public.class_sessions; latest public.class_logs; draft public.class_logs; progress jsonb:=coalesce(p_input->'unit_progress','[]'::jsonb); unit_count integer;
 summary text:=trim(coalesce(p_input->>'class_summary','')); unfinished text:=trim(coalesce(p_input->>'unfinished_reason',''));
 homework_value text:=trim(coalesce(p_input->>'homework','')); next_value text:=trim(coalesce(p_input->>'next_session_plan',''));
 result jsonb; new_revision integer; branch uuid;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 if rid is null or sid is null or length(why)<5 or length(why)>500 then raise exception 'Session, request identity and reason (5–500 characters) are required.'; end if;
 if act not in ('SAVE_DRAFT','SUBMIT') then raise exception 'Unsupported class-log action.'; end if;
 if not (public.has_permission('academics.attendance.record') or public.has_permission('academics.sessions.manage')) then raise exception 'Attendance recording permission required.'; end if;
 if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
 select * into key from public.admission_command_keys where request_id=rid;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if; return key.result; end if;
 perform pg_advisory_xact_lock(hashtextextended(sid::text,21));
 select * into cs from public.class_sessions where id=sid for update;
 select branch_id into branch from public.batches where id=cs.batch_id;
 if cs.status<>'SCHEDULED' then raise exception 'A cancelled class cannot receive a class log.'; end if;
 if cs.starts_at>now() then raise exception 'Class log opens after the scheduled class starts.'; end if;
 if not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff st where st.profile_id=actor and st.id=cs.teacher_id) then raise exception 'Only the assigned teacher may record this class.'; end if;
 select * into latest from public.class_logs where session_id=sid order by revision desc limit 1;
 select * into draft from public.class_logs where session_id=sid and status='DRAFT' for update;
 if act='SAVE_DRAFT' then
  if jsonb_typeof(progress)<>'array' or jsonb_array_length(progress)>200 then raise exception 'Check curriculum progress entries.'; end if;
  select coalesce(jsonb_array_length(cv.units),0) into unit_count from public.class_sessions x left join public.curriculum_versions cv on cv.id=x.curriculum_version_id where x.id=sid;
  if jsonb_array_length(progress)>unit_count then raise exception 'Progress must refer only to the curriculum pinned to this class.'; end if;
  if exists(select 1 from jsonb_array_elements(progress) e where (e->>'unit_index')::integer<0 or (e->>'unit_index')::integer>=unit_count or e->>'status' not in ('COVERED','PARTIAL','NOT_COVERED') or length(coalesce(e->>'note',''))>500) then raise exception 'Invalid curriculum progress entry.'; end if;
  if summary='' or length(summary)>4000 or length(unfinished)>2000 or length(homework_value)>2000 or length(next_value)>2000 then raise exception 'Class summary is required; keep each field within its limit.'; end if;
  if exists(select 1 from jsonb_array_elements(progress) e where e->>'status' in ('PARTIAL','NOT_COVERED')) and unfinished='' then raise exception 'Explain any planned curriculum left incomplete.'; end if;
  if draft.id is not null and draft.authored_by<>actor then raise exception 'Another staff member owns the current draft.'; end if;
  if draft.id is null then
   select coalesce(max(revision),0)+1 into new_revision from public.class_logs where session_id=sid;
   insert into public.class_logs(session_id,revision,previous_log_id,status,unit_progress,class_summary,unfinished_reason,homework,next_session_plan,reason,authored_by)
   values(sid,new_revision,latest.id,'DRAFT',progress,summary,unfinished,homework_value,next_value,why,actor) returning * into draft;
  else
   update public.class_logs set unit_progress=progress,class_summary=summary,unfinished_reason=unfinished,homework=homework_value,next_session_plan=next_value,reason=why where id=draft.id returning * into draft;
  end if;
  result:=jsonb_build_object('id',draft.id,'revision',draft.revision,'status',draft.status,'message','Class-log draft saved.');
 else
  if draft.id is null or draft.authored_by<>actor then raise exception 'Save your class-log draft before submitting it.'; end if;
  update public.class_logs set status='SUBMITTED',submitted_at=now() where id=draft.id returning * into draft;
  result:=jsonb_build_object('id',draft.id,'revision',draft.revision,'status',draft.status,'message','Class log submitted. Curriculum completion remains a teacher report, separate from attendance approval.');
 end if;
 insert into public.audit_events(actor_profile_id,branch_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(actor,branch,'CLASS_LOG',draft.id::text,act,why,null,to_jsonb(draft),jsonb_build_object('session_id',sid,'revision',draft.revision));
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
 return result;
end $$;
revoke all on function public.class_log_workspace(uuid),public.class_log_command(jsonb) from public,anon;
grant execute on function public.class_log_workspace(uuid),public.class_log_command(jsonb) to authenticated;

