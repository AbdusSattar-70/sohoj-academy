-- Forward migration: apply after the fresh 01-13 baseline. No reset required.
alter table public.referral_people add column email text;
alter table public.referral_people add column profile_id uuid references public.profiles(id);
alter table public.referral_people add column is_active boolean not null default true;
create unique index referral_people_profile_unique on public.referral_people(profile_id) where profile_id is not null;
update public.referral_people r set profile_id=s.profile_id,email=s.email from public.staff s where s.id=r.staff_id;
alter table public.invoice_credits add column category text not null default 'DISCOUNT' check(category in('DISCOUNT','SCHOLARSHIP','ADJUSTMENT','CANCELLATION'));
alter table public.invoice_credits add column description text;
update public.invoice_credits set category='CANCELLATION' where kind='CANCELLATION';
create table public.referral_reward_contracts (
 admission_id uuid primary key references public.admission_cases(id), referrer_id uuid not null references public.referral_people(id),
 billing_period date not null, bonus_percent numeric(7,3) not null check(bonus_percent between 0 and 100),
 policy_version_id uuid not null references public.business_rule_versions(id), created_at timestamptz not null default now()
);
create table public.referral_reward_entries (
 id uuid primary key default gen_random_uuid(), admission_id uuid not null references public.admission_cases(id),
 referrer_id uuid not null references public.referral_people(id), amount numeric(14,2) not null check(amount<>0),
 net_collected numeric(14,2) not null, bonus_percent numeric(7,3) not null, journal_id uuid references public.general_ledger_journals(id),
 payable_id uuid references public.finance_payables(id), source_reference text unique, created_at timestamptz not null default now(), actor_id uuid references public.profiles(id)
);
alter table public.referral_reward_contracts enable row level security;
alter table public.referral_reward_entries enable row level security;
revoke all on public.referral_reward_contracts,public.referral_reward_entries from anon,authenticated;
grant all on public.referral_reward_contracts,public.referral_reward_entries to service_role;
insert into public.permissions(code,name,description) values('referrals.portal.view','View own referrals','Only referrals linked to the signed-in identity') on conflict(code) do nothing;
insert into public.system_roles(code,name,description,is_system) values('REFERRER','Referrer','Own referred students and reward statement only',true) on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code='REFERRER' and p.code='referrals.portal.view' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT','ACADEMIC_DIRECTOR') and p.code='referrals.portal.view' on conflict do nothing;


