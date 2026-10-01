insert into public.permissions(code,name,description) values('payroll.manage','Manage staff payroll','Preview, post and settle staff payroll') on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code in('ADMIN','ACCOUNTANT') and p.code='payroll.manage' on conflict do nothing;
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'2140','Staff Salary Payable','LIABILITY','STAFF_SALARY_PAYABLE',true from public.organizations where code='SOHOJ' on conflict(organization_id,code) do nothing;
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'5300','Staff Fixed and Hourly Payroll','EXPENSE','STAFF_PAYROLL_EXPENSE',true from public.organizations where code='SOHOJ' on conflict(organization_id,code) do nothing;
alter table public.finance_payables drop constraint finance_payables_payable_type_check;
alter table public.finance_payables add constraint finance_payables_payable_type_check check(payable_type in('TEACHER_COMPENSATION','VENDOR','STAFF_REIMBURSEMENT','OTHER','STAFF_PAYROLL'));
create sequence public.staff_payroll_no_seq;
create table public.staff_payroll_records(
 id uuid primary key default gen_random_uuid(),payroll_no text not null unique default ('SAL-'||lpad(nextval('public.staff_payroll_no_seq')::text,6,'0')),staff_id uuid not null references public.staff(id),month date not null check(extract(day from month)=1),
 payable_id uuid not null unique references public.finance_payables(id),snapshot jsonb not null,
 gross numeric(14,2) not null check(gross>0),corrections numeric(14,2) not null check(corrections>=0),net numeric(14,2) not null check(net>0 and net=gross-corrections),
 due_on date not null,posted_by uuid not null references public.profiles(id),posted_at timestamptz not null default now(),reason text not null,unique(staff_id,month)
);
alter table public.staff_payroll_records enable row level security;
create policy payroll_read_scope on public.staff_payroll_records for select to authenticated using(public.has_permission('payroll.manage') or (public.has_permission('workforce.self.view') and staff_id in(select id from public.staff where profile_id=auth.uid())));
grant select on public.staff_payroll_records to authenticated;
revoke insert,update,delete on public.staff_payroll_records from authenticated,anon;
create trigger payroll_no_change before update or delete on public.staff_payroll_records for each row execute function public.prevent_permanent_record_delete();

