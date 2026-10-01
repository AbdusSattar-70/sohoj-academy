-- Sohoj Academy fresh database baseline: accounting workflows.
-- Install on an empty application schema. Each object is defined once.

CREATE OR REPLACE FUNCTION public.finance_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 actor uuid:=auth.uid(); action text:=p_input->>'action'; req uuid:=(p_input->>'request_id')::uuid;
 reason text:=btrim(coalesce(p_input->>'reason','')); key public.admission_command_keys;
 a public.admission_cases;
 start_date date; end_date date; kind text; value numeric; preview jsonb; row jsonb; invoice_id uuid; gross numeric:=0; count_invoices integer:=0;
 result jsonb; permission text; today date; year public.academic_years; term public.billing_terms;
begin
 if actor is null then raise exception 'Sign in to continue.'; end if;
 if req is null or length(reason)<5 then raise exception 'A request identity and reason are required.'; end if;
 if action in('APPLY_DISCOUNT','CANCEL_ADMISSION','REFUND') then return public.apply_finance_adjustment(p_input); end if;
 if action not in('RUN_BILLING','CREATE_TERM') or not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
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
  raise exception 'Choose a supported billing action.';
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'FINANCE_WORKFLOW',result->>'id',action,reason,result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.assert_journal_balanced()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_journal uuid := coalesce(new.journal_id,old.journal_id);
  v_debit numeric;
  v_credit numeric;