CREATE OR REPLACE FUNCTION public.validate_business_rule_payload(p_domain text, p_rule_key text, p_payload jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare
  v_pool numeric;
  v_pool_max numeric;
  v_acquisition numeric;
  v_retention_3 numeric;
  v_retention_6 numeric;
  v_capacity numeric;
  v_payment_requirement text;
  v_minimum_payment numeric;
begin
  if p_payload is null or jsonb_typeof(p_payload)<>'object' then return false; end if;

  if p_domain='referrals' and p_rule_key='acquisition_policy' then
    return jsonb_typeof(p_payload->'bonus_percent')='number' and (p_payload->>'bonus_percent')::numeric between 0 and 100;
  end if;
  if p_domain='finance' and p_rule_key='collection_discount_policy' then
    return jsonb_typeof(p_payload->'max_discount_percent')='number' and jsonb_typeof(p_payload->'max_scholarship_percent')='number'
      and (p_payload->>'max_discount_percent')::numeric between 0 and 100 and (p_payload->>'max_scholarship_percent')::numeric between 0 and 100;
  end if;
  if p_domain='academics'  and p_rule_key='batch_capacity_policy' then
    if jsonb_typeof(p_payload->'max_students')<>'number' then return false; end if;
    v_capacity:=(p_payload->>'max_students')::numeric;
    return v_capacity=trunc(v_capacity) and v_capacity between 1 and 500;
  end if;

  if p_domain='teacher_compensation' and p_rule_key='default_policy' then
    if jsonb_typeof(p_payload->'teaching_pool_percent')<>'number'
       or jsonb_typeof(p_payload->'teaching_pool_review_max_percent')<>'number'
       or jsonb_typeof(p_payload->'acquisition_bonus_percent')<>'number'
       or jsonb_typeof(p_payload->'retention_3_month_percent')<>'number'
       or jsonb_typeof(p_payload->'retention_6_month_percent')<>'number' then
      return false;
    end if;
    v_pool:=(p_payload->>'teaching_pool_percent')::numeric;
    v_pool_max:=(p_payload->>'teaching_pool_review_max_percent')::numeric;
    v_acquisition:=(p_payload->>'acquisition_bonus_percent')::numeric;
    v_retention_3:=(p_payload->>'retention_3_month_percent')::numeric;
    v_retention_6:=(p_payload->>'retention_6_month_percent')::numeric;
    if coalesce(p_payload->>'teaching_allocation_method','APPROVED_SESSION_WEIGHT')
       not in('APPROVED_SESSION_WEIGHT') then
      return false;
    end if;
    return v_pool between 0 and 100
      and v_pool_max between 0 and 100
      and v_pool<=v_pool_max
      and v_acquisition between 0 and 100
      and v_retention_3 between 0 and 100
      and v_retention_6 between 0 and 100;
  end if;

  if p_domain='admissions' and p_rule_key='activation_policy' then
    if jsonb_typeof(p_payload->'requires_admission_acceptance')<>'boolean'
       or jsonb_typeof(p_payload->'requires_initial_billing_posted')<>'boolean'
       or jsonb_typeof(p_payload->'allow_credit_enrollment')<>'boolean'
       or jsonb_typeof(p_payload->'count_student_active_only_when_enrollment_active')<>'boolean'
       or jsonb_typeof(p_payload->'minimum_payment_percent')<>'number'
       or jsonb_typeof(p_payload->'payment_requirement')<>'string' then return false; end if;
    v_payment_requirement:=p_payload->>'payment_requirement';
    v_minimum_payment:=(p_payload->>'minimum_payment_percent')::numeric;
    if v_payment_requirement not in('NONE','MINIMUM_PERCENT','FULL') then return false; end if;
    if v_minimum_payment<0 or v_minimum_payment>100 then return false; end if;
    if v_payment_requirement='NONE' and v_minimum_payment<>0 then return false; end if;
    if v_payment_requirement='MINIMUM_PERCENT' and (v_minimum_payment<=0 or v_minimum_payment>=100) then return false; end if;
    if v_payment_requirement='FULL' and v_minimum_payment<>100 then return false; end if;
    return true;
  end if;

  return false;
exception when others then
  return false;
end;
$function$;

insert into public.business_rule_versions(domain,rule_key,version,status,effective_from,payload,change_reason)
select 'referrals','acquisition_policy',1,'ACTIVE',current_date,jsonb_build_object('bonus_percent',coalesce((payload->>'acquisition_bonus_percent')::numeric,50)), 'Initial unified referrer acquisition settings'
from public.business_rule_versions where domain='teacher_compensation' and rule_key='default_policy' and status='ACTIVE' order by version desc limit 1;
insert into public.business_rule_versions(domain,rule_key,version,status,effective_from,payload,change_reason)
values('finance','collection_discount_policy',1,'ACTIVE',current_date,'{"max_discount_percent":30,"max_scholarship_percent":100}','Initial authorized collection-time adjustment limits');


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

-- Monetary collection attributed to tuition after recorded discounts and refunds.
create function public.referral_invoice_collections(p_admission_id uuid)
returns table(invoice_id uuid,billing_period date,tuition_net numeric,net_paid numeric,tuition_collected numeric)
language sql stable security definer set search_path=public as $$
select i.id,i.billing_period,n.tuition_net,c.net_paid,
 round(least(n.tuition_net,case when n.net_invoice>0 then c.net_paid*least(n.tuition_net,n.net_invoice)/n.net_invoice else 0 end),2)
from public.admission_invoices i
cross join lateral(select greatest(i.total-coalesce(sum(ic.amount),0),0) net_invoice,
 greatest(coalesce((select sum(l.amount) from public.admission_invoice_lines l where l.invoice_id=i.id and l.charge_type='TUITION'),0)-coalesce(sum(ic.amount) filter(where ic.kind='DISCOUNT'),0),0) tuition_net
 from public.invoice_credits ic where ic.invoice_id=i.id) n
cross join lateral(select greatest(coalesce((select sum(pa.amount) from public.admission_payment_allocations pa where pa.invoice_id=i.id),0)-coalesce((select sum(ra.amount) from public.refund_authorizations ra join public.refund_payouts rp on rp.authorization_id=ra.id where ra.invoice_id=i.id),0),0) net_paid) c
where i.admission_id=p_admission_id;
$$;
-- Preserve previously posted external awards as opening evidence, without reposting journals.
insert into public.referral_reward_contracts(admission_id,referrer_id,billing_period,bonus_percent,policy_version_id)
select admission_id,referrer_id,period_start,bonus_percent,policy_version_id from public.referral_bonus_awards where status='APPROVED' on conflict do nothing;
insert into public.referral_reward_entries(admission_id,referrer_id,amount,net_collected,bonus_percent,payable_id,source_reference,actor_id)
select admission_id,referrer_id,amount,net_collected,bonus_percent,payable_id,'LEGACY_AWARD:'||id,requested_by from public.referral_bonus_awards where status='APPROVED';
-- Teacher acquisition already posted in an older run must not accrue twice.
insert into public.referral_reward_contracts(admission_id,referrer_id,billing_period,bonus_percent,policy_version_id)
select distinct on(l.admission_id) l.admission_id,ar.referrer_id,date_trunc('month',r.period_start)::date,
 coalesce((l.calculation->>'bonusPercent')::numeric,0),r.policy_version_id
from public.teacher_compensation_lines l join public.teacher_compensation_runs r on r.id=l.run_id
join public.admission_referrals ar on ar.admission_id=l.admission_id and ar.source='REFERRED'
where l.line_type='ACQUISITION_BONUS' and r.status='APPROVED' order by l.admission_id,r.created_at on conflict do nothing;
insert into public.referral_reward_entries(admission_id,referrer_id,amount,net_collected,bonus_percent,source_reference,actor_id)
select l.admission_id,ar.referrer_id,l.amount,coalesce((l.calculation->>'firstMonthNetCollectedTuition')::numeric,0),coalesce((l.calculation->>'bonusPercent')::numeric,0),'LEGACY_TEACHER:'||l.id,r.submitted_by
from public.teacher_compensation_lines l join public.teacher_compensation_runs r on r.id=l.run_id
join public.admission_referrals ar on ar.admission_id=l.admission_id and ar.source='REFERRED'
where l.line_type='ACQUISITION_BONUS' and r.status='APPROVED' and l.amount>0;
create function public.sync_referral_reward(p_admission_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; ar public.admission_referrals; c public.referral_reward_contracts;
 policy public.business_rule_versions; person public.referral_people; first_month date; collected numeric; target numeric; delta numeric;
 actor uuid; org uuid; liability uuid; expense uuid; payable uuid; event_id uuid:=gen_random_uuid(); journal uuid;
begin
 select * into a from public.admission_cases where id=p_admission_id for update;
 if a.id is null then return; end if;
 select * into ar from public.admission_referrals where admission_id=a.id;
 if ar.source is distinct from 'REFERRED' then return; end if;
 select * into person from public.referral_people where id=ar.referrer_id;
 select * into c from public.referral_reward_contracts where admission_id=a.id;
 actor:=coalesce(auth.uid(),a.created_by); org:=person.organization_id;
 if c.admission_id is null then
   select min(billing_period) into first_month from public.referral_invoice_collections(a.id) where tuition_collected>0;
   if first_month is null then return; end if;
   select * into policy from public.business_rule_versions where domain='referrals' and rule_key='acquisition_policy' and status='ACTIVE' order by version desc limit 1;
   if policy.id is null then raise exception 'Configure referrer acquisition settings first.'; end if;
   insert into public.referral_reward_contracts(admission_id,referrer_id,billing_period,bonus_percent,policy_version_id)
   values(a.id,person.id,first_month,(policy.payload->>'bonus_percent')::numeric,policy.id) returning * into c;
 end if;
 select coalesce(sum(tuition_collected),0) into collected from public.referral_invoice_collections(a.id) where billing_period=c.billing_period;
 target:=round(collected*c.bonus_percent/100,2);
 select target-coalesce(sum(amount),0) into delta from public.referral_reward_entries where admission_id=a.id;
 if delta=0 then return; end if;
 select id into liability from public.finance_accounts where organization_id=org and code='2130';
 select id into expense from public.finance_accounts where organization_id=org and code='5200';
 if delta>0 then
  insert into public.finance_payables(organization_id,payable_type,referrer_id,source_type,source_id,payable_account_id,original_amount,due_on,created_by)
  values(org,'OTHER',c.referrer_id,'REFERRAL_ACCRUAL',event_id::text,liability,delta,current_date,actor) returning id into payable;
 end if;
 journal:=public.finance_post_journal(org,current_date,'COMPENSATION_RUN','REFERRAL_ACCRUAL',event_id::text,
 'Referral acquisition entitlement adjusted to actual net tuition collected',actor,
 case when delta>0 then jsonb_build_array(jsonb_build_object('account_id',expense,'debit',delta,'credit',0),jsonb_build_object('account_id',liability,'debit',0,'credit',delta))
 else jsonb_build_array(jsonb_build_object('account_id',liability,'debit',-delta,'credit',0),jsonb_build_object('account_id',expense,'debit',0,'credit',-delta)) end);
 insert into public.referral_reward_entries(id,admission_id,referrer_id,amount,net_collected,bonus_percent,journal_id,payable_id,actor_id)
 values(event_id,a.id,c.referrer_id,delta,collected,c.bonus_percent,journal,payable,actor);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values(actor,'REFERRAL_REWARD',event_id::text,case when delta>0 then 'ACCRUE' else 'CORRECT' end,'Based on actual net collected tuition',jsonb_build_object('admission_id',a.id,'amount',delta,'net_collected',collected,'rate',c.bonus_percent));
end; $$;
create function public.referral_collection_changed() returns trigger language plpgsql security definer set search_path=public as $$
declare admission uuid;
begin
 if TG_TABLE_NAME='admission_payment_allocations' then select admission_id into admission from public.admission_invoices where id=new.invoice_id;
 elsif TG_TABLE_NAME='invoice_credits' then select admission_id into admission from public.admission_invoices where id=new.invoice_id;
 elsif TG_TABLE_NAME='refund_payouts' then select i.admission_id into admission from public.refund_authorizations r join public.admission_invoices i on i.id=r.invoice_id where r.id=new.authorization_id;
 else admission:=new.admission_id; end if;
 perform public.sync_referral_reward(admission); return new;
end; $$;
create trigger referral_collection_accrual after insert on public.admission_payment_allocations for each row execute function public.referral_collection_changed();
create trigger referral_discount_correction after insert on public.invoice_credits for each row execute function public.referral_collection_changed();
create trigger referral_refund_correction after insert on public.refund_payouts for each row execute function public.referral_collection_changed();
create trigger referral_capture_accrual after insert or update on public.admission_referrals for each row execute function public.referral_collection_changed();
create function public.referrer_paid(p_referrer uuid) returns numeric language sql stable security definer set search_path=public as $$
 select coalesce((select sum(s.amount) from public.finance_payable_settlements s join public.finance_payables p on p.id=s.payable_id where p.referrer_id=p_referrer),0)
 +coalesce((select sum(l.amount*least(s.gross_amount/greatest(t.total,0.01),1)) from public.teacher_compensation_lines l
 join public.admission_referrals ar on ar.admission_id=l.admission_id and ar.referrer_id=p_referrer
 join public.teacher_compensation_settlements s on s.run_id=l.run_id and s.teacher_id=l.teacher_id
 cross join lateral(select sum(amount) total from public.teacher_compensation_lines x where x.run_id=l.run_id and x.teacher_id=l.teacher_id) t
 where l.line_type='ACQUISITION_BONUS'),0);
$$;


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
     where id=(p_input->>'referrer_id')::uuid and organization_id=org and is_active;
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
   if not person.is_active then raise exception 'This referrer is inactive for new admissions.'; end if;
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
  perform public.sync_referral_reward((p_input->>'admission_id')::uuid);
  result:=jsonb_build_object('id',p_input->>'admission_id','message','Referral entitlement synchronized with recorded net tuition collection.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ADMISSION_REFERRAL',result->>'id',action,reason,result,jsonb_build_object('module','referrals'));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end
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
  if action='SETTLE_PAYABLE' and exists(select 1 from public.finance_payables where id=(p_input->>'payable_id')::uuid and referrer_id is not null) then
    raise exception 'Settle referral rewards from the Referrers page so corrected entitlement is checked.';
  end if;
  if action in('CREATE_ADVANCE' ,'CREATE_EXPENSE_DIRECT','RUN_COMPENSATION','APPLY_COMP_ADJUSTMENT') then
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
create function public.referrer_workspace(p_referrer_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare manager boolean:=public.has_permission('staff.compensation.manage') or public.has_permission('admissions.create'); rid uuid; person public.referral_people; students jsonb; org uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Active sign-in required.'; end if;
 if manager then rid:=p_referrer_id;
 else select r.id into rid from public.referral_people r left join public.staff s on s.id=r.staff_id where r.is_active and (r.profile_id=auth.uid() or (s.profile_id=auth.uid() and s.status='ACTIVE'));
  if rid is null or (p_referrer_id is not null and p_referrer_id<>rid) then raise exception 'Only your own referrals are available.'; end if;
 end if;
 select * into person from public.referral_people where id=rid;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'number',a.admission_no,'name',a.identity_snapshot->>'student_name','studentNo',s.student_no,'programme',o.name,'status',a.status,
 'discountPercent',a.selected_discount_percent,
 'discountAmount',(select coalesce(sum(ic.amount),0) from public.invoice_credits ic join public.admission_invoices i on i.id=ic.invoice_id where i.admission_id=a.id and ic.kind='DISCOUNT'),
 'netTuition',(select coalesce(sum(tuition_collected),0) from public.referral_invoice_collections(a.id)),
 'reward',(select coalesce(sum(amount),0) from public.referral_reward_entries where admission_id=a.id),
 'rate',(select bonus_percent from public.referral_reward_contracts where admission_id=a.id),
 'collections',(select coalesce(jsonb_agg(jsonb_build_object('receipt',p.receipt_no,'receivedOn',p.posted_at,'allocated',pa.amount,'billingPeriod',i.billing_period,'tuitionCollected',c.tuition_collected) order by p.posted_at desc),'[]'::jsonb)
 from public.admission_invoices i join public.admission_payment_allocations pa on pa.invoice_id=i.id join public.admission_payments p on p.id=pa.payment_id
 join public.referral_invoice_collections(a.id) c on c.invoice_id=i.id where i.admission_id=a.id)) order by a.created_at desc),'[]'::jsonb) into students
 from public.admission_referrals ar join public.admission_cases a on a.id=ar.admission_id join public.batches b on b.id=a.batch_id join public.programme_offerings o on o.id=b.offering_id left join public.students s on s.id=a.student_id
 where ar.referrer_id=rid and ar.source='REFERRED';
 return jsonb_build_object('manager',manager,'people',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.full_name,'mobile',r.mobile,'email',r.email,'staffId',r.staff_id,'profileId',coalesce(r.profile_id,s.profile_id),'active',r.is_active,'relationship',r.relationship_note,'notes',r.contact_note) order by r.full_name),'[]'::jsonb) from public.referral_people r left join public.staff s on s.id=r.staff_id) else '[]'::jsonb end,
 'selected',rid,'name',person.full_name,'students',students,
 'earned',(select coalesce(sum(amount),0) from public.referral_reward_entries where referrer_id=rid),'settled',public.referrer_paid(rid),
 'entries',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'amount',amount,'collected',net_collected,'rate',bonus_percent,'date',created_at) order by created_at desc),'[]'::jsonb) from public.referral_reward_entries where referrer_id=rid),
 'settlements',(select coalesce(jsonb_agg(jsonb_build_object('amount',s.amount,'date',s.settled_at,'reference',s.external_reference) order by s.settled_at desc),'[]'::jsonb) from public.finance_payable_settlements s join public.finance_payables p on p.id=s.payable_id where p.referrer_id=rid),
 'accounts',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)),'[]'::jsonb) from public.finance_accounts where organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')) else '[]'::jsonb end);
