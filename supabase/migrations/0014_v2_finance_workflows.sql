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