begin
  select
    coalesce(sum(debit),0),
    coalesce(sum(credit),0)
  into v_debit,v_credit
  from public.general_ledger_lines
  where journal_id=v_journal;

  if v_debit<>v_credit then
    raise exception 'Journal % is not balanced. Debit %, credit %.',
      v_journal,v_debit,v_credit;
  end if;

  return coalesce(new,old);
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_account_balance(p_account_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when a.account_type in('ASSET','EXPENSE') then
      coalesce(sum(l.debit-l.credit),0)
    when a.account_type in('LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE') then
      coalesce(sum(l.credit-l.debit),0)
    else 0
  end
  from public.finance_accounts a
  join public.general_ledger_lines l on l.account_id=a.id
  join public.general_ledger_journals j on j.id=l.journal_id
  where a.id=p_account_id
    and j.status='POSTED'
    and j.journal_date<=p_as_of
  group by a.id,a.account_type;
$function$;

CREATE OR REPLACE FUNCTION public.advance_balance(p_advance_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(
    case movement_type
      when 'PAYMENT' then amount
      when 'SETTLEMENT' then -amount
      when 'REFUND' then -amount
    end
  ),0)
  from public.finance_advance_movements
  where advance_id=p_advance_id;
$function$;

CREATE OR REPLACE FUNCTION public.finance_post_journal(p_organization_id uuid, p_journal_date date, p_journal_type text, p_source_type text, p_source_id text, p_description text, p_posted_by uuid, p_lines jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  journal_id uuid;
  line jsonb;
  n integer:=0;
  debit_total numeric:=0;
  credit_total numeric:=0;
  account_org uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines)<>'array'
     or jsonb_array_length(p_lines)<2 then
    raise exception 'A journal requires at least two lines.';
  end if;

  if exists(
    select 1 from public.general_ledger_journals
    where source_type=p_source_type and source_id=p_source_id
  ) then
    select id into journal_id
    from public.general_ledger_journals
    where source_type=p_source_type and source_id=p_source_id;
    return journal_id;
  end if;

  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
    if nullif(line->>'account_id','') is null then
      raise exception 'Journal line % has no account.',n;
    end if;

    select organization_id into account_org
    from public.finance_accounts
    where id=(line->>'account_id')::uuid and is_active;

    if account_org is null or account_org<>p_organization_id then
      raise exception 'Journal line % uses an invalid account.',n;
    end if;

    debit_total:=debit_total+coalesce((line->>'debit')::numeric,0);
    credit_total:=credit_total+coalesce((line->>'credit')::numeric,0);

    if coalesce((line->>'debit')::numeric,0)>0
       and coalesce((line->>'credit')::numeric,0)>0 then
      raise exception 'Journal line % cannot contain both debit and credit.',n;
    end if;

    if coalesce((line->>'debit')::numeric,0)<=0
       and coalesce((line->>'credit')::numeric,0)<=0 then
      raise exception 'Journal line % must contain a positive debit or credit.',n;
    end if;
  end loop;

  if round(debit_total,2)<>round(credit_total,2) then
    raise exception 'Journal must balance. Debit %, credit %.',debit_total,credit_total;
  end if;

  insert into public.general_ledger_journals(
    organization_id,journal_date,journal_type,source_type,source_id,
    description,posted_by
  )
  values(
    p_organization_id,p_journal_date,p_journal_type,p_source_type,p_source_id,
    btrim(p_description),p_posted_by
  )
  returning id into journal_id;

  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
  end loop;

  n:=0;
  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
    insert into public.general_ledger_lines(
      journal_id,line_no,account_id,debit,credit,memo,
      cost_centre_id,branch_id,program_id,batch_id
    )
    values(
      journal_id,n,(line->>'account_id')::uuid,
      coalesce((line->>'debit')::numeric,0),
      coalesce((line->>'credit')::numeric,0),
      nullif(btrim(line->>'memo'),''),
      nullif(line->>'cost_centre_id','')::uuid,
      nullif(line->>'branch_id','')::uuid,
      nullif(line->>'program_id','')::uuid,
      nullif(line->>'batch_id','')::uuid
    );
  end loop;

  return journal_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_invoice(p_invoice_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  i public.admission_invoices;
  a public.admission_cases;
  org uuid;
  ar uuid;
  other_revenue uuid;
  lines jsonb:='[]'::jsonb;
begin
  select * into i from public.admission_invoices where id=p_invoice_id;
  if i.id is null or i.total <= 0 then return null; end if;

  select * into a from public.admission_cases where id=i.admission_id;
  select organization_id into org from public.students where id=i.student_id;

  select id into ar from public.finance_accounts
  where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into other_revenue from public.finance_accounts
  where organization_id=org and account_subtype='OTHER_FEE_REVENUE' and is_active limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'account_id',coalesce(m.account_id,other_revenue),
      'debit',0,
      'credit',l.amount,
      'memo',l.name,
      'branch_id',b.branch_id,
      'program_id',b.program_id,
      'batch_id',b.id
    )
  ),'[]'::jsonb)
  into lines
  from public.admission_invoice_lines l
  left join public.finance_fee_revenue_map m
    on m.organization_id=org and m.charge_type=l.charge_type
  join public.admission_cases ac on ac.id=i.admission_id
  join public.batches b on b.id=ac.batch_id
  where l.invoice_id=i.id and l.amount>0;

  if jsonb_array_length(lines)=0 then
    raise exception 'A positive invoice has no positive charge lines.';
  end if;

  lines:=jsonb_build_array(
    jsonb_build_object(
      'account_id',ar,
      'debit',i.total,
      'credit',0,
      'memo','Student receivable'
    )
  ) || lines;

  return public.finance_post_journal(
    org,i.issued_on,
    'INVOICE','ADMISSION_INVOICE',i.id::text,
    'Invoice '||i.invoice_no,
    i.posted_by,lines
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_invoice_line_statement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
begin
  for r in select distinct invoice_id from new_table
  loop
    perform public.finance_sync_invoice(r.invoice_id);
  end loop;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_invoice_credit(p_credit_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.invoice_credits;
  i public.admission_invoices;
  org uuid;
  ar uuid;
  contra uuid;
begin
  select * into c from public.invoice_credits where id=p_credit_id;
  select * into i from public.admission_invoices where id=c.invoice_id;
  select organization_id into org from public.students where id=i.student_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into contra from public.finance_accounts where organization_id=org and account_subtype='FEE_CREDITS' and is_active limit 1;

  return public.finance_post_journal(
    org,current_date,'INVOICE_CREDIT','INVOICE_CREDIT',c.id::text,
    initcap(lower(c.kind))||' credit for invoice '||i.invoice_no,
    (select posted_by from public.admission_cases a join public.admission_invoices x on x.admission_id=a.id where x.id=i.id limit 1),
    jsonb_build_array(
      jsonb_build_object('account_id',contra,'debit',c.amount,'credit',0,'memo',c.kind),
      jsonb_build_object('account_id',ar,'debit',0,'credit',c.amount,'memo','Reduce student receivable')
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_invoice_credit_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.finance_sync_invoice_credit(new.id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_payment(p_payment_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  p public.admission_payments;
  pa public.admission_payment_allocations;
  i public.admission_invoices;
  org uuid;
  cash_account uuid;
  ar uuid;
begin
  select * into p from public.admission_payments where id=p_payment_id;
  select * into pa from public.admission_payment_allocations where payment_id=p.id;
  select * into i from public.admission_invoices where id=pa.invoice_id;
  select organization_id into org from public.students where id=p.student_id;
  select account_id into cash_account from public.finance_payment_account_map where payment_method_id=p.payment_method_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;

  return public.finance_post_journal(
    org,p.posted_at::date,'PAYMENT','ADMISSION_PAYMENT',p.id::text,
    'Payment '||p.receipt_no,p.posted_by,
    jsonb_build_array(
      jsonb_build_object('account_id',cash_account,'debit',p.amount,'credit',0,'memo',p.receipt_no),
      jsonb_build_object('account_id',ar,'debit',0,'credit',p.amount,'memo','Reduce student receivable')
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_payment_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.finance_sync_payment(new.payment_id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_refund(p_payout_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  rp public.refund_payouts;
  ra public.refund_authorizations;
  i public.admission_invoices;
  org uuid;
  cash_account uuid;
  ar uuid;
begin
  select * into rp from public.refund_payouts where id=p_payout_id;
  select * into ra from public.refund_authorizations where id=rp.authorization_id;
  select * into i from public.admission_invoices where id=ra.invoice_id;
  select organization_id into org from public.students where id=i.student_id;
  select account_id into cash_account from public.finance_payment_account_map where payment_method_id=rp.payment_method_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;

  return public.finance_post_journal(
    org,rp.posted_at::date,'REFUND','REFUND_PAYOUT',rp.id::text,
    'Refund '||rp.refund_no,rp.posted_by,
    jsonb_build_array(
      jsonb_build_object('account_id',ar,'debit',ra.amount,'credit',0,'memo','Reinstate student receivable'),
      jsonb_build_object('account_id',cash_account,'debit',0,'credit',ra.amount,'memo',rp.refund_no)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_sync_refund_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.finance_sync_refund(new.id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_net_collected_tuition(p_from date, p_to date)
 RETURNS TABLE(admission_id uuid, batch_id uuid, billing_period date, tuition_collected numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with cash_events as (
 select i.id invoice_id,i.admission_id,a.batch_id,
  timezone(o.timezone,p.posted_at)::date event_date,
  pa.amount signed_amount,
  (select coalesce(sum(l.amount),0) from public.admission_invoice_lines l
    where l.invoice_id=i.id and l.charge_type='TUITION') tuition_gross
 from public.admission_payment_allocations pa
 join public.admission_payments p on p.id=pa.payment_id
 join public.admission_invoices i on i.id=pa.invoice_id
 join public.admission_cases a on a.id=i.admission_id
 join public.students s on s.id=p.student_id
 join public.organizations o on o.id=s.organization_id
 where timezone(o.timezone,p.posted_at)::date between p_from and p_to
 union all
 select i.id,i.admission_id,a.batch_id,
  timezone(o.timezone,rp.posted_at)::date,-r.amount,
  (select coalesce(sum(l.amount),0) from public.admission_invoice_lines l
    where l.invoice_id=i.id and l.charge_type='TUITION')
 from public.refund_payouts rp
 join public.refund_authorizations r on r.id=rp.authorization_id
 join public.admission_invoices i on i.id=r.invoice_id
 join public.admission_cases a on a.id=i.admission_id
 join public.students s on s.id=i.student_id
 join public.organizations o on o.id=s.organization_id
 where timezone(o.timezone,rp.posted_at)::date between p_from and p_to
), attributed as (
 select e.*, greatest(i.total-coalesce((select sum(c.amount) from public.invoice_credits c
   where c.invoice_id=e.invoice_id and c.created_at::date<=e.event_date),0),0) net_invoice,
  greatest(e.tuition_gross-coalesce((select sum(c.amount) from public.invoice_credits c
   where c.invoice_id=e.invoice_id and c.kind='DISCOUNT' and c.created_at::date<=e.event_date),0),0) net_tuition
 from cash_events e join public.admission_invoices i on i.id=e.invoice_id
)
select admission_id,batch_id,date_trunc('month',event_date)::date,
 round(sum(case when net_invoice>0 then signed_amount*least(net_tuition,net_invoice)/net_invoice else 0 end),2)
from attributed group by admission_id,batch_id,date_trunc('month',event_date)::date;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_compensation_preview(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  policy public.business_rule_versions;
  rows jsonb:='[]'::jsonb;
  teacher_row record;
  batch_row record;
  event_amount numeric;
  pool_percent numeric;
  acquisition_percent numeric;
  retention3_percent numeric;
  retention6_percent numeric;
  first_period date;
  first_collected numeric;
  month3 date;
  month6 date;
  month_paid boolean;
  continuous3 boolean;
  continuous6 boolean;
begin
  if actor is null or not public.has_permission('staff.compensation.view') then
    raise exception 'Compensation access denied.';
  end if;
  if p_from is null or p_to is null or p_to<p_from then
    raise exception 'Choose a valid compensation period.';
  end if;

  select * into policy
  from public.business_rule_versions
  where domain='teacher_compensation'
    and rule_key='default_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if policy.id is null
     or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
    raise exception 'A valid teacher compensation policy is required.';
  end if;

  pool_percent:=(policy.payload->>'teaching_pool_percent')::numeric;
  acquisition_percent:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  retention3_percent:=(policy.payload->>'retention_3_month_percent')::numeric;
  retention6_percent:=(policy.payload->>'retention_6_month_percent')::numeric;

  -- Teaching pool is calculated per batch from Net Collected Tuition and
  -- allocated by approved attendance/session workload within that batch.
  for batch_row in
    with batch_revenue as (
      select batch_id,sum(tuition_collected) net_collected
      from public.finance_net_collected_tuition(p_from,p_to)
      group by batch_id
    ),
    session_weights as (
      select
        cs.batch_id,
        cs.teacher_id,
        count(*) filter(
          where exists(
            select 1 from public.attendance_submissions aa
            where aa.id=(
              select z.id from public.attendance_submissions z
              where z.session_id=cs.id
              order by z.revision desc limit 1
            )
            and aa.status='APPROVED'
          )
        )::numeric as session_count
      from public.class_sessions cs
      where cs.session_date between p_from and p_to
        and cs.status='SCHEDULED'
      group by cs.batch_id,cs.teacher_id
    )
    select
      r.batch_id,
      r.net_collected,
      r.net_collected*pool_percent/100 as pool_amount,
      w.teacher_id,
      w.session_count,
      sum(w.session_count) over(partition by w.batch_id) total_sessions
    from batch_revenue r
    join session_weights w on w.batch_id=r.batch_id
    where r.net_collected>0 and w.session_count>0
  loop
    event_amount:=round(batch_row.pool_amount*batch_row.session_count/nullif(batch_row.total_sessions,0),2);
    if event_amount>0 and not exists (select 1 from public.teacher_compensation_claims c
      where c.teacher_id=batch_row.teacher_id and c.source_type='BATCH_PERIOD'
        and c.source_id=batch_row.batch_id::text||':'||p_from::text||':'||p_to::text) then
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',batch_row.teacher_id,
        'lineType','TEACHING_REMUNERATION',
        'amount',event_amount,
        'sourceType','BATCH_PERIOD',
        'sourceId',batch_row.batch_id::text||':'||p_from::text||':'||p_to::text,
        'calculation',jsonb_build_object(
          'batchId',batch_row.batch_id,
          'netCollectedTuition',batch_row.net_collected,
          'poolPercent',pool_percent,
          'poolAmount',batch_row.pool_amount,
          'approvedSessions',batch_row.session_count,
          'batchApprovedSessions',batch_row.total_sessions
        )
      )
    );
    end if;
  end loop;

  -- Acquisition/retention bonuses require a structured teacher referral.
  for teacher_row in
    select
      tr.teacher_id,
      tr.admission_id,
      min(n.billing_period) first_billing_period
    from public.teacher_referrals tr
    join public.admission_cases a on a.id=tr.admission_id and a.status='ACTIVE_ENROLLMENT'
    join public.finance_net_collected_tuition(date '2000-01-01',p_to) n
      on n.admission_id=tr.admission_id and n.tuition_collected>0
    group by tr.teacher_id,tr.admission_id
  loop
    first_period:=teacher_row.first_billing_period;

    select coalesce(sum(n.tuition_collected),0)
    into first_collected
    from public.finance_net_collected_tuition(first_period,(first_period+interval '1 month - 1 day')::date) n
    where n.admission_id=teacher_row.admission_id;

    if first_period between p_from and p_to and first_collected>0
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='ACQUISITION'
          and c.source_id=teacher_row.admission_id::text) then
      rows:=rows||jsonb_build_array(
        jsonb_build_object(
          'teacherId',teacher_row.teacher_id,
          'admissionId',teacher_row.admission_id,
          'lineType','ACQUISITION_BONUS',
          'amount',round(first_collected*acquisition_percent/100,2),
          'sourceType','ACQUISITION',
          'sourceId',teacher_row.admission_id::text,
          'calculation',jsonb_build_object(
            'firstMonthNetCollectedTuition',first_collected,
            'bonusPercent',acquisition_percent
          )
        )
      );
    end if;

    month3:=(first_period+interval '2 months')::date;
    month6:=(first_period+interval '5 months')::date;

    select bool_and(tuition_collected>0)
    into continuous3
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month3,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month3 between p_from and p_to and continuous3 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_3'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month3,(month3+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_3_MONTH',
            'amount',round(event_amount*retention3_percent/100,2),
            'sourceType','RETENTION_3',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month3,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention3_percent
            )
          )
        );
      end if;
    end if;

    select bool_and(tuition_collected>0)
    into continuous6
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month6,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month6 between p_from and p_to and continuous6 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_6'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month6,(month6+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_6_MONTH',
            'amount',round(event_amount*retention6_percent/100,2),
            'sourceType','RETENTION_6',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month6,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention6_percent
            )
          )
        );
      end if;
    end if;
  end loop;

  for teacher_row in
    select teacher_id,adjustment_type,id,amount
    from public.teacher_compensation_adjustments
    where status='APPROVED'
      and effective_period between p_from and p_to
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_compensation_adjustments.teacher_id
          and c.source_type='ADJUSTMENT' and c.source_id=teacher_compensation_adjustments.id::text)
  loop
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',teacher_row.teacher_id,
        'lineType',case when teacher_row.adjustment_type='GROWTH_BONUS'
          then 'GROWTH_BONUS' else 'ADJUSTMENT' end,
        'amount',teacher_row.amount,
        'sourceType','ADJUSTMENT',
        'sourceId',teacher_row.id::text,
        'calculation',jsonb_build_object(
          'adjustmentType',teacher_row.adjustment_type
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'periodStart',p_from,
    'periodEnd',p_to,
    'policyVersion',policy.version,
    'rows',rows,
    'total',coalesce((select sum((x->>'amount')::numeric) from jsonb_array_elements(rows) x),0)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finance_accounting_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  key public.admission_command_keys;
  result jsonb;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  org uuid;
  account public.finance_accounts;
  journal_id uuid;
  advance public.finance_advances;
  adv_balance numeric;
  payable public.finance_payables;
  expense public.finance_expenses;
  vendor public.vendors;
  amount numeric;
  expense_account uuid;
  payment_account uuid;
  payment_mode text;
  category public.finance_expense_categories;
  compensation public.teacher_compensation_runs;
  policy public.business_rule_versions;
  preview jsonb;
  line jsonb;
  teacher_id uuid;
  v_teacher uuid;
  settlement public.teacher_compensation_settlements;
  cash_paid numeric;
  advance_offset numeric;
  advance_row record;
  settlement_id uuid;
  decision text;
  source_type text;
  permission text;
begin
  if actor is null then raise exception 'Sign in to continue.'; end if;
  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason of at least five characters are required.';
  end if;

  permission := null;
  -- Action permission is assigned below because compensation/expense/advance
  -- workflows have different authorization boundaries.
  if action in('CREATE_ADVANCE','CREATE_EXPENSE_DIRECT','RUN_COMPENSATION','APPLY_COMP_ADJUSTMENT') then
    return public.post_accounting_operation(p_input);
  end if;
  permission:=case
    when action in('CREATE_ACCOUNT','POST_JOURNAL') then 'accounting.manage'
    when action in('CREATE_VENDOR','PAY_ADVANCE','REFUND_ADVANCE','APPLY_ADVANCE') then 'finance.advances.manage'
    when action='SETTLE_PAYABLE' then 'finance.payments.post'
    when action in('RECONCILE_EXPENSE','RECONCILE_ACCOUNT') then 'accounting.reconcile'
    when action='SETTLE_COMPENSATION' then 'staff.compensation.manage'
    else null end;

  if permission is null or not public.has_permission(permission) then
    raise exception 'Permission denied for this accounting action.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,7));
  select * into key from public.admission_command_keys where request_id=req;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select id into org from public.organizations where code='SOHOJ' and is_active limit 1;

  if action='CREATE_ACCOUNT' then
    if length(btrim(coalesce(p_input->>'code','')))<2
       or length(btrim(coalesce(p_input->>'name','')))<2
       or p_input->>'account_type' not in('ASSET','LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE','EXPENSE')
       or length(btrim(coalesce(p_input->>'account_subtype','')))<2 then
      raise exception 'Enter valid account code, name, type and category.';
    end if;

    insert into public.finance_accounts(
      organization_id,code,name,account_type,account_subtype,parent_id,
      is_control_account,created_by
    )
    values(
      org,btrim(p_input->>'code'),btrim(p_input->>'name'),
      p_input->>'account_type',btrim(p_input->>'account_subtype'),
      nullif(p_input->>'parent_id','')::uuid,
      coalesce((p_input->>'is_control_account')::boolean,false),actor
    )
    returning * into account;

    result:=jsonb_build_object('id',account.id,'message','Financial account created.');

  elsif action='POST_JOURNAL' then
    if not public.has_permission('accounting.manage') then raise exception 'Accounting management permission required.'; end if;
    perform public.finance_post_journal(
      org,
      (p_input->>'journal_date')::date,
      'MANUAL',
      'MANUAL_JOURNAL',
      req::text,
      btrim(p_input->>'description'),
      actor,
      p_input->'lines'
    );
    result:=jsonb_build_object('id',req,'message','Balanced journal posted.');

  elsif action='CREATE_VENDOR' then
    if length(btrim(coalesce(p_input->>'name','')))<2 then
      raise exception 'Vendor name is required.';
    end if;
    insert into public.vendors(
      organization_id,name,mobile,email,address,service_category,created_by
    )
    values(
      org,btrim(p_input->>'name'),
      nullif(btrim(p_input->>'mobile'),''),
      nullif(lower(btrim(p_input->>'email')),''),
      nullif(btrim(p_input->>'address'),''),
      nullif(btrim(p_input->>'service_category'),''),
      actor
    )
    returning * into vendor;
    result:=jsonb_build_object('id',vendor.id,'vendorNo',vendor.vendor_no,'message','Vendor created.');

  elsif action='PAY_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null or advance.status not in('APPROVED','PAID') then raise exception 'Only approved advances can be paid.'; end if;
    if amount is null or amount<=0 then raise exception 'Advance payment must be positive.'; end if;
    if amount>advance.approved_amount-public.advance_paid(advance.id) then raise exception 'Payment exceeds approved advance balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;

    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(
      advance.id,'PAYMENT',amount,'ADVANCE_PAYMENT',req::text,payment_account,actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_PAYMENT','ADVANCE_PAYMENT',req::text,
      'Advance payment '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='STAFF'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
            when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',amount,'credit',0
        ),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    if public.advance_paid(advance.id)>=advance.approved_amount then
      update public.finance_advances set status='PAID' where id=advance.id;
    end if;
    result:=jsonb_build_object('id',advance.id,'message','Advance payment posted.');

  elsif action='REFUND_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    adv_balance:=public.advance_balance(advance.id);
    if advance.id is null or adv_balance<=0 or amount is null or amount<=0 or amount>adv_balance then
      raise exception 'Refund exceeds the unsettled advance balance.';
    end if;
    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_REFUND','ADVANCE_REFUND',req::text,
      'Advance refund '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',payment_account,'debit',amount,'credit',0
        ),
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',0,'credit',amount
        )
      )
    );

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(advance.id,'REFUND',amount,'ADVANCE_REFUND',req::text,payment_account,actor,reason);

    update public.finance_advances
    set status=case when public.advance_balance(id)<=0 then 'REFUNDED' else status end
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance refund recorded.');

  elsif action='SETTLE_PAYABLE' then
    select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if payable.id is null or payable.status not in('OPEN','PARTIALLY_SETTLED') then raise exception 'Payable is not open.'; end if;
    if payable.payable_type='TEACHER_COMPENSATION' then raise exception 'Use the compensation settlement to preserve advance offsets.'; end if;
    if amount is null or amount<=0 or amount > payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0) then raise exception 'Settlement exceeds payable balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_payable_settlements(
      payable_id,amount,payment_account_id,external_reference,settled_by,reason
    )
    values(
      payable.id,amount,payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'PAYABLE_SETTLEMENT','PAYABLE_SETTLEMENT',req::text,
      'Payable settlement '||payable.payable_no,actor,
      jsonb_build_array(
        jsonb_build_object('account_id',payable.payable_account_id,'debit',amount,'credit',0),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
        then 'SETTLED'
      else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    result:=jsonb_build_object('id',payable.id,'message','Payable settlement posted.');

  elsif action='RECONCILE_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    amount:=(p_input->>'matched_amount')::numeric;
    if expense.id is null or expense.status<>'POSTED' then raise exception 'Post the expense before reconciliation.'; end if;
    if amount is null or amount<>expense.amount then raise exception 'Reconciled amount must equal the posted expense amount.'; end if;

    insert into public.finance_expense_reconciliations(
      expense_id,matched_amount,statement_reference,reconciled_by,note
    )
    values(
      expense.id,amount,btrim(p_input->>'statement_reference'),actor,reason
    )
    on conflict(expense_id) do nothing;

    if not found then raise exception 'Expense is already reconciled.'; end if;
    update public.finance_expenses set status='RECONCILED' where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense reconciled to the statement reference.');

  elsif action='RECONCILE_ACCOUNT' then
    select * into account from public.finance_accounts
    where id=(p_input->>'account_id')::uuid
      and organization_id=org and is_active;
    if account.id is null then raise exception 'Choose an active account.'; end if;

    select public.finance_account_balance(account.id,(p_input->>'statement_date')::date)
    into amount;

    if amount is null then amount:=0; end if;
    insert into public.finance_account_reconciliations(
      account_id,statement_date,statement_reference,statement_balance,
      ledger_balance,difference,status,note,reconciled_by,reconciled_at
    )
    values(
      account.id,(p_input->>'statement_date')::date,
      btrim(p_input->>'statement_reference'),
      (p_input->>'statement_balance')::numeric,
      amount,
      round((p_input->>'statement_balance')::numeric-amount,2),
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then 'RECONCILED' else 'OPEN' end,
      reason,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then actor else null end,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then now() else null end
    )
    on conflict(account_id,statement_date,statement_reference) do update
      set statement_balance=excluded.statement_balance,
          ledger_balance=excluded.ledger_balance,
          difference=excluded.difference,
          status=excluded.status,
          reconciled_by=excluded.reconciled_by,
          reconciled_at=excluded.reconciled_at,
          note=excluded.note;

    result:=jsonb_build_object('id',req,'message',
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0
        then 'Account reconciled.'
        else 'Reconciliation saved as open; investigate the difference before closing it.' end);

  elsif action='SETTLE_COMPENSATION' then
    select * into compensation from public.teacher_compensation_runs
    where id=(p_input->>'run_id')::uuid and status='APPROVED' for update;
    if compensation.id is null then raise exception 'Only an approved compensation run can be settled.'; end if;

    teacher_id:=(p_input->>'teacher_id')::uuid;
    select * into payable from public.finance_payables
    where source_type='COMPENSATION_RUN'
      and source_id=compensation.id::text||':'||teacher_id::text
      and staff_id=teacher_id
    for update;
    if payable.id is null then raise exception 'Teacher payable not found.'; end if;

    amount:=payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0);
    if amount<=0 then raise exception 'Teacher payable is already settled.'; end if;

    advance_offset:=coalesce((p_input->>'advance_offset')::numeric,0);
    if advance_offset<0 or advance_offset>amount then raise exception 'Advance offset is outside the payable balance.'; end if;

    if advance_offset>0 then
      select * into advance_row
      from (
        select adv.*,public.advance_balance(adv.id) balance
        from public.finance_advances adv
        where adv.staff_id=teacher_id
          and adv.beneficiary_type='STAFF'
          and public.advance_balance(adv.id)>0
          and adv.status in('PAID','PARTIALLY_SETTLED','OVERDUE')
        order by adv.expected_settlement_date nulls last,adv.created_at
      ) q
      limit 1 for update;

      if advance_row.id is null or advance_row.balance<advance_offset then
        raise exception 'Requested advance offset exceeds available teacher advance balance.';
      end if;
    end if;

    cash_paid:=amount-advance_offset;
    if cash_paid>0 then
      select id into payment_account
      from public.finance_accounts
      where id=(p_input->>'payment_account_id')::uuid
        and organization_id=compensation.organization_id
        and account_subtype in('CASH','BANK','MOBILE_BANK')
        and is_active;
      if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;
    end if;

    insert into public.teacher_compensation_settlements(
      run_id,teacher_id,payable_id,gross_amount,advance_offset,cash_paid,
      payment_account_id,external_reference,settled_by,reason
    )
    values(
      compensation.id,teacher_id,payable.id,amount,advance_offset,cash_paid,
      payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    )
    returning id into settlement;

    if advance_offset>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_SETTLEMENT',settlement.id::text,
        'Teacher compensation advance offset',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',advance_offset,'credit',0
          ),
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='STAFF_ADVANCE' limit 1),
            'debit',0,'credit',advance_offset
          )
        )
      );
      insert into public.finance_advance_movements(
        advance_id,movement_type,amount,source_type,source_id,payable_id,created_by,reason
      )
      values(
        advance_row.id,'SETTLEMENT',advance_offset,
        'COMPENSATION_SETTLEMENT',settlement.id::text,payable.id,actor,reason
      );
    end if;

    if cash_paid>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_CASH_SETTLEMENT',settlement.id::text,
        'Teacher compensation cash settlement',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',cash_paid,'credit',0
          ),
          jsonb_build_object(
            'account_id',payment_account,'debit',0,'credit',cash_paid
          )
        )
      );
    end if;

    if advance_offset>0 then
      insert into public.finance_payable_settlements(
        payable_id,amount,advance_id,settled_by,reason
      ) values(payable.id,advance_offset,advance_row.id,actor,reason);
    end if;
    if cash_paid>0 then
      insert into public.finance_payable_settlements(
        payable_id,amount,payment_account_id,external_reference,settled_by,reason
      ) values(payable.id,cash_paid,payment_account,
        nullif(btrim(p_input->>'external_reference'),''),actor,reason);
    end if;

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
      then 'SETTLED' else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    if not exists(
      select 1 from public.finance_payables
      where source_type='COMPENSATION_RUN'
        and source_id like compensation.id::text||':%'
        and status<>'SETTLED'
    ) then
      update public.teacher_compensation_runs set status='SETTLED' where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',settlement.id,'message','Teacher compensation settlement posted.');
  
  elsif action='APPLY_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null or advance.status not in('PAID','PARTIALLY_SETTLED','OVERDUE')
      or payable.id is null or payable.status not in('OPEN','PARTIALLY_SETTLED')
      or payable.organization_id<>advance.organization_id
      or not ((advance.beneficiary_type='VENDOR' and payable.vendor_id=advance.vendor_id)
        or (advance.beneficiary_type='STAFF' and payable.staff_id=advance.staff_id))
      or amount is null or amount<=0 or amount<>round(amount,2)
      or amount>public.advance_balance(advance.id)
      or amount>payable.original_amount-coalesce((select sum(s.amount)
        from public.finance_payable_settlements s where s.payable_id=payable.id),0) then
      raise exception 'Choose a matching approved payable and outstanding advance balance.';
    end if;
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',req::text,
        'Approved advance against payable '||payable.payable_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',payable.payable_account_id,'debit',amount,'credit',0),
          jsonb_build_object('account_id',(select id from public.finance_accounts
            where organization_id=org and account_subtype=case when advance.beneficiary_type='VENDOR'
              then 'VENDOR_ADVANCE' else 'STAFF_ADVANCE' end limit 1),
            'debit',0,'credit',amount)
        )
      );
      insert into public.finance_advance_movements(advance_id,movement_type,amount,
        source_type,source_id,payable_id,created_by,reason)
      values(advance.id,'SETTLEMENT',amount,'ADVANCE_SETTLEMENT',req::text,payable.id,actor,reason);
      insert into public.finance_payable_settlements(payable_id,amount,advance_id,settled_by,reason)
      values(payable.id,amount,advance.id,actor,'Advance application: '||reason);
      update public.finance_advances set status=case when public.advance_balance(id)=0
        then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=advance.id;
      update public.finance_payables p set status=case when
        coalesce((select sum(s.amount) from public.finance_payable_settlements s
          where s.payable_id=p.id),0)>=p.original_amount then 'SETTLED' else 'PARTIALLY_SETTLED' end
      where p.id=payable.id;
    result:=jsonb_build_object('id',advance.id,'message','Advance applied to payable.');

  end if;

  insert into public.audit_events(
    correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,action,reason,after_data,metadata
  )
  values(
    req,actor,(select id from public.staff where profile_id=actor limit 1),
    'FINANCE_ACCOUNTING',coalesce(result->>'id',req::text),action,reason,result,p_input
  );

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(req,actor,p_input,result);

  return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_paid(p_advance_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(amount),0)
  from public.finance_advance_movements
  where advance_id=p_advance_id and movement_type='PAYMENT';