end; $$;
create function public.manage_referrer(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.referral_people; actor uuid:=auth.uid(); org uuid; action text:=p_input->>'action'; profile uuid; assigned_role uuid; result jsonb; req uuid:=nullif(p_input->>'request_id','')::uuid; reason text:=btrim(coalesce(p_input->>'reason','')); previous public.admission_command_keys;
begin
 if actor is null or not public.has_permission('admissions.create') then raise exception 'Referrer management permission required.'; end if;
 if req is null or length(reason)<5 or length(reason)>500 then raise exception 'Supply a request ID and reason of 5-500 characters.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,12)); select * into previous from public.admission_command_keys where request_id=req;
 if found then if previous.actor_id<>actor or previous.payload<>p_input then raise exception 'Request ID already used.'; end if; return previous.result; end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 if action='SAVE' then
  if length(btrim(coalesce(p_input->>'name','')))<2 or length(p_input->>'name')>160 then raise exception 'Enter the referrer name.'; end if;
  if coalesce(p_input->>'mobile','') !~ '^$|^01[3-9][0-9]{8}$' or coalesce(p_input->>'email','') !~ '^$|^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Check mobile and email.'; end if;
  if nullif(p_input->>'id','') is null then
   insert into public.referral_people(organization_id,full_name,mobile,email,relationship_note,contact_note,created_by)
   values(org,btrim(p_input->>'name'),nullif(p_input->>'mobile',''),nullif(lower(btrim(p_input->>'email')),''),left(p_input->>'relationship',160),left(p_input->>'notes',500),actor) returning * into r;
  else
   select * into r from public.referral_people where id=(p_input->>'id')::uuid and organization_id=org for update;
   if r.id is null then raise exception 'Referrer not found.'; end if;
   if r.profile_id is not null and nullif(lower(btrim(p_input->>'email')),'') is distinct from r.email then raise exception 'Linked account email changes must use verified Supabase account recovery.'; end if;
   update public.referral_people set full_name=btrim(p_input->>'name'),mobile=nullif(p_input->>'mobile',''),email=nullif(lower(btrim(p_input->>'email')),''),relationship_note=left(p_input->>'relationship',160),contact_note=left(p_input->>'notes',500) where id=r.id;
  end if;
 elsif action='LINK_ACCOUNT' then
  if not public.has_permission('system.users.manage') then raise exception 'Account management permission required.'; end if;
  select * into r from public.referral_people where id=(p_input->>'id')::uuid and organization_id=org and is_active for update;
  if r.id is null or r.email is null then raise exception 'Save and verify the referrer email first.'; end if;
  select id into profile from auth.users where lower(email)=lower(r.email);
  if profile is null then raise exception 'Send the Supabase invitation first.'; end if;
  if r.staff_id is not null and not exists(select 1 from public.staff where id=r.staff_id and profile_id=profile) then raise exception 'Use the linked staff account, not a second identity.'; end if;
  insert into public.profiles(id,display_name) values(profile,r.full_name) on conflict(id) do nothing;
  update public.referral_people set profile_id=profile where id=r.id;
  select id into assigned_role from public.system_roles where code='REFERRER';
  if not exists(select 1 from public.user_role_assignments where profile_id=profile and user_role_assignments.role_id=assigned_role and is_active and effective_to is null) then
   insert into public.user_role_assignments(profile_id,role_id,assigned_by) values(profile,assigned_role,actor);
  end if;
 elsif action='SET_ACTIVE' then
  update public.referral_people set is_active=(p_input->>'active')::boolean where id=(p_input->>'id')::uuid and organization_id=org returning * into r;
  if r.id is null then raise exception 'Referrer not found.'; end if;
 else raise exception 'Unknown referrer action.'; end if;
 result:=jsonb_build_object('id',r.id,'message','Referrer record saved.');
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'REFERRER',r.id::text,action,reason,result);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result); return result;
end; $$;
create function public.settle_referrer_reward(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare rid uuid:=(p_input->>'referrer_id')::uuid; actor uuid:=auth.uid(); req uuid:=(p_input->>'request_id')::uuid; amount numeric:=round((p_input->>'amount')::numeric,2); cash uuid:=(p_input->>'account_id')::uuid;
 reason text:=btrim(coalesce(p_input->>'reason','')); available numeric; org uuid; liability uuid; remaining numeric; pay public.finance_payables; portion numeric; result jsonb; previous public.admission_command_keys;
begin
 if actor is null or not public.has_permission('staff.compensation.manage') then raise exception 'Compensation management permission required.'; end if;
 if req is null or amount is null or amount<=0 or length(reason)<5 then raise exception 'Enter a positive amount, reason and request ID.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,13)); select * into previous from public.admission_command_keys where request_id=req;
 if found then if previous.actor_id<>actor or previous.payload<>p_input then raise exception 'Request ID already used.'; end if; return previous.result; end if;
 select organization_id into org from public.referral_people where id=rid for update;
 if org is null then raise exception 'Referrer unavailable.'; end if;
 -- Lock admissions too: collection adjustments and settlements cannot race.
 perform 1 from public.admission_cases a join public.admission_referrals r on r.admission_id=a.id where r.referrer_id=rid order by a.id for update of a;
 select coalesce(sum(e.amount),0)-public.referrer_paid(rid) into available from public.referral_reward_entries e where e.referrer_id=rid;
 if amount>available then raise exception 'Payment exceeds the corrected outstanding referral entitlement.'; end if;
 if not exists(select 1 from public.finance_accounts where id=cash and organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')) then raise exception 'Choose an active cash/bank account.'; end if;
 select id into liability from public.finance_accounts where organization_id=org and code='2130';
 remaining:=amount;
 for pay in select * from public.finance_payables where referrer_id=rid and status<>'VOIDED' order by created_at,id for update loop
  portion:=least(remaining,pay.original_amount-coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=pay.id),0));
  if portion>0 then
   insert into public.finance_payable_settlements(payable_id,amount,payment_account_id,external_reference,settled_by,reason) values(pay.id,portion,cash,nullif(p_input->>'reference',''),actor,reason);
   remaining:=remaining-portion;
  end if;
  exit when remaining=0;
 end loop;
 if remaining<>0 then raise exception 'Legacy teacher acquisition remains in teacher compensation settlement. Settle that run first.'; end if;
 perform public.finance_post_journal(org,current_date,'PAYABLE_SETTLEMENT','REFERRER_PAYMENT',req::text,reason,actor,jsonb_build_array(jsonb_build_object('account_id',liability,'debit',amount,'credit',0),jsonb_build_object('account_id',cash,'debit',0,'credit',amount)));
 result:=jsonb_build_object('id',rid,'message','Actual referrer payment recorded.');
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'REFERRER',rid::text,'SETTLE_REWARD',reason,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end; $$;
create function public.collect_student_payment(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid:=auth.uid(); req uuid:=(p_input->>'request_id')::uuid; i public.admission_invoices; b record; tuition numeric; adjustment numeric:=coalesce((p_input->>'adjustment_amount')::numeric,0); category text:=coalesce(p_input->>'adjustment_category','DISCOUNT'); limit_percent numeric; policy public.business_rule_versions; result jsonb; previous public.admission_command_keys;
begin
 if actor is null or not public.has_permission('finance.payments.post') then raise exception 'Payment permission required.'; end if;
 if req is null then raise exception 'Request ID required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,14));select * into previous from public.admission_command_keys where request_id=req;
 if found then if previous.actor_id<>actor or previous.payload<>p_input then raise exception 'Request ID already used.'; end if; return previous.result; end if;
 select * into i from public.admission_invoices where id=(p_input->>'invoice_id')::uuid for update;
 if i.id is null or i.admission_id<>(p_input->>'admission_id')::uuid then raise exception 'Choose the correct student invoice.'; end if;
 if adjustment<0 or adjustment<>round(adjustment,2) then raise exception 'Enter an adjustment amount with at most two decimals.'; end if;
 if adjustment>0 then
  if not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required for discounts or scholarships.'; end if;
  if category not in('DISCOUNT','SCHOLARSHIP') or length(btrim(coalesce(p_input->>'adjustment_reason','')))<5 then raise exception 'Select discount/scholarship and a reason of at least five characters.'; end if;
  select * into policy from public.business_rule_versions where domain='finance' and rule_key='collection_discount_policy' and status='ACTIVE' order by version desc limit 1;
  if policy.id is null then raise exception 'Configure collection-time adjustment limits.'; end if;
  limit_percent:=(policy.payload->>case when category='SCHOLARSHIP' then 'max_scholarship_percent' else 'max_discount_percent' end)::numeric;
  select coalesce(sum(amount),0) into tuition from public.admission_invoice_lines where invoice_id=i.id and charge_type='TUITION';
  select * into b from public.invoice_balance(i.id);
  if adjustment>greatest(tuition-coalesce((select sum(amount) from public.invoice_credits where invoice_id=i.id and kind='DISCOUNT'),0),0)
    or adjustment>tuition*limit_percent/100 or adjustment>b.due then raise exception 'Adjustment exceeds remaining tuition, the configured limit, or the unpaid balance.'; end if;
  insert into public.invoice_credits(invoice_id,kind,category,amount,applied_by,description) values(i.id,'DISCOUNT',category,adjustment,actor,btrim(p_input->>'adjustment_reason'));
 end if;
 if coalesce((p_input->>'amount')::numeric,0)>0 then
  result:=public.post_admission_payment((p_input-'adjustment_amount'-'adjustment_category'-'adjustment_reason')||jsonb_build_object('request_id',gen_random_uuid(),'action','PAY'));
 elsif adjustment>0 then result:=jsonb_build_object('message',initcap(lower(category))||' recorded; no money received.');
 else raise exception 'Record an actual payment or a positive discount/scholarship.'; end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'INVOICE',i.id::text,'COLLECT_OR_ADJUST',p_input->>'reason',p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end; $$;
create function public.finance_operating_summary() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare revenue numeric; contra numeric; expenses numeric;
begin
 if not public.has_permission('accounting.view') then raise exception 'Accounting view permission required.'; end if;
 select coalesce(sum(case when a.account_type='REVENUE' then l.credit-l.debit else 0 end),0),
 coalesce(sum(case when a.account_type='CONTRA_REVENUE' then l.debit-l.credit else 0 end),0),
 coalesce(sum(case when a.account_type='EXPENSE' then l.debit-l.credit else 0 end),0) into revenue,contra,expenses
 from public.general_ledger_lines l join public.finance_accounts a on a.id=l.account_id join public.general_ledger_journals j on j.id=l.journal_id where j.status='POSTED';
 return jsonb_build_object('revenue',revenue,'discountsAndReversals',contra,'expenses',expenses,'profitLoss',revenue-contra-expenses,
 'balances',(select coalesce(jsonb_object_agg(a.id::text,public.finance_account_balance(a.id,current_date)),'{}'::jsonb) from public.finance_accounts a where is_active));
end; $$;

CREATE OR REPLACE FUNCTION public.publish_business_rule_version(p_domain text, p_rule_key text, p_payload jsonb, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare previous public.business_rule_versions; saved public.business_rule_versions; next_version integer; trace uuid:=gen_random_uuid();
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Settings management permission required.'; end if;
 if (p_domain,p_rule_key) not in (('academics','batch_capacity_policy'),('admissions','activation_policy'),('teacher_compensation','default_policy'),('referrals','acquisition_policy'),('finance','collection_discount_policy')) then raise exception 'Choose a supported operating rule.'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 5 and 500 or not public.validate_business_rule_payload(p_domain,p_rule_key,p_payload) then raise exception 'Check the operating values and change reason.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_domain||'.'||p_rule_key,0));
 select * into previous from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key and status='ACTIVE' for update;
 if previous.id is not null and previous.payload=p_payload then return jsonb_build_object('id',previous.id,'version',previous.version); end if;
 select coalesce(max(version),0)+1 into next_version from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key;
 update public.business_rule_versions set status='RETIRED',effective_to=current_date where id=previous.id;
 insert into public.business_rule_versions(domain,rule_key,version,status,effective_from,payload,change_reason,created_by)
 values(p_domain,p_rule_key,next_version,'ACTIVE',current_date,p_payload,btrim(p_reason),auth.uid()) returning * into saved;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(trace,auth.uid(),'BUSINESS_RULE',p_domain||'.'||p_rule_key,case when previous.id is null then 'CREATE_SETTINGS' else 'SAVE_SETTINGS' end,p_reason,to_jsonb(previous),to_jsonb(saved));
 return jsonb_build_object('id',saved.id,'version',saved.version,'correlation_id',trace);
end $function$;

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
 'invoices',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'admissionId',a.id,'name',a.identity_snapshot->>'student_name','number',i.invoice_no,'kind',i.invoice_kind,'period',i.billing_period,'dueOn',i.due_on,'currency',i.currency_code,'gross',b.gross,'credits',b.credits,'discountAmount',(select coalesce(sum(amount),0) from public.invoice_credits where invoice_id=i.id and kind='DISCOUNT' and category<>'SCHOLARSHIP'),'scholarshipAmount',(select coalesce(sum(amount),0) from public.invoice_credits where invoice_id=i.id and category='SCHOLARSHIP'),'otherAdjustments',(select coalesce(sum(amount),0) from public.invoice_credits where invoice_id=i.id and kind<>'DISCOUNT'),'net',b.net,'paid',b.paid,'refunded',b.refunded,'due',b.due,'credit',b.credit_balance,'reserved',b.reserved_refunds,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('name',name,'amount',amount)) from public.admission_invoice_lines where invoice_id=i.id),'[]'::jsonb)) order by i.posted_at desc) from public.admission_invoices i join public.admission_cases a on a.id=i.admission_id cross join lateral public.invoice_balance(i.id) b),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'invoiceId',pa.invoice_id,'number',p.receipt_no,'amount',p.amount,'postedAt',p.posted_at,'method',pm.name,'remaining',p.amount-coalesce((select sum(amount) from public.refund_authorizations where payment_id=p.id),0))) from public.admission_payments p join public.admission_payment_allocations pa on pa.payment_id=p.id join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'discounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'kind',kind,'value',value,'startsOn',starts_on,'endsOn',ends_on)) from public.admission_discounts),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'invoiceId',r.invoice_id,'paymentId',r.payment_id,'amount',r.amount,'number',p.refund_no,'postedAt',p.posted_at,'method',pm.name,'reference',p.external_reference)) from public.refund_authorizations r left join public.refund_payouts p on p.authorization_id=r.id left join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'runs',coalesce((select jsonb_agg(jsonb_build_object('id',id,'period',period,'count',invoice_count,'gross',gross_total,'postedAt',posted_at) order by posted_at desc) from public.billing_runs),'[]'::jsonb),
 'paymentMethods',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb)
 );
