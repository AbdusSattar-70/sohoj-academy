-- Repair finance operations without rewriting migration 0042 after deployment.
alter table public.teacher_compensation_lines
 add column admission_id uuid references public.admission_cases(id);

-- A source can be earned only once across approved runs. Rejected requests do
-- not consume the source; approval is serialized by this unique key.
create table public.teacher_compensation_claims (
 id uuid primary key default gen_random_uuid(),
 teacher_id uuid not null references public.staff(id),
 source_type text not null, source_id text not null,
 line_id uuid not null unique references public.teacher_compensation_lines(id),
 run_id uuid not null references public.teacher_compensation_runs(id),
 claimed_at timestamptz not null default now(),
 unique(teacher_id,source_type,source_id)
);
alter table public.teacher_compensation_claims enable row level security;
grant select on public.teacher_compensation_claims to authenticated;
revoke insert,update,delete on public.teacher_compensation_claims from anon,authenticated;
create policy teacher_compensation_claims_read on public.teacher_compensation_claims
 for select to authenticated using(public.has_permission('staff.compensation.view'));
create trigger immutable_compensation_claim before update or delete on public.teacher_compensation_claims
 for each row execute function public.protect_admission_invoice();

alter table public.finance_advance_movements
  add column payable_id uuid references public.finance_payables(id);

alter table public.finance_payable_settlements
  add column advance_id uuid references public.finance_advances(id);