create function public.staff_payroll_preview(p_input jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid:=(p_input->>'staff_id')::uuid;month_value date:=(p_input->>'month')::date;last_day date;eligible date;terms public.staff_compensation_terms;person public.staff;hours numeric:=0;base numeric:=0;hourly numeric:=0;allowance numeric:=0;corrections numeric:=0;item jsonb;attendance jsonb;snapshot jsonb;
begin
 if auth.uid() is null or not public.has_permission('payroll.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Payroll management permission required.';end if;
 if month_value is null or extract(day from month_value)<>1 or month_value>date_trunc('month',now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose a current or previous payroll month.';end if;
 last_day:=(month_value+interval '1 month')::date;
 select * into person from public.staff where id=sid and status in('ACTIVE','ON_LEAVE');if person.id is null then raise exception 'Choose current staff.';end if;
 select * into terms from public.staff_compensation_terms where staff_id=sid;if terms.staff_id is null then raise exception 'Configure agreed compensation terms before payroll.';end if;
 if terms.model='REVENUE_SHARE' then raise exception 'Revenue-share-only earnings use the teaching compensation and referral workflows.';end if;
 eligible:=greatest(month_value,terms.effective_from,coalesce(person.joined_on,month_value));
 if eligible>=last_day then raise exception 'Current agreement or join date does not cover this month. Resolve historical terms before posting.';end if;
 if jsonb_typeof(coalesce(p_input->'allowances','[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_input->'corrections','[]'::jsonb))<>'array' then raise exception 'Provide itemised allowances and corrections.';end if;
 if jsonb_array_length(coalesce(p_input->'allowances','[]'::jsonb))>20 or jsonb_array_length(coalesce(p_input->'corrections','[]'::jsonb))>20 then raise exception 'Too many payroll items.';end if;
 for item in select value from jsonb_array_elements(coalesce(p_input->'allowances','[]'::jsonb)) loop
 if coalesce(length(btrim(item->>'label')),0)<3 or coalesce((item->>'amount')::numeric,0)<=0 or (item->>'amount')::numeric<>round((item->>'amount')::numeric,2) then raise exception 'Each allowance needs an explanation and positive amount.';end if;allowance:=allowance+round((item->>'amount')::numeric,2);end loop;
 for item in select value from jsonb_array_elements(coalesce(p_input->'corrections','[]'::jsonb)) loop
 if coalesce(length(btrim(item->>'label')),0)<5 or item->>'kind' not in('UNPAID_LEAVE','ABSENCE','EARNING_CORRECTION') or coalesce((item->>'amount')::numeric,0)<=0 or (item->>'amount')::numeric<>round((item->>'amount')::numeric,2) then raise exception 'Each earning correction needs a supported type, explanation and positive amount.';end if;corrections:=corrections+round((item->>'amount')::numeric,2);end loop;
 select coalesce(sum(case when status='PRESENT' then extract(epoch from ended_at-started_at)/3600-break_minutes/60.0 else 0 end),0),coalesce(jsonb_agg(to_jsonb(a) order by work_date),'[]'::jsonb) into hours,attendance from public.staff_attendance_records a where staff_id=sid and work_date>=eligible and work_date<last_day;
 base:=round(terms.monthly_base*(last_day-eligible)::numeric/(last_day-month_value),2);hourly:=round(hours*terms.hourly_rate,2);
 snapshot:=jsonb_build_object('staffId',sid,'name',person.full_name,'number',person.staff_no,'month',month_value,'eligibleFrom',eligible,'terms',to_jsonb(terms),'hours',round(hours,4),'base',base,'hourly',hourly,'allowances',coalesce(p_input->'allowances','[]'::jsonb),'correctionItems',coalesce(p_input->'corrections','[]'::jsonb),'allowanceTotal',allowance,'gross',base+hourly+allowance,'corrections',corrections,'net',base+hourly+allowance-corrections,'attendance',attendance,'dueOn',last_day+(terms.pay_day-1),'canPost',last_day<=(now() at time zone 'Asia/Dhaka')::date);
 if (snapshot->>'net')::numeric<=0 then raise exception 'Net payroll must be positive. Review the agreement, hours and earning corrections.';end if;
 return snapshot||jsonb_build_object('token',md5(snapshot::text));
end $$;
revoke all on function public.staff_payroll_preview(jsonb) from public,anon;
grant execute on function public.staff_payroll_preview(jsonb) to authenticated;

create function public.staff_payroll_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();request uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');key public.admission_command_keys;preview jsonb;org uuid;expense_account uuid;salary_account uuid;advance_account uuid;record public.staff_payroll_records;payable public.finance_payables;advance public.finance_advances;cash numeric;offset_amount numeric;remaining numeric;account uuid;journal_lines jsonb;result jsonb;
begin
 if actor is null or not public.has_permission('payroll.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Payroll management permission required.';end if;
 if request is null or coalesce(length(reason),0)<5 then raise exception 'Request identity and reason are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(request::text,0));select * into key from public.admission_command_keys where request_id=request;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select id into salary_account from public.finance_accounts where organization_id=org and account_subtype='STAFF_SALARY_PAYABLE' and is_active;
 select id into expense_account from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYROLL_EXPENSE' and is_active;
 if action='POST' then
  perform 1 from public.staff where id=(p_input->>'staff_id')::uuid for update;
  preview:=public.staff_payroll_preview(p_input);
  if not (preview->>'canPost')::boolean then raise exception 'A current-month preview is provisional. Post after the month has ended; use advances for earlier payments.';end if;
  if preview->>'token' is distinct from p_input->>'preview_token' then raise exception 'Attendance or agreed terms changed. Review a fresh preview before posting.';end if;
  if preview->'terms'->>'model' in('FIXED','HOURLY') and exists(select 1 from public.teacher_compensation_lines l join public.teacher_compensation_runs r on r.id=l.run_id where l.teacher_id=(p_input->>'staff_id')::uuid and r.status='APPROVED' and l.line_type='TEACHING_REMUNERATION' and r.period_start<(preview->>'month')::date+interval '1 month' and r.period_end>=(preview->>'month')::date) then raise exception 'Teaching-pool remuneration was already posted for this period. Resolve the agreement; use HYBRID only when both bases were agreed.';end if;
  if exists(select 1 from public.staff_payroll_records where staff_id=(p_input->>'staff_id')::uuid and month=(p_input->>'month')::date) then raise exception 'Payroll is already posted for this staff and month.';end if;
  record.id:=gen_random_uuid();
  insert into public.finance_payables(organization_id,payable_type,staff_id,source_type,source_id,payable_account_id,original_amount,due_on,created_by)
  values(org,'STAFF_PAYROLL',(p_input->>'staff_id')::uuid,'STAFF_PAYROLL',record.id::text,salary_account,(preview->>'net')::numeric,(preview->>'dueOn')::date,actor) returning * into payable;
  insert into public.staff_payroll_records(id,staff_id,month,payable_id,snapshot,gross,corrections,net,due_on,posted_by,reason)
  values(record.id,(p_input->>'staff_id')::uuid,(p_input->>'month')::date,payable.id,preview,(preview->>'gross')::numeric,(preview->>'corrections')::numeric,(preview->>'net')::numeric,(preview->>'dueOn')::date,actor,reason) returning * into record;
  perform public.finance_post_journal(org,(now() at time zone 'Asia/Dhaka')::date,'COMPENSATION_RUN','STAFF_PAYROLL',record.id::text,'Staff payroll '||(preview->>'number')||' '||(preview->>'month'),actor,jsonb_build_array(jsonb_build_object('account_id',expense_account,'debit',record.net,'credit',0),jsonb_build_object('account_id',salary_account,'debit',0,'credit',record.net)));
 elsif action='SETTLE' then
  select * into record from public.staff_payroll_records where id=(p_input->>'id')::uuid for update;if record.id is null then raise exception 'Payroll record unavailable.';end if;
  select * into payable from public.finance_payables where id=record.payable_id for update;
  remaining:=payable.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=payable.id),0);
  cash:=coalesce((p_input->>'cash')::numeric,0);offset_amount:=coalesce((p_input->>'advance_offset')::numeric,0);
  if cash<>round(cash,2) or offset_amount<>round(offset_amount,2) or cash<0 or offset_amount<0 or cash+offset_amount<=0 or cash+offset_amount>remaining then raise exception 'Cash plus advance offset must fit the remaining payable.';end if;
  journal_lines:=jsonb_build_array(jsonb_build_object('account_id',payable.payable_account_id,'debit',cash+offset_amount,'credit',0));
  if cash>0 then
   select id into account from public.finance_accounts where id=(p_input->>'account_id')::uuid and organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');
   if account is null or coalesce(length(btrim(p_input->>'reference')),0)<3 then raise exception 'Choose the actual payment account and payment reference.';end if;
   insert into public.finance_payable_settlements(payable_id,amount,payment_account_id,external_reference,settled_by,reason) values(payable.id,cash,account,p_input->>'reference',actor,reason);
   journal_lines:=journal_lines||jsonb_build_array(jsonb_build_object('account_id',account,'debit',0,'credit',cash));
  end if;
  if offset_amount>0 then
   select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
   if advance.id is null or advance.staff_id is distinct from record.staff_id or advance.beneficiary_type<>'STAFF' or advance.status not in('PAID','PARTIALLY_SETTLED') or public.advance_balance(advance.id)<offset_amount then raise exception 'Choose a paid advance belonging to this staff member with enough balance.';end if;
   select id into advance_account from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' and is_active;
   insert into public.finance_payable_settlements(payable_id,amount,advance_id,settled_by,reason) values(payable.id,offset_amount,advance.id,actor,reason);
   insert into public.finance_advance_movements(advance_id,movement_type,amount,source_type,source_id,created_by,reason) values(advance.id,'SETTLEMENT',offset_amount,'STAFF_PAYROLL',request::text,actor,reason);
   update public.finance_advances set status=case when public.advance_balance(id)=0 then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=advance.id;
   journal_lines:=journal_lines||jsonb_build_array(jsonb_build_object('account_id',advance_account,'debit',0,'credit',offset_amount));
  end if;
  perform public.finance_post_journal(org,(now() at time zone 'Asia/Dhaka')::date,'COMPENSATION_SETTLEMENT','STAFF_PAYROLL_SETTLEMENT',request::text,'Payroll settlement '||record.id::text,actor,journal_lines);
  update public.finance_payables set status=case when cash+offset_amount=remaining then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=payable.id;
 else raise exception 'Unknown payroll action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'STAFF_PAYROLL',record.id::text,action,reason,jsonb_build_object('net',record.net,'cash',cash,'advanceOffset',offset_amount),request);
 result:=jsonb_build_object('id',record.id,'ok',true);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(request,actor,p_input,result);return result;
end $$;
revoke all on function public.staff_payroll_command(jsonb) from public,anon;
grant execute on function public.staff_payroll_command(jsonb) to authenticated;

create function public.staff_payroll_workspace(p_id uuid default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('payroll.manage');sid uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Payroll access required.';end if;
 select id into sid from public.staff where profile_id=auth.uid();
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Invalid page.';end if;
 if p_id is not null and not exists(select 1 from public.staff_payroll_records where id=p_id and (manager or staff_id=sid)) then raise exception 'Payslip unavailable.';end if;
 select count(*) into total from public.staff_payroll_records where (manager or staff_id=sid) and (p_id is null or id=p_id);
 select coalesce(jsonb_agg(to_jsonb(r) order by r.month desc,r.id),'[]'::jsonb) into rows from(select r.*,p.status,coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0) settled,
 (select coalesce(jsonb_agg(jsonb_build_object('date',s.settled_at,'amount',s.amount,'offset',s.advance_id is not null,'reference',s.external_reference) order by s.settled_at),'[]'::jsonb) from public.finance_payable_settlements s where s.payable_id=r.payable_id) payments
 from public.staff_payroll_records r join public.finance_payables p on p.id=r.payable_id where (manager or r.staff_id=sid) and (p_id is null or r.id=p_id) order by r.month desc,r.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('manager',manager,'total',total,'records',rows,
 'people',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no) order by full_name),'[]'::jsonb) from public.staff where status in('ACTIVE','ON_LEAVE')) else '[]'::jsonb end,
 'accounts',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by code),'[]'::jsonb) from public.finance_accounts where is_active and account_subtype in('CASH','BANK','MOBILE_BANK')) else '[]'::jsonb end,
 'advances',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'staffId',staff_id,'name',advance_no,'balance',public.advance_balance(id))),'[]'::jsonb) from public.finance_advances where beneficiary_type='STAFF' and public.advance_balance(id)>0) else '[]'::jsonb end);