end;
$function$;
create or replace function public.edit_staff_record(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare original public.staff; saved public.staff; actor uuid:=auth.uid(); trace uuid:=gen_random_uuid();
begin
 if actor is null or not public.has_permission('staff.manage') then raise exception 'Staff management permission required.'; end if;
 select * into original from public.staff where id=(p_input->>'id')::uuid for update;
 if original.id is null then raise exception 'Staff identity not found.'; end if;
 if length(btrim(coalesce(p_input->>'full_name','')))<2 or length(p_input->>'full_name')>160 or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Enter name and correction reason.'; end if;
 if coalesce(p_input->>'mobile','') !~ '^$|^01[3-9][0-9]{8}$' or coalesce(p_input->>'alternate_mobile','') !~ '^$|^01[3-9][0-9]{8}$' or coalesce(p_input->>'emergency_contact_mobile','') !~ '^$|^01[3-9][0-9]{8}$' then raise exception 'Check 11-digit Bangladesh mobile numbers.'; end if;
 if original.profile_id is not null and p_input ? 'email' and nullif(lower(btrim(p_input->>'email')),'') is distinct from original.email then raise exception 'Change linked account email through secure account settings.'; end if;
 if coalesce(p_input->>'email','') !~ '^$|^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Enter a valid email.'; end if;
 update public.staff set full_name=btrim(p_input->>'full_name'), mobile=nullif(p_input->>'mobile',''),
 alternate_mobile=case when p_input ? 'alternate_mobile' then nullif(p_input->>'alternate_mobile','') else alternate_mobile end,
 email=case when p_input ? 'email' then nullif(lower(btrim(p_input->>'email')),'') else email end,
 address=case when p_input ? 'address' then left(p_input->>'address',500) else address end,
 emergency_contact_name=case when p_input ? 'emergency_contact_name' then left(p_input->>'emergency_contact_name',160) else emergency_contact_name end,
 emergency_contact_mobile=case when p_input ? 'emergency_contact_mobile' then nullif(p_input->>'emergency_contact_mobile','') else emergency_contact_mobile end,
 joined_on=case when p_input ? 'joined_on' then nullif(p_input->>'joined_on','')::date else joined_on end,
 notes=case when p_input ? 'notes' then left(p_input->>'notes',1000) else notes end where id=original.id returning * into saved;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data) values(trace,actor,'STAFF',saved.id::text,'CORRECT_DETAILS',p_input->>'reason',to_jsonb(original),to_jsonb(saved));
 return jsonb_build_object('id',saved.id);