$function$;

CREATE OR REPLACE FUNCTION public.finance_read_account_balance(p_account_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null or not public.has_permission('accounting.view') then
    raise exception 'Accounting view permission required.';
  end if;
  if p_account_id is null or p_as_of is null or not exists(
    select 1 from public.finance_accounts where id=p_account_id and is_active
  ) then raise exception 'Choose an active financial account and date.'; end if;
  return coalesce(public.finance_account_balance(p_account_id,p_as_of),0);
end $function$;

CREATE OR REPLACE FUNCTION public.referral_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 actor uuid:=auth.uid();
 action text:=p_input->>'action';
 req uuid:=nullif(p_input->>'request_id','')::uuid;
 reason text:=btrim(coalesce(p_input->>'reason',''));
 k public.admission_command_keys;
 a public.admission_cases;
 person public.referral_people;
 referral public.admission_referrals;
 award public.referral_bonus_awards;
 policy public.business_rule_versions;
 org uuid;
 first_month date;
 collected numeric;
 rate numeric;
 amount numeric;
 payable public.finance_payables;
 result jsonb;
begin
 if actor is null or req is null or length(reason)<5 then raise exception 'Sign in and provide a request ID and reason.'; end if;
 if action='CAPTURE' and not public.has_permission('admissions.create') or
    action='AWARD_BONUS' and not public.has_permission('staff.compensation.manage') or
    action not in('CAPTURE','AWARD_BONUS') then
   raise exception 'Permission denied for this referral action.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,7));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>actor or k.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
  return k.result;
 end if;
 if action='CAPTURE' then
  select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  if a.id is null or a.status='CANCELLED'
    or (a.status not in('DRAFT','READY') and exists(
      select 1 from public.admission_referrals prior where prior.admission_id=a.id
    )) then
   raise exception 'A referral can be added to an accepted case only when no source is already on file.'; end if;
  select id into org from public.organizations where code='SOHOJ' and is_active;
  if p_input->>'source'='ORGANIC' then
   insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
   values(a.id,'ORGANIC',null,actor,reason)
   on conflict(admission_id) do update set source='ORGANIC',referrer_id=null,captured_by=actor,captured_at=now(),reason=excluded.reason;
   delete from public.teacher_referrals where admission_id=a.id;
  elsif p_input->>'source'='REFERRED' then
   if nullif(p_input->>'staff_id','') is not null then
    if not exists(select 1 from public.staff where id=(p_input->>'staff_id')::uuid and status='ACTIVE') then
      raise exception 'Choose an active staff member.'; end if;
    insert into public.referral_people(organization_id,staff_id,full_name,mobile,created_by)
      select org,id,full_name,null,actor from public.staff where id=(p_input->>'staff_id')::uuid
    on conflict(staff_id) do update set full_name=excluded.full_name
    returning * into person;
   elsif nullif(p_input->>'referrer_id','') is not null then
    select * into person from public.referral_people
     where id=(p_input->>'referrer_id')::uuid and organization_id=org;
    if person.id is null then raise exception 'Choose an existing referrer.'; end if;
   else
    if length(btrim(coalesce(p_input->>'full_name','')))<2 or
       coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$' then
      raise exception 'Enter the new referrer name and an 11-digit Bangladesh mobile.';
    end if;
    insert into public.referral_people(organization_id,staff_id,full_name,mobile,relationship_note,contact_note,created_by)
    values(org,null,btrim(p_input->>'full_name'),p_input->>'mobile',
      nullif(btrim(p_input->>'relationship_note'),''),nullif(btrim(p_input->>'contact_note'),''),actor)
    on conflict(organization_id,mobile) do update set
      full_name=public.referral_people.full_name
    returning * into person;
    if lower(btrim(person.full_name))<>lower(btrim(p_input->>'full_name')) then
      raise exception 'A different referrer already uses this mobile. Select the existing record or verify identity.';
    end if;
   end if;
   insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
   values(a.id,'REFERRED',person.id,actor,reason)
   on conflict(admission_id) do update set source='REFERRED',referrer_id=excluded.referrer_id,
      captured_by=actor,captured_at=now(),reason=excluded.reason;
   if person.staff_id is not null and exists(select 1 from public.staff_role_assignments sra
      join public.staff_roles sr on sr.id=sra.staff_role_id
      where sra.staff_id=person.staff_id and sr.is_teaching_role) then
     insert into public.teacher_referrals(admission_id,teacher_id,captured_by,reason)
     values(a.id,person.staff_id,actor,reason)
     on conflict(admission_id) do update set teacher_id=excluded.teacher_id,captured_by=actor,captured_at=now(),reason=excluded.reason;
   else
     delete from public.teacher_referrals where admission_id=a.id;
   end if;
  else raise exception 'Select an existing or new referrer, or Organic.'; end if;
  result:=jsonb_build_object('id',a.id,'message','Admission referral choice saved.');
 elsif action='AWARD_BONUS' then
  select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  select * into referral from public.admission_referrals where admission_id=a.id;
  select * into person from public.referral_people where id=referral.referrer_id;
  if a.id is null or a.status<>'ACTIVE_ENROLLMENT' or referral.source<>'REFERRED'
    or person.id is null or person.staff_id is not null then
    raise exception 'Choose an active admission with an external referrer.'; end if;
  if exists(select 1 from public.referral_bonus_awards where admission_id=a.id and status in('PENDING','APPROVED')) then
   raise exception 'The referral reward is already requested or approved.'; end if;
  select min(n.billing_period) into first_month from public.finance_net_collected_tuition(date '2000-01-01',current_date) n
   where n.admission_id=a.id and n.tuition_collected>0;
  if first_month is null then raise exception 'No posted tuition collection qualifies for an acquisition reward.'; end if;
  select coalesce(sum(n.tuition_collected),0) into collected from public.finance_net_collected_tuition(first_month,(first_month+interval '1 month - 1 day')::date) n
   where n.admission_id=a.id;
  if collected<=0 then raise exception 'First-month net collected tuition is not positive.'; end if;
  select * into policy from public.business_rule_versions where domain='teacher_compensation'
   and rule_key='default_policy' and status='ACTIVE' order by version desc limit 1;
  if policy.id is null or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
   raise exception 'Configure a valid acquisition compensation policy first.'; end if;
  rate:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  amount:=round(collected*rate/100,2);
  if amount<=0 then raise exception 'The reward would be zero under the current policy.'; end if;
  select id into org from public.organizations where code='SOHOJ' and is_active;
  insert into public.referral_bonus_awards(admission_id,referrer_id,period_start,net_collected,policy_version_id,
    bonus_percent,amount,requested_by,status,reviewed_by,reviewed_at)
  values(a.id,person.id,first_month,collected,policy.id,rate,amount,actor,'APPROVED',actor,now()) returning * into award;
  insert into public.finance_payables(organization_id,payable_type,referrer_id,source_type,source_id,payable_account_id,original_amount,due_on,created_by)
  values(org,'OTHER',person.id,'REFERRAL_BONUS',a.id::text,
    (select id from public.finance_accounts where organization_id=org and code='2130'),amount,current_date,actor) returning * into payable;
  perform public.finance_post_journal(org,current_date,'COMPENSATION_RUN','REFERRAL_BONUS',award.id::text,
    reason,actor,jsonb_build_array(
      jsonb_build_object('account_id',(select id from public.finance_accounts where organization_id=org and code='5200'),'debit',amount,'credit',0),
      jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',amount)));
  update public.referral_bonus_awards set payable_id=payable.id where id=award.id;
  result:=jsonb_build_object('id',award.id,'message','Referral reward calculated and posted to payable.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ADMISSION_REFERRAL',result->>'id',action,reason,result,jsonb_build_object('module','referrals'));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end
$function$;

CREATE OR REPLACE FUNCTION public.finance_workspace()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.has_permission('finance.view') then raise exception 'Finance access denied.'; end if;
 return jsonb_build_object(
 'admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',coalesce(s.full_name,a.identity_snapshot->>'student_name'),'number',a.admission_no,'status',a.status,'studentId',s.id,'studentNo',s.student_no,'mobile',a.identity_snapshot->>'mobile') order by a.created_at desc) from public.admission_cases a left join public.students s on s.id=a.student_id),'[]'::jsonb),
 'years',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.academic_years),'[]'::jsonb),
 'terms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'startsOn',starts_on,'endsOn',ends_on,'dueOn',due_on)) from public.billing_terms),'[]'::jsonb),
 'invoices',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'admissionId',a.id,'name',a.identity_snapshot->>'student_name','number',i.invoice_no,'kind',i.invoice_kind,'period',i.billing_period,'dueOn',i.due_on,'currency',i.currency_code,'gross',b.gross,'credits',b.credits,'net',b.net,'paid',b.paid,'refunded',b.refunded,'due',b.due,'credit',b.credit_balance,'reserved',b.reserved_refunds,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('name',name,'amount',amount)) from public.admission_invoice_lines where invoice_id=i.id),'[]'::jsonb)) order by i.posted_at desc) from public.admission_invoices i join public.admission_cases a on a.id=i.admission_id cross join lateral public.invoice_balance(i.id) b),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'invoiceId',pa.invoice_id,'number',p.receipt_no,'amount',p.amount,'postedAt',p.posted_at,'method',pm.name,'remaining',p.amount-coalesce((select sum(amount) from public.refund_authorizations where payment_id=p.id),0))) from public.admission_payments p join public.admission_payment_allocations pa on pa.payment_id=p.id join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'discounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'kind',kind,'value',value,'startsOn',starts_on,'endsOn',ends_on)) from public.admission_discounts),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'invoiceId',r.invoice_id,'paymentId',r.payment_id,'amount',r.amount,'number',p.refund_no,'postedAt',p.posted_at,'method',pm.name,'reference',p.external_reference)) from public.refund_authorizations r left join public.refund_payouts p on p.authorization_id=r.id left join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'runs',coalesce((select jsonb_agg(jsonb_build_object('id',id,'period',period,'count',invoice_count,'gross',gross_total,'postedAt',posted_at) order by posted_at desc) from public.billing_runs),'[]'::jsonb),
 'paymentMethods',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb)
 );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_finance_adjustment(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  a public.admission_cases;
  i public.admission_invoices;
  payment public.admission_payments;
  discount public.admission_discounts;
  cancellation public.admission_cancellations;
  refund_auth public.refund_authorizations;
  payout public.refund_payouts;
  balance record;
  invoice_allocation numeric;
  reserved numeric;
  amount numeric;
  kind text;
  value numeric;
  start_date date;
  end_date date;
  settlement text;
  payment_method uuid;
  today date;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
begin
  if actor is null then
    raise exception 'Sign in to continue.';
  end if;

  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason are required.';
  end if;

  if action not in ('APPLY_DISCOUNT','CANCEL_ADMISSION','REFUND') then
    raise exception 'Unsupported finance adjustment.';
  end if;

  if action='APPLY_DISCOUNT' and not public.has_permission('finance.billing.manage') then
    raise exception 'Billing management permission required.';
  end if;

  if action='CANCEL_ADMISSION' and not public.has_permission('admissions.create') then
    raise exception 'Admission management permission required.';
  end if;

  if action='REFUND' and not public.has_permission('finance.payments.post') then
    raise exception 'Payment posting permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,0));

  select * into key
  from public.admission_command_keys
  where request_id=req;

  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select * into a
  from public.admission_cases
  where id=nullif(p_input->>'admission_id','')::uuid
  for update;

  if action in ('APPLY_DISCOUNT','CANCEL_ADMISSION') and a.id is null then
    raise exception 'Admission not found.';
  end if;

  if a.id is not null then
    select (now() at time zone o.timezone)::date
    into today
    from public.batches b
    join public.organizations o on o.id=b.organization_id
    where b.id=a.batch_id;
  end if;

  if action='APPLY_DISCOUNT' then
    kind:=p_input->>'kind';
    value:=(p_input->>'value')::numeric;
    start_date:=(p_input->>'starts_on')::date;
    end_date:=(p_input->>'ends_on')::date;

    if a.status='CANCELLED'
      or kind not in ('PERCENT','FIXED')
      or value is null
      or value<=0
      or value<>round(value,2)
      or value>9999999999.99
      or (kind='PERCENT' and value>100)
      or start_date is null
      or end_date is null
      or end_date<start_date
    then
      raise exception 'Enter a valid discount and effective period.';
    end if;

    if exists(
      select 1
      from public.admission_discounts d
      where d.admission_id=a.id
        and daterange(d.starts_on,d.ends_on,'[]')
          && daterange(start_date,end_date,'[]')
    ) then
      raise exception 'Discount overlaps an existing discount. Use a non-overlapping period.';
    end if;

    before_data:=jsonb_build_object(
      'admission_id',a.id,
      'status',a.status
    );

    insert into public.admission_discounts(admission_id, authorized_by, authorization_reason, correlation_id, kind, value, starts_on, ends_on)
    values(a.id, actor, reason, req, kind, value, start_date, end_date)
    returning * into discount;

    for i in
      select *
      from public.admission_invoices
      where admission_id=a.id
        and billing_period between start_date and end_date
    loop
      perform public.apply_invoice_discounts(i.id);
    end loop;

    after_data:=jsonb_build_object(
      'discount_id',discount.id,
      'admission_id',a.id,
      'kind',discount.kind,
      'value',discount.value,
      'starts_on',discount.starts_on,
      'ends_on',discount.ends_on
    );

    result:=jsonb_build_object(
      'id',discount.id,
      'message','Discount applied and recorded.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'ADMISSION_DISCOUNT',a.id::text,'APPLY_DISCOUNT',reason,
      before_data,after_data,jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='CANCEL_ADMISSION' then
    settlement:=p_input->>'settlement';

    if a.status='CANCELLED'
      or settlement not in ('KEEP_CHARGES','CREDIT_ALL')
    then
      raise exception 'Choose a valid cancellation settlement for an open admission.';
    end if;

    if exists(
      select 1 from public.admission_cancellations
      where admission_id=a.id
    ) then
      raise exception 'Admission cancellation is already recorded.';
    end if;

    before_data:=jsonb_build_object(
      'admission_id',a.id,
      'status',a.status,
      'enrollment_id',a.enrollment_id
    );

    insert into public.admission_cancellations(admission_id, cancelled_by, cancellation_reason, correlation_id, settlement)
    values(a.id, actor, reason, req, settlement)
    returning * into cancellation;

    if settlement='CREDIT_ALL' then
      for i in
        select *
        from public.admission_invoices
        where admission_id=a.id
      loop
        select * into balance
        from public.invoice_balance(i.id);

        if balance.net>0 then
          insert into public.invoice_credits(invoice_id, kind, amount, applied_by)
          values(i.id, 'CANCELLATION', balance.net, actor)
          on conflict (invoice_id)
            where kind='CANCELLATION'
          do nothing;
        end if;
      end loop;
    end if;

    update public.admission_cases
    set status='CANCELLED'
    where id=a.id;

    update public.enrollments
    set status='WITHDRAWN',
        ended_on=today
    where id=a.enrollment_id
      and status='ACTIVE';

    if a.student_id is not null
      and not exists(
        select 1
        from public.enrollments
        where student_id=a.student_id
          and status='ACTIVE'
      )
    then
      update public.students
      set status='INACTIVE'
      where id=a.student_id;
    end if;

    after_data:=jsonb_build_object(
      'cancellation_id',cancellation.id,
      'admission_id',a.id,
      'status','CANCELLED',
      'settlement',settlement
    );

    result:=jsonb_build_object(
      'id',cancellation.id,
      'message','Admission cancelled and recorded.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'ADMISSION_CANCELLATION',a.id::text,'CANCEL_ADMISSION',reason,
      before_data,after_data,jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  else
    select * into payment
    from public.admission_payments
    where id=nullif(p_input->>'payment_id','')::uuid
    for update;

    select * into i
    from public.admission_invoices
    where id=nullif(p_input->>'invoice_id','')::uuid
    for update;

    amount:=(p_input->>'amount')::numeric;
    payment_method:=nullif(p_input->>'payment_method_id','')::uuid;

    if payment.id is null or i.id is null then
      raise exception 'Payment or invoice not found.';
    end if;

    if not exists(
      select 1
      from public.admission_payment_allocations pa
      where pa.payment_id=payment.id
        and pa.invoice_id=i.id
    ) then
      raise exception 'The selected payment is not allocated to this invoice.';
    end if;

    select coalesce(sum(pa.amount),0)
    into invoice_allocation
    from public.admission_payment_allocations pa
    where pa.payment_id=payment.id
      and pa.invoice_id=i.id;

    select coalesce(sum(r.amount),0)
    into reserved
    from public.refund_authorizations r
    where r.payment_id=payment.id;

    select * into balance
    from public.invoice_balance(i.id);

    if amount is null
      or amount<=0
      or amount<>round(amount,2)
      or payment_method is null
      or amount>payment.amount-reserved
      or amount>invoice_allocation
      or amount>balance.credit_balance-balance.reserved_refunds
    then
      raise exception 'Refund exceeds the unreserved eligible credit for this payment and invoice.';
    end if;

    if not exists(
      select 1
      from public.payment_methods
      where id=payment_method
        and is_active
    ) then
      raise exception 'Choose an active refund payment method.';
    end if;

    before_data:=jsonb_build_object(
      'payment_id',payment.id,
      'invoice_id',i.id,
      'amount_received',payment.amount,
      'invoice_credit',balance.credit_balance
    );

    insert into public.refund_authorizations(payment_id, invoice_id, amount, authorized_by, authorization_reason, correlation_id)
    values(payment.id, i.id, amount, actor, reason, req)
    returning * into refund_auth;

    insert into public.refund_payouts(
      authorization_id,
      payment_method_id,
      external_reference,
      posted_by,
      reason
    )
    values(
      refund_auth.id,
      payment_method,
      nullif(btrim(coalesce(p_input->>'external_reference','')),''),
      actor,
      reason
    )
    returning * into payout;

    after_data:=jsonb_build_object(
      'refund_authorization_id',refund_auth.id,
      'refund_id',payout.id,
      'refund_no',payout.refund_no,
      'invoice_id',i.id,
      'payment_id',payment.id,
      'amount',amount
    );

    result:=jsonb_build_object(
      'id',payout.id,
      'refund_no',payout.refund_no,
      'message','Actual refund posted: '||payout.refund_no||'.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'REFUND',payout.id::text,'POST_REFUND',reason,
      before_data,after_data,jsonb_build_object(
        'finance_flow','V3_DIRECT_ADMIN',
        'invoice_id',i.id,
        'payment_id',payment.id
      )
    );
  end if;

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(req,actor,p_input,result);

  return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_accounting_operation(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  org uuid;
  result jsonb;
  amount numeric;
  payment_account uuid;
  advance public.finance_advances;
  expense public.finance_expenses;
  category public.finance_expense_categories;
  payable public.finance_payables;
  compensation public.teacher_compensation_runs;
  policy public.business_rule_versions;
  preview jsonb;
  line jsonb;
  v_teacher_id uuid;
  teacher_total numeric;
  decision text;
  adjustment_id uuid;
begin
  if actor is null then
    raise exception 'Sign in to continue.';
  end if;

  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason of at least five characters are required.';
  end if;

  if action not in (
    'CREATE_ADVANCE',
    'CREATE_EXPENSE_DIRECT',
    'RUN_COMPENSATION',
    'APPLY_COMP_ADJUSTMENT'
  ) then
    raise exception 'Unsupported V3 accounting action.';
  end if;

  if action='CREATE_ADVANCE'
    and not public.has_permission('finance.advances.manage') then
    raise exception 'Advance management permission required.';
  end if;

  if action='CREATE_EXPENSE_DIRECT'
    and not public.has_permission('accounting.expense.manage') then
    raise exception 'Expense management permission required.';
  end if;

  if action in ('RUN_COMPENSATION','APPLY_COMP_ADJUSTMENT')
    and not public.has_permission('staff.compensation.manage') then
    raise exception 'Teacher compensation management permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,9));

  select * into key
  from public.admission_command_keys
  where request_id=req;

  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select id into org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  if action='CREATE_ADVANCE' then
    if p_input->>'beneficiary_type' not in ('STAFF','VENDOR','PROJECT') then
      raise exception 'Choose staff, vendor or project as the advance beneficiary.';
    end if;

    amount:=(p_input->>'requested_amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Advance amount must be a positive two-decimal amount.';
    end if;

    if p_input->>'beneficiary_type'='STAFF' and not exists(
      select 1 from public.staff
      where id=nullif(p_input->>'staff_id','')::uuid
        and organization_id=org
        and status='ACTIVE'
    ) then
      raise exception 'Choose an active staff member.';
    end if;

    if p_input->>'beneficiary_type'='VENDOR' and not exists(
      select 1 from public.vendors
      where id=nullif(p_input->>'vendor_id','')::uuid
        and organization_id=org
        and is_active
    ) then
      raise exception 'Choose an active vendor.';
    end if;

    if p_input->>'beneficiary_type'='PROJECT'
      and nullif(btrim(p_input->>'project_reference'),'') is null then
      raise exception 'Project reference is required for a project advance.';
    end if;

    if length(btrim(coalesce(p_input->>'purpose','')))<5 then
      raise exception 'Advance purpose must be at least five characters.';
    end if;

    insert into public.finance_advances(
      organization_id,
      beneficiary_type,
      staff_id,
      vendor_id,
      project_reference,
      purpose,
      requested_amount,
      approved_amount,
      expected_settlement_date,
      requested_by,
      authorized_by,
      authorization_reason,
      status
    )
    values(
      org,
      p_input->>'beneficiary_type',
      nullif(p_input->>'staff_id','')::uuid,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(btrim(p_input->>'project_reference'),''),
      btrim(p_input->>'purpose'),
      amount,
      amount,
      nullif(p_input->>'expected_settlement_date','')::date,
      actor,
      actor,
      reason,
      'APPROVED'
    )
    returning * into advance;

    result:=jsonb_build_object(
      'id',advance.id,
      'advanceNo',advance.advance_no,
      'message','Advance authorized and recorded.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'FINANCE_ADVANCE',
      advance.id::text,
      'CREATE_ADVANCE',
      reason,
      jsonb_build_object(
        'advance_no',advance.advance_no,
        'beneficiary_type',advance.beneficiary_type,
        'requested_amount',advance.requested_amount,
        'approved_amount',advance.approved_amount,
        'status',advance.status
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='CREATE_EXPENSE_DIRECT' then
    amount:=(p_input->>'amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Expense amount must be a positive two-decimal amount.';
    end if;

    select * into category
    from public.finance_expense_categories
    where id=nullif(p_input->>'category_id','')::uuid
      and organization_id=org
      and is_active;

    if category.id is null then
      raise exception 'Choose an active expense category.';
    end if;

    if p_input->>'payment_mode' not in ('PAID_NOW','ON_ACCOUNT') then
      raise exception 'Choose whether the expense is paid now or payable later.';
    end if;

    if length(btrim(coalesce(p_input->>'description','')))<3 then
      raise exception 'Expense description is required.';
    end if;

    if p_input->>'payment_mode'='PAID_NOW' then
      select id into payment_account
      from public.finance_accounts
      where id=nullif(p_input->>'payment_account_id','')::uuid
        and organization_id=org
        and account_subtype in ('CASH','BANK','MOBILE_BANK')
        and is_active;

      if payment_account is null then
        raise exception 'Choose an active cash or bank account for a paid expense.';
      end if;
    else
      payment_account:=null;
    end if;

    insert into public.finance_expenses(organization_id, expense_date, category_id, expense_account_id, payment_mode, payment_account_id, vendor_id, staff_id, amount, description, receipt_reference, status, authorized_by, authorization_reason, submitted_by, posted_by, posted_at)
    values(org, coalesce(nullif(p_input->>'expense_date','')::date,current_date), category.id, category.expense_account_id, p_input->>'payment_mode', payment_account, nullif(p_input->>'vendor_id','')::uuid, nullif(p_input->>'staff_id','')::uuid, amount, btrim(p_input->>'description'), nullif(btrim(p_input->>'receipt_reference'),''), 'POSTED', actor, reason, actor, actor, now())
    returning * into expense;

    if expense.payment_mode='PAID_NOW' then
      perform public.finance_post_journal(
        org,
        expense.expense_date,
        'EXPENSE',
        'EXPENSE',
        expense.id::text,
        'Expense '||expense.expense_no,
        actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',expense.expense_account_id,
            'debit',expense.amount,
            'credit',0,
            'memo',expense.description
          ),
          jsonb_build_object(
            'account_id',payment_account,
            'debit',0,
            'credit',expense.amount,
            'memo',coalesce(expense.receipt_reference,'Paid expense')
          )
        )
      );
    else
      insert into public.finance_payables(
        organization_id,
        payable_type,
        staff_id,
        vendor_id,
        source_type,
        source_id,
        payable_account_id,
        original_amount,
        due_on,
        created_by
      )
      values(
        org,
        case
          when expense.vendor_id is not null then 'VENDOR'
          when expense.staff_id is not null then 'STAFF_REIMBURSEMENT'
          else 'OTHER'
        end,
        expense.staff_id,
        expense.vendor_id,
        'EXPENSE',
        expense.id::text,
        case
          when expense.vendor_id is not null then
            (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1)
          else
            (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYABLE' limit 1)
        end,
        expense.amount,
        expense.expense_date+30,
        actor
      )
      returning * into payable;

      update public.finance_expenses
      set payable_id=payable.id
      where id=expense.id;

      perform public.finance_post_journal(
        org,
        expense.expense_date,
        'EXPENSE',
        'EXPENSE',
        expense.id::text,
        'Expense payable '||expense.expense_no,
        actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',expense.expense_account_id,
            'debit',expense.amount,
            'credit',0,
            'memo',expense.description
          ),
          jsonb_build_object(
            'account_id',payable.payable_account_id,
            'debit',0,
            'credit',expense.amount,
            'memo','Payable for expense '||expense.expense_no
          )
        )
      );
    end if;

    result:=jsonb_build_object(
      'id',expense.id,
      'expenseNo',expense.expense_no,
      'message','Expense posted to the ledger.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'FINANCE_EXPENSE',
      expense.id::text,
      'CREATE_EXPENSE_DIRECT',
      reason,
      jsonb_build_object(
        'expense_no',expense.expense_no,
        'amount',expense.amount,
        'payment_mode',expense.payment_mode,
        'status',expense.status
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='RUN_COMPENSATION' then
    preview:=public.teacher_compensation_preview(
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date
    );

    if jsonb_array_length(preview->'rows')=0 then
      raise exception 'No eligible compensation lines for this period.';
    end if;

    select * into policy
    from public.business_rule_versions
    where domain='teacher_compensation'
      and rule_key='default_policy'
      and status='ACTIVE'
    order by version desc
    limit 1;

    if policy.id is null then
      raise exception 'No active teacher compensation policy is configured.';
    end if;

    insert into public.teacher_compensation_runs(
      organization_id,
      period_start,
      period_end,
      policy_version_id,
      status,
      total_amount,
      submitted_by,
      approved_by,
      approved_at,
      authorized_by,
      authorization_reason
    )
    values(
      org,
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date,
      policy.id,
      'APPROVED',
      (preview->>'total')::numeric,
      actor,
      actor,
      now(),
      actor,
      reason
    )
    returning * into compensation;

    for line in
      select value
      from jsonb_array_elements(preview->'rows')
    loop
      insert into public.teacher_compensation_lines(
        run_id,
        teacher_id,
        admission_id,
        line_type,
        source_type,
        source_id,
        amount,
        calculation
      )
      values(
        compensation.id,
        (line->>'teacherId')::uuid,
        nullif(line->>'admissionId','')::uuid,
        line->>'lineType',
        line->>'sourceType',
        line->>'sourceId',
        (line->>'amount')::numeric,
        coalesce(line->'calculation','{}'::jsonb)
      )
      on conflict(run_id,source_type,source_id) do nothing;
    end loop;

    for v_teacher_id in
      select distinct l.teacher_id
      from public.teacher_compensation_lines l
      where l.run_id=compensation.id
    loop
      select coalesce(sum(l.amount),0)
      into teacher_total
      from public.teacher_compensation_lines l
      where l.run_id=compensation.id
        and l.teacher_id=v_teacher_id;

      if teacher_total>0 then
        insert into public.finance_payables(
          organization_id,
          payable_type,
          staff_id,
          source_type,
          source_id,
          payable_account_id,
          original_amount,
          due_on,
          created_by
        )
        values(
          org,
          'TEACHER_COMPENSATION',
          v_teacher_id,
          'COMPENSATION_RUN',
          compensation.id::text||':'||v_teacher_id::text,
          (
            select id
            from public.finance_accounts
            where organization_id=org
              and account_subtype='TEACHER_PAYABLE'
            limit 1
          ),
          teacher_total,
          compensation.period_end,
          actor
        )
        on conflict(source_type,source_id) do nothing;
      end if;
    end loop;

    perform public.finance_post_journal(
      org,
      compensation.period_end,
      'COMPENSATION_RUN',
      'COMPENSATION_RUN',
      compensation.id::text,
      'Teacher compensation run '||compensation.run_no,
      actor,
      (
        select jsonb_build_array(
          jsonb_build_object(
            'account_id',(
              select id
              from public.finance_accounts
              where organization_id=org
                and account_subtype='TEACHING_COMPENSATION'
              limit 1
            ),
            'debit',compensation.total_amount,
            'credit',0,
            'memo','Teaching compensation expense'
          )
        ) ||
        coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'account_id',(
                select id
                from public.finance_accounts
                where organization_id=org
                  and account_subtype='TEACHER_PAYABLE'
                limit 1
              ),
              'debit',0,
              'credit',sum(l.amount),
              'memo','Payable for teacher '||l.teacher_id::text
            )
          )
          from public.teacher_compensation_lines l
          where l.run_id=compensation.id
          group by l.teacher_id
        ),'[]'::jsonb)
      )
    );

    result:=jsonb_build_object(
      'id',compensation.id,
      'runNo',compensation.run_no,
      'message','Teacher compensation run approved and posted.',
      'total',compensation.total_amount
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'TEACHER_COMPENSATION_RUN',
      compensation.id::text,
      'RUN_COMPENSATION',
      reason,
      jsonb_build_object(
        'run_no',compensation.run_no,
        'status',compensation.status,
        'total_amount',compensation.total_amount
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  else
    if not exists(
      select 1
      from public.staff
      where id=nullif(p_input->>'teacher_id','')::uuid
        and status='ACTIVE'
    ) then
      raise exception 'Choose an active teacher.';
    end if;

    amount:=(p_input->>'amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Adjustment amount must be a positive two-decimal amount.';
    end if;

    if (p_input->>'effective_period')::date is null then
      raise exception 'Choose an effective period.';
    end if;

    insert into public.teacher_compensation_adjustments(teacher_id, amount, adjustment_type, effective_period, reason, authorized_by, authorization_reason, status, requested_by, approved_by, approved_at)
    values((p_input->>'teacher_id')::uuid, amount, coalesce(p_input->>'adjustment_type','ADJUSTMENT'), (p_input->>'effective_period')::date, reason, actor, reason, 'APPROVED', actor, actor, now())
    returning id into adjustment_id;

    result:=jsonb_build_object(
      'id',adjustment_id,
      'message','Teacher compensation adjustment authorized and recorded.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'TEACHER_COMPENSATION_ADJUSTMENT',
      adjustment_id::text,
      'APPLY_COMP_ADJUSTMENT',
      reason,
      jsonb_build_object(
        'teacher_id',(p_input->>'teacher_id')::uuid,
        'amount',amount,
        'effective_period',(p_input->>'effective_period')::date,
        'status','APPROVED'
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );
  end if;

  insert into public.admission_command_keys(
    request_id,actor_id,payload,result
  )
  values(req,actor,p_input,result);

  return result;
end;
$function$;