end $$;
revoke all on function public.staff_payroll_workspace(uuid,integer) from public,anon;
grant execute on function public.staff_payroll_workspace(uuid,integer) to authenticated;

-- Fixed/hourly contracts do not accrue a second teaching-pool salary. Retention and acquisition remain independent.
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
    if event_amount>0 and not exists(select 1 from public.staff_compensation_terms t where t.staff_id=batch_row.teacher_id and t.model in('FIXED','HOURLY') and t.effective_from<=p_to) and not exists(select 1 from public.staff_payroll_records r where r.staff_id=batch_row.teacher_id and r.month between date_trunc('month',p_from)::date and p_to and r.snapshot->'terms'->>'model' in('FIXED','HOURLY')) and not exists (select 1 from public.teacher_compensation_claims c
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

    -- Acquisition is accrued by the unified referrer collection workflow.
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

-- Staff identities are scoped by campus; the clean staff table has no organization_id column.
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
        and coalesce((select b.organization_id from public.branches b where b.id=staff.branch_id),org)=org
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

-- Include salary settlements in the actual prior-month pay card; leave does not revoke own attendance reads.
create or replace function public.staff_work_workspace(p_month date default null,p_staff_id uuid default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('workforce.manage');sid uuid;first_day date:=date_trunc('month',coalesce(p_month,(now() at time zone 'Asia/Dhaka')::date))::date;last_day date;rows jsonb;terms jsonb;total integer;present integer;hours numeric;effective_hours numeric;pay_date date;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Workforce access required.';end if;
 select id into sid from public.staff where profile_id=actor and status in('ACTIVE','ON_LEAVE');
 if p_staff_id is not null then if not manager and p_staff_id is distinct from sid then raise exception 'Only your own workforce records are available.';end if;sid:=p_staff_id;end if;
 if p_page<1 or p_page>10000 or p_page is null then raise exception 'Invalid page.';end if;
 last_day:=(first_day+interval '1 month')::date;
 select count(*),count(*) filter(where status='PRESENT'),coalesce(sum(case when status='PRESENT' then extract(epoch from ended_at-started_at)/3600-break_minutes/60.0 else 0 end),0)
 into total,present,hours from public.staff_attendance_records where staff_id=sid and work_date>=first_day and work_date<last_day;
 select coalesce(jsonb_agg(to_jsonb(a) order by a.work_date desc),'[]'::jsonb) into rows from(select id,work_date,status,started_at,ended_at,break_minutes,reason,round(case when status='PRESENT' then extract(epoch from ended_at-started_at)/3600-break_minutes/60.0 else 0 end,2) hours from public.staff_attendance_records where staff_id=sid and work_date>=first_day and work_date<last_day order by work_date desc limit 25 offset (p_page-1)*25) a;
 select to_jsonb(t) into terms from public.staff_compensation_terms t where staff_id=sid;
 select coalesce(sum(extract(epoch from ended_at-started_at)/3600-break_minutes/60.0),0) into effective_hours from public.staff_attendance_records where staff_id=sid and status='PRESENT' and work_date>=greatest(first_day,(terms->>'effective_from')::date) and work_date<last_day;
 if terms is not null then pay_date:=date_trunc('month',now() at time zone 'Asia/Dhaka')::date+((terms->>'pay_day')::integer-1);if pay_date<(now() at time zone 'Asia/Dhaka')::date then pay_date:=(date_trunc('month',now() at time zone 'Asia/Dhaka')+interval '1 month')::date+((terms->>'pay_day')::integer-1);end if;end if;
 return jsonb_build_object('manager',manager,'staffId',sid,'name',(select full_name from public.staff where id=sid),'month',first_day,'total',total,'presentDays',present,'hours',round(hours,2),'records',rows,'terms',terms,'scheduledPayDate',pay_date,
 'previousMonthPaid',(select coalesce(sum(s.amount),0) from public.finance_payable_settlements s join public.finance_payables p on p.id=s.payable_id where (p.staff_id=sid or p.referrer_id in(select id from public.referral_people where staff_id=sid)) and (p.payable_type in('TEACHER_COMPENSATION','STAFF_PAYROLL') or p.referrer_id is not null) and s.payment_account_id is not null and s.advance_id is null and s.settled_at>=((date_trunc('month',now() at time zone 'Asia/Dhaka')-interval '1 month') at time zone 'Asia/Dhaka') and s.settled_at<(date_trunc('month',now() at time zone 'Asia/Dhaka') at time zone 'Asia/Dhaka')),
 'hourlyEstimate',round(effective_hours*coalesce((terms->>'hourly_rate')::numeric,0),2),
 'people',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name,'number',staff_no) order by full_name),'[]'::jsonb) from public.staff where status in('ACTIVE','ON_LEAVE')) else '[]'::jsonb end);
end $$;
revoke all on function public.staff_work_workspace(date,uuid,integer) from public,anon;
grant execute on function public.staff_work_workspace(date,uuid,integer) to authenticated;

create function public.my_salary_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid;last_record public.staff_payroll_records;
begin
 if auth.uid() is null or not public.has_permission('workforce.self.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Own workforce access required.';end if;
 select id into sid from public.staff where profile_id=auth.uid();
 select * into last_record from public.staff_payroll_records where staff_id=sid order by month desc limit 1;
 return jsonb_build_object('latestMonth',last_record.month,'latestNet',last_record.net,
 'outstanding',(select coalesce(sum(r.net-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0)),0) from public.staff_payroll_records r where r.staff_id=sid),
 'nextDue',(select min(r.due_on) from public.staff_payroll_records r where r.staff_id=sid and r.net>coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0)));
end $$;
revoke all on function public.my_salary_summary() from public,anon;
grant execute on function public.my_salary_summary() to authenticated;