end; $$;

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

  if coalesce(p_input->>'student_mobile','') !~ '^$|^01[3-9][0-9]{8}$' or coalesce(p_input->>'student_email','') !~ '^$|^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Check optional student contact details.'; end if;
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

  extras:=jsonb_build_object('student_mobile',left(p_input->>'student_mobile',30),'student_email',left(p_input->>'student_email',254),'present_landmark',left(p_input->>'present_landmark',160),'permanent_same_as_present',coalesce(p_input->>'permanent_same_as_present','false'),'father_name',left(p_input->>'father_name',160),'mother_name',left(p_input->>'mother_name',160),
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

revoke all on function public.referral_invoice_collections(uuid) from public,anon,authenticated;

revoke all on function public.sync_referral_reward(uuid) from public,anon,authenticated;

revoke all on function public.referral_collection_changed() from public,anon,authenticated;

revoke all on function public.referrer_paid(uuid) from public,anon,authenticated;

revoke all on function public.referrer_workspace(uuid) from public,anon,authenticated;

revoke all on function public.manage_referrer(jsonb) from public,anon,authenticated;

revoke all on function public.settle_referrer_reward(jsonb) from public,anon,authenticated;

revoke all on function public.collect_student_payment(jsonb) from public,anon,authenticated;

revoke all on function public.finance_operating_summary() from public,anon,authenticated;
grant execute on function public.referrer_workspace(uuid) to authenticated;
grant execute on function public.manage_referrer(jsonb) to authenticated;
grant execute on function public.settle_referrer_reward(jsonb) to authenticated;
grant execute on function public.collect_student_payment(jsonb) to authenticated;
grant execute on function public.finance_operating_summary() to authenticated;

revoke update,delete on public.referral_reward_contracts,public.referral_reward_entries from authenticated;
create function public.save_referral_operating_rules(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 perform public.publish_business_rule_version('referrals','acquisition_policy',jsonb_build_object('bonus_percent',(p_input->>'bonusPercent')::numeric),p_input->>'reason');
 perform public.publish_business_rule_version('finance','collection_discount_policy',jsonb_build_object('max_discount_percent',(p_input->>'discountMax')::numeric,'max_scholarship_percent',(p_input->>'scholarshipMax')::numeric),p_input->>'reason');
 return jsonb_build_object('message','Referrer and collection settings saved.');
end; $$;
revoke all on function public.save_referral_operating_rules(jsonb) from public,anon;
grant execute on function public.save_referral_operating_rules(jsonb) to authenticated;
create function public.preserve_referral_evidence() returns trigger language plpgsql as $$ begin raise exception 'Referral reward evidence is immutable; use a compensating entry.';end;$$;
revoke all on function public.preserve_referral_evidence() from public,anon,authenticated;
create trigger preserve_reward_entries before update or delete on public.referral_reward_entries for each row execute function public.preserve_referral_evidence();
create trigger preserve_reward_contract before update or delete on public.referral_reward_contracts for each row execute function public.preserve_referral_evidence();

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
 if coalesce(identity->>'student_mobile','') !~ '^$|^01[3-9][0-9]{8}$' or coalesce(identity->>'student_email','') !~ '^$|^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Check optional student contact.'; end if;
 identity:=jsonb_build_object('student_mobile',identity->>'student_mobile','student_email',identity->>'student_email','present_landmark',left(identity->>'present_landmark',160),'permanent_address',left(identity->>'permanent_address',300),'permanent_same_as_present',identity->>'permanent_same_as_present','student_name',btrim(identity->>'student_name'),'student_name_bn',nullif(btrim(identity->>'student_name_bn'),''),
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
alter table public.students add column mobile text;
alter table public.students add column email text;
create function public.sync_student_optional_contact() returns trigger language plpgsql security definer set search_path=public as $$ begin
 if new.student_id is not null and not new.existing_student then
  update public.students set mobile=nullif(new.identity_snapshot->>'student_mobile',''),email=nullif(new.identity_snapshot->>'student_email','') where id=new.student_id;
 end if; return new;
end; $$;
revoke all on function public.sync_student_optional_contact() from public,anon,authenticated;
create trigger admission_student_contact after update of student_id,identity_snapshot on public.admission_cases for each row execute function public.sync_student_optional_contact();
do $$ declare a record;begin
 for a in select admission_id from public.admission_referrals where source='REFERRED' order by admission_id loop perform public.sync_referral_reward(a.admission_id);end loop;
end; $$;

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
            where invoice_credits.kind='CANCELLATION'
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
      'cancellation_id',cancellation.admission_id,
      'admission_id',a.id,
      'status','CANCELLED',
      'settlement',settlement
    );

    result:=jsonb_build_object(
      'id',cancellation.admission_id,
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