revoke execute on function public.finance_sync_invoice(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_invoice_credit(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_payment(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_refund(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_invoice_line_statement() from public, anon, authenticated;

-- This helper describes actual cash movement by the academy's local posting
-- date, not the month written on an invoice. Refunds are negative movements.
create or replace function public.finance_net_collected_tuition(p_from date,p_to date)
returns table(admission_id uuid,batch_id uuid,billing_period date,tuition_collected numeric)
language sql stable security definer set search_path=public as $$
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
$$;
revoke all on function public.finance_net_collected_tuition(date,date) from public,anon,authenticated;

-- Period-scoped, once-only compensation preview.
create or replace function public.teacher_compensation_preview(
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
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
$$;



-- Transactional finance command with compensation and payable corrections.
create or replace function public.finance_accounting_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
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
  approval public.approval_requests;
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
  if action in('CREATE_ACCOUNT','POST_JOURNAL') then permission:='accounting.manage';
  elsif action in('CREATE_VENDOR','REQUEST_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('DECIDE_ADVANCE') then permission:='finance.advances.approve';
  elsif action in('PAY_ADVANCE','REFUND_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('CREATE_EXPENSE','SUBMIT_EXPENSE') then permission:='accounting.expense.manage';
  elsif action='DECIDE_EXPENSE' then permission:='accounting.expense.approve';
  elsif action='POST_EXPENSE' then permission:='accounting.expense.manage';
  elsif action='SETTLE_PAYABLE' then permission:='finance.payments.post';
  elsif action='REQUEST_ADVANCE_SETTLEMENT' then permission:='finance.advances.manage';
  elsif action='DECIDE_ADVANCE_SETTLEMENT' then permission:='finance.advances.approve';
  elsif action='RECONCILE_EXPENSE' or action='RECONCILE_ACCOUNT' then permission:='accounting.reconcile';
  elsif action='REQUEST_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMPENSATION' then permission:='staff.compensation.approve';
  elsif action='SETTLE_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='REQUEST_COMP_ADJUSTMENT' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMP_ADJUSTMENT' then permission:='staff.compensation.approve';
  elsif action='SET_TEACHER_REFERRAL' then permission:='admissions.create';
  else permission:=null;
  end if;

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

  elsif action='SET_TEACHER_REFERRAL' then
    select * into compensation from public.teacher_compensation_runs where false;
    if not exists(
      select 1 from public.admission_cases
      where id=(p_input->>'admission_id')::uuid and status in('DRAFT','READY')
    ) then
      raise exception 'Teacher referral can only be captured before admission acceptance.';
    end if;
    if not exists(
      select 1 from public.staff s
      where s.id=(p_input->>'teacher_id')::uuid
        and s.status='ACTIVE'
        and exists(
          select 1
          from public.staff_role_assignments sra
          join public.staff_roles sr on sr.id=sra.staff_role_id
          where sra.staff_id=s.id and sr.is_teaching_role
        )
    ) then raise exception 'Choose an active teacher.';
    end if;

    insert into public.teacher_referrals(admission_id,teacher_id,captured_by,reason)
    values((p_input->>'admission_id')::uuid,(p_input->>'teacher_id')::uuid,actor,reason)
    on conflict(admission_id) do update
      set teacher_id=excluded.teacher_id,captured_by=excluded.captured_by,
          captured_at=now(),reason=excluded.reason;

    result:=jsonb_build_object('id',(p_input->>'admission_id'),'message','Teacher referral recorded before acceptance.');

  elsif action='REQUEST_ADVANCE' then
    if p_input->>'beneficiary_type' not in('STAFF','VENDOR','PROJECT') then
      raise exception 'Choose staff, vendor or project as the advance beneficiary.';
    end if;
    amount:=(p_input->>'requested_amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Advance amount must be positive.'; end if;

    insert into public.finance_advances(
      organization_id,beneficiary_type,staff_id,vendor_id,project_reference,
      purpose,requested_amount,expected_settlement_date,requested_by,status
    )
    values(
      org,p_input->>'beneficiary_type',
      nullif(p_input->>'staff_id','')::uuid,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(btrim(p_input->>'project_reference'),''),
      btrim(p_input->>'purpose'),amount,
      nullif(p_input->>'expected_settlement_date','')::date,
      actor,'REQUESTED'
    )
    returning * into advance;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values(
      'ADVANCE','FINANCE_ADVANCE',advance.id::text,action,p_input,reason,actor,req
    )
    returning id into approval;

    update public.finance_advances
    set approval_id=approval.id
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance submitted for independent approval.');

  elsif action='DECIDE_ADVANCE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='ADVANCE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then
      raise exception 'Pending advance approval not found.';
    end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the advance.'; end if;

    select * into advance from public.finance_advances where id=approval.entity_id::uuid for update;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      update public.finance_advances
      set approved_amount=(approval.payload_snapshot->>'requested_amount')::numeric,status='APPROVED'
      where id=advance.id;
    else
      update public.finance_advances set status='REJECTED' where id=advance.id;
    end if;

    result:=jsonb_build_object('id',advance.id,'message','Advance request '||lower(decision)||'.');

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

  elsif action='REQUEST_ADVANCE_SETTLEMENT' then
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
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,
      payload_snapshot,request_note,requested_by,correlation_id)
    values('ADVANCE_SETTLEMENT','ADVANCE',advance.id::text,action,p_input,reason,actor,req)
    returning id into approval;
    result:=jsonb_build_object('id',approval.id,'message','Advance application submitted for independent approval.');

  elsif action='DECIDE_ADVANCE_SETTLEMENT' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='ADVANCE_SETTLEMENT' for update;
    if approval.id is null or approval.status<>'PENDING' or approval.requested_by=actor then
      raise exception 'Choose a pending advance application submitted by another staff member.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
    if decision='APPROVED' then
      select * into advance from public.finance_advances
        where id=(approval.payload_snapshot->>'advance_id')::uuid for update;
      select * into payable from public.finance_payables
        where id=(approval.payload_snapshot->>'payable_id')::uuid for update;
      amount:=(approval.payload_snapshot->>'amount')::numeric;
      if advance.id is null or payable.id is null or payable.organization_id<>advance.organization_id
        or payable.status not in('OPEN','PARTIALLY_SETTLED')
        or not ((advance.beneficiary_type='VENDOR' and payable.vendor_id=advance.vendor_id)
          or (advance.beneficiary_type='STAFF' and payable.staff_id=advance.staff_id))
        or amount>public.advance_balance(advance.id)
        or amount>payable.original_amount-coalesce((select sum(s.amount)
          from public.finance_payable_settlements s where s.payable_id=payable.id),0) then
        raise exception 'Advance or payable changed; review the application again.';
      end if;
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',approval.id::text,
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
      values(advance.id,'SETTLEMENT',amount,'ADVANCE_SETTLEMENT',approval.id::text,payable.id,actor,reason);
      insert into public.finance_payable_settlements(payable_id,amount,advance_id,settled_by,reason)
      values(payable.id,amount,advance.id,actor,'Advance application: '||reason);
      update public.finance_advances set status=case when public.advance_balance(id)=0
        then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=advance.id;
      update public.finance_payables p set status=case when
        coalesce((select sum(s.amount) from public.finance_payable_settlements s
          where s.payable_id=p.id),0)>=p.original_amount then 'SETTLED' else 'PARTIALLY_SETTLED' end
      where p.id=payable.id;
    end if;
    update public.approval_requests set status=decision::public.approval_status,
      decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
    result:=jsonb_build_object('id',approval.id,'message','Advance application '||lower(decision)||'.');

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

  elsif action='CREATE_EXPENSE' then
    amount:=(p_input->>'amount')::numeric;
    payment_mode:=p_input->>'payment_mode';
    if amount is null or amount<=0 or payment_mode not in('PAID_NOW','ON_ACCOUNT') then
      raise exception 'Enter a valid expense amount and payment mode.';
    end if;
    select * into category from public.finance_expense_categories
    where id=(p_input->>'category_id')::uuid and organization_id=org and is_active;
    if category.id is null then raise exception 'Choose an active expense category.'; end if;

    insert into public.finance_expenses(
      organization_id,expense_date,category_id,expense_account_id,payment_mode,
      payment_account_id,vendor_id,staff_id,amount,description,receipt_reference,
      status,submitted_by
    )
    values(
      org,(p_input->>'expense_date')::date,category.id,category.expense_account_id,payment_mode,
      case when payment_mode='PAID_NOW' then nullif(p_input->>'payment_account_id','')::uuid else null end,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(p_input->>'staff_id','')::uuid,
      amount,btrim(p_input->>'description'),
      nullif(btrim(p_input->>'receipt_reference'),''),
      'PENDING_APPROVAL',actor
    )
    returning * into expense;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('EXPENSE','FINANCE_EXPENSE',expense.id::text,'CREATE_EXPENSE',p_input,reason,actor,req)
    returning id into approval;

    update public.finance_expenses set approval_id=approval.id where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense submitted for independent approval.');

  elsif action='DECIDE_EXPENSE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='EXPENSE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending expense approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the expense.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.finance_expenses
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Expense '||lower(decision)||'.');

  elsif action='POST_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    if expense.id is null or expense.status<>'APPROVED' then raise exception 'Only approved expenses can be posted.'; end if;
    if expense.payment_mode='PAID_NOW'
       and not exists(select 1 from public.finance_accounts where id=expense.payment_account_id and organization_id=org and account_subtype in('CASH','BANK','MOBILE_BANK') and is_active) then
      raise exception 'Choose an active cash or bank account for this expense.';
    end if;
    if expense.payment_mode='ON_ACCOUNT' and expense.vendor_id is null and expense.staff_id is null then
      raise exception 'An on-account expense must identify a vendor or staff claimant.';
    end if;

    if expense.payment_mode='PAID_NOW' then
      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',expense.payment_account_id,'debit',0,'credit',expense.amount)
        )
      );
    else
      insert into public.finance_payables(
        organization_id,payable_type,vendor_id,staff_id,source_type,source_id,
        payable_account_id,original_amount,due_on,created_by
      )
      values(
        org,
        case when expense.vendor_id is not null then 'VENDOR'
             when expense.staff_id is not null then 'STAFF_REIMBURSEMENT'
             else 'OTHER' end,
        expense.vendor_id,expense.staff_id,'EXPENSE',expense.id::text,
        case when expense.vendor_id is not null
          then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1)
          else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYABLE' limit 1)
        end,
        expense.amount,
        expense.expense_date + 30,
        actor
      )
      returning * into payable;

      update public.finance_expenses set payable_id=payable.id where id=expense.id;

      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense payable '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',expense.amount)
        )
      );
    end if;

    update public.finance_expenses
    set status='POSTED',posted_by=actor,posted_at=now()
    where id=expense.id;

    result:=jsonb_build_object('id',expense.id,'message','Expense posted to the ledger.');

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

  elsif action='REQUEST_COMPENSATION' then
    preview:=public.teacher_compensation_preview(
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date
    );
    if jsonb_array_length(preview->'rows')=0 then
      raise exception 'No eligible compensation lines for this period.';
    end if;
    if (p_input->>'period_start')::date<>date_trunc('month',(p_input->>'period_start')::date)::date
       or (p_input->>'period_end')::date<>((p_input->>'period_start')::date+interval '1 month - 1 day')::date then
      raise exception 'Compensation runs must cover one complete calendar month.';
    end if;

    select * into policy
    from public.business_rule_versions
    where domain='teacher_compensation'
      and rule_key='default_policy'
      and status='ACTIVE'
    order by version desc
    limit 1;

    insert into public.teacher_compensation_runs(
      organization_id,period_start,period_end,policy_version_id,
      status,total_amount,submitted_by
    )
    values(
      org,(p_input->>'period_start')::date,(p_input->>'period_end')::date,
      policy.id,'PENDING_APPROVAL',(preview->>'total')::numeric,actor
    )
    returning * into compensation;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION','TEACHER_COMPENSATION_RUN',compensation.id::text,
      action,preview,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_runs
    set approval_id=approval.id
    where id=compensation.id;

    for line in select value from jsonb_array_elements(preview->'rows')
    loop
      insert into public.teacher_compensation_lines(
        run_id,teacher_id,admission_id,line_type,source_type,source_id,amount,calculation
      )
      values(
        compensation.id,(line->>'teacherId')::uuid,
        nullif(line->>'admissionId','')::uuid,
        line->>'lineType',line->>'sourceType',line->>'sourceId',
        (line->>'amount')::numeric,coalesce(line->'calculation','{}'::jsonb)
      )
      on conflict(run_id,source_type,source_id) do nothing;
    end loop;

    result:=jsonb_build_object(
      'id',compensation.id,
      'runNo',compensation.run_no,
      'message','Teacher compensation run prepared and submitted for independent approval.',
      'total',compensation.total_amount
    );

  elsif action='DECIDE_COMPENSATION' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide compensation.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    select * into compensation from public.teacher_compensation_runs
    where id=approval.entity_id::uuid for update;
    if decision='APPROVED' and exists(select 1 from public.teacher_compensation_runs prior
      where prior.organization_id=compensation.organization_id and prior.id<>compensation.id
        and prior.status in ('APPROVED','SETTLED')
        and daterange(prior.period_start,prior.period_end,'[]') &&
            daterange(compensation.period_start,compensation.period_end,'[]')) then
      raise exception 'A compensation run already covers this period.';
    end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      -- Claim every earning source atomically before making obligations.
      insert into public.teacher_compensation_claims(teacher_id,source_type,source_id,line_id,run_id)
      select l.teacher_id,l.source_type,l.source_id,l.id,l.run_id
      from public.teacher_compensation_lines l where l.run_id=compensation.id;
      for v_teacher in
        select distinct l.teacher_id from public.teacher_compensation_lines l
        where l.run_id=compensation.id
      loop
        select coalesce(sum(l.amount),0) into amount
        from public.teacher_compensation_lines l
        where l.run_id=compensation.id and l.teacher_id=v_teacher;
        if amount>0 then
          insert into public.finance_payables(
            organization_id,payable_type,staff_id,source_type,source_id,
            payable_account_id,original_amount,due_on,created_by
          ) values(
            compensation.organization_id,'TEACHER_COMPENSATION',v_teacher,
            'COMPENSATION_RUN',compensation.id::text||':'||v_teacher::text,
            (select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            amount,compensation.period_end,actor
          );
        end if;
      end loop;

      perform public.finance_post_journal(
        compensation.organization_id,compensation.period_end,
        'COMPENSATION_RUN','COMPENSATION_RUN',compensation.id::text,
        'Teacher compensation run '||compensation.run_no,actor,
        (
          select jsonb_build_array(
            jsonb_build_object(
              'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHING_COMPENSATION' limit 1),
              'debit',compensation.total_amount,'credit',0,
              'memo','Teaching compensation expense'
            )
          ) ||
          coalesce((
            select jsonb_agg(jsonb_build_object(
              'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
              'debit',0,'credit',totals.amount,
              'memo','Payable for teacher '||totals.teacher_id::text
            ))
            from (select l.teacher_id,sum(l.amount) amount
              from public.teacher_compensation_lines l
              where l.run_id=compensation.id group by l.teacher_id) totals
          ),'[]'::jsonb)
        )
      );
      update public.teacher_compensation_runs
      set status='APPROVED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    else
      update public.teacher_compensation_runs
      set status='REJECTED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',compensation.id,'message','Compensation run '||lower(decision)||'.');

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
  
  elsif action='REQUEST_COMP_ADJUSTMENT' then
    if not exists(select 1 from public.staff where id=(p_input->>'teacher_id')::uuid and status='ACTIVE') then
      raise exception 'Choose an active teacher.';
    end if;
    amount:=(p_input->>'amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Adjustment amount must be positive.'; end if;

    insert into public.teacher_compensation_adjustments(
      teacher_id,amount,adjustment_type,effective_period,reason,requested_by
    )
    values(
      (p_input->>'teacher_id')::uuid,amount,
      coalesce(p_input->>'adjustment_type','ADJUSTMENT'),
      (p_input->>'effective_period')::date,reason,actor
    )
    returning id into settlement_id;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION_ADJUSTMENT','TEACHER_COMPENSATION_ADJUSTMENT',settlement_id::text,
      action,p_input,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_adjustments
    set approval_id=approval.id
    where id=settlement_id;

    result:=jsonb_build_object('id',settlement_id,'message','Compensation adjustment submitted for approval.');

  elsif action='DECIDE_COMP_ADJUSTMENT' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION_ADJUSTMENT'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation adjustment not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the adjustment.'; end if;

    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.teacher_compensation_adjustments
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end,
        approved_by=actor,approved_at=now()
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Compensation adjustment '||lower(decision)||'.');

  else
    raise exception 'Unsupported accounting action.';
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
$$;

