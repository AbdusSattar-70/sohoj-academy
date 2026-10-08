-- Hydrate existing programme context and put actionable classes first.
create or replace function public.academic_planning_workspace(p_section text,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total int;choices jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Academic planning permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_section not in('offerings','batches','rooms','availability','closures','routines') then raise exception 'Choose an academic planning section/page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where organization_id=org and is_active),'[]'),
 'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name||' · '||o.code,'days',o.teaching_days,'operation_kind',o.operation_kind,'starts_on',coalesce(o.teaching_starts_on,y.starts_on),'ends_on',coalesce(o.teaching_ends_on,y.ends_on))) from public.programme_offerings o left join public.academic_years y on y.id=o.academic_year_id where o.organization_id=org and o.status in('DRAFT','ACTIVE')),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||o.name,'offering_id',o.id,'branch_id',b.branch_id,'capacity',b.capacity,'windows',b.teaching_windows,'days',o.teaching_days)) from public.batches b join public.programme_offerings o on o.id=b.offering_id where b.organization_id=org and b.is_active),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'offerings',coalesce((select jsonb_agg(offering_id) from public.programme_offering_subjects where subject_id=s.id),'[]'))) from public.subjects s where s.organization_id=org and s.is_active),'[]'),
 'teachers',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name||' · '||s.staff_no,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id and(effective_to is null or effective_to>=current_date)),'[]'))) from public.staff s where s.status='ACTIVE' and(s.branch_id is null or s.branch_id in(select id from public.branches where organization_id=org)) and exists(select 1 from public.staff_role_assignments a join public.staff_roles r on r.id=a.staff_role_id where a.staff_id=s.id and r.is_teaching_role and(a.effective_to is null or a.effective_to>=current_date))),'[]'),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'name',v.title||' · v'||v.version,'batch_id',v.batch_id,'subject_id',v.subject_id)) from public.curriculum_versions v join public.batches b on b.id=v.batch_id where b.organization_id=org),'[]'),
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'branch_id',r.branch_id,'capacity',r.capacity)) from public.academic_rooms r join public.branches b on b.id=r.branch_id where b.organization_id=org and r.is_active),'[]')) into choices;
 with items as(
 select to_jsonb(o)||jsonb_build_object('label',o.name) item,o.id from public.programme_offerings o where p_section='offerings' and o.organization_id=org
 union all select to_jsonb(b)||jsonb_build_object('label',b.name||' · '||o.name),b.id from public.batches b join public.programme_offerings o on o.id=b.offering_id where p_section='batches' and b.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',r.name),r.id from public.academic_rooms r join public.branches b on b.id=r.branch_id where p_section='rooms' and b.organization_id=org
 union all select to_jsonb(a)||jsonb_build_object('label',coalesce(r.name,s.full_name)||' · '||a.resource_kind),a.id from public.academic_availability a left join public.academic_rooms r on r.id=a.resource_id and a.resource_kind='ROOM' left join public.staff s on s.id=a.resource_id and a.resource_kind='TEACHER' where p_section='availability' and a.organization_id=org
 union all select to_jsonb(c)||jsonb_build_object('label',c.label),c.id from public.academic_closures c where p_section='closures' and c.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',b.name||' · '||s.name,'teacher',t.full_name,'room',rm.name),r.id from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where p_section='routines' and b.organization_id=org),paged as(select * from items order by item->>'label',id limit 25 offset(p_page-1)*25)
 select (select count(*) from items),coalesce((select jsonb_agg(item order by item->>'label',id) from paged),'[]') into total,rows;
 return jsonb_build_object('section',p_section,'page',p_page,'total',total,'choices',choices,'rows',rows);
end $$;
create or replace function public.academic_calendar(p_from date,p_to date,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$declare org uuid;result jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Academic access required.';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>31 or p_page is null or p_page not between 1 and 10000 then raise exception 'Choose up to 32 days and a valid page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 with visible as(select s.*,b.name batch,su.name subject,t.full_name teacher,r.name room,
 (select status from public.attendance_submissions where session_id=s.id order by revision desc limit 1) attendance,(select max(revision) from public.attendance_submissions where session_id=s.id and status='APPROVED') approved_revision,
 (select status from public.class_logs where session_id=s.id order by revision desc limit 1) report_status
 from public.class_sessions s join public.batches b on b.id=s.batch_id join public.subjects su on su.id=s.subject_id join public.staff t on t.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id where b.organization_id=org and s.session_date between p_from and p_to and public.can_access_class_session(s.id)),paged as(select * from visible order by case when session_date=(now() at time zone 'Asia/Dhaka')::date then 0 when report_status='SUBMITTED' then 1 when session_date>(now() at time zone 'Asia/Dhaka')::date then 2 else 3 end,starts_at,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('page',p_page,'total',(select count(*) from visible),'rows',coalesce((select jsonb_agg(to_jsonb(p) order by case when session_date=(now() at time zone 'Asia/Dhaka')::date then 0 when report_status='SUBMITTED' then 1 when session_date>(now() at time zone 'Asia/Dhaka')::date then 2 else 3 end,starts_at,id) from paged p),'[]'),'pendingReports',(select count(*) from visible where report_status='SUBMITTED'),'canManage',public.has_permission('academics.sessions.manage')) into result;return result;
end $$;
notify pgrst,'reload schema';

-- Preserve the branch fixed/hourly contract exclusions and unified referral accrual.
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
        sum(public.verified_teaching_hours(cs.id)) as session_count
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
          'workloadUnit','HOURS',
          'approvedTeachingHours',batch_row.session_count,
          'batchApprovedTeachingHours',batch_row.total_sessions,
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
create or replace function public.referrer_workspace(p_referrer_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare manager boolean:=public.has_permission('staff.compensation.manage') or public.has_permission('admissions.create'); rid uuid; person public.referral_people; students jsonb; org uuid; policy jsonb; teacher_policy jsonb; teaching boolean:=false; teaching_lines jsonb; teaching_payments jsonb; teacher_earned numeric:=0; teacher_settled numeric:=0; advances numeric:=0;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Active sign-in required.'; end if;
 if not manager and not public.has_permission('referrals.portal.view') then raise exception 'Referral account access required.';end if;
 if manager and p_referrer_id is not null then rid:=p_referrer_id;
 else select r.id into rid from public.referral_people r left join public.staff s on s.id=r.staff_id
  where r.is_active and (r.profile_id=auth.uid() or (s.profile_id=auth.uid() and s.status='ACTIVE')) order by (r.profile_id=auth.uid()) desc,r.created_at limit 1;
  if not manager and p_referrer_id is not null and p_referrer_id is distinct from rid then raise exception 'Only your own referrals are available.';end if;
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
 select payload into policy from public.business_rule_versions where domain='referrals' and rule_key='acquisition_policy' and status='ACTIVE' order by version desc limit 1;
 select payload into teacher_policy from public.business_rule_versions where domain='teacher_compensation' and rule_key='default_policy' and status='ACTIVE' order by version desc limit 1;
 teaching:=exists(select 1 from public.staff_role_assignments a join public.staff_roles r on r.id=a.staff_role_id where a.staff_id=person.staff_id and r.code in('TEACHER','ACADEMIC_DIRECTOR') and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date));
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'run',r.run_no,'from',r.period_start,'to',r.period_end,'type',l.line_type,'amount',l.amount,'netTuition',l.calculation->'netCollectedTuition','poolPercent',l.calculation->'poolPercent','workloadUnit',coalesce(l.calculation->>'workloadUnit','SESSIONS'),'approvedSessions',l.calculation->'approvedSessions','batchApprovedSessions',l.calculation->'batchApprovedSessions') order by r.period_end desc,l.id),'[]'::jsonb),coalesce(sum(l.amount),0) into teaching_lines,teacher_earned
 from public.teacher_compensation_lines l join public.teacher_compensation_runs r on r.id=l.run_id where l.teacher_id=person.staff_id and r.status='APPROVED' and l.line_type<>'ACQUISITION_BONUS';
 -- Attribute historical mixed settlements proportionately; acquisition stays in the referral statement.
 select coalesce(jsonb_agg(jsonb_build_object('date',s.settled_at,'run',r.run_no,'gross',round(s.gross_amount*coalesce(t.non_acquisition/nullif(t.total,0),0),2),'cash',round(s.cash_paid*coalesce(t.non_acquisition/nullif(t.total,0),0),2),'advanceOffset',round(s.advance_offset*coalesce(t.non_acquisition/nullif(t.total,0),0),2),'reference',s.external_reference) order by s.settled_at desc),'[]'::jsonb),coalesce(sum(round(s.gross_amount*coalesce(t.non_acquisition/nullif(t.total,0),0),2)),0) into teaching_payments,teacher_settled
 from public.teacher_compensation_settlements s join public.teacher_compensation_runs r on r.id=s.run_id
 cross join lateral(select sum(amount) total,sum(amount) filter(where line_type<>'ACQUISITION_BONUS') non_acquisition from public.teacher_compensation_lines where run_id=s.run_id and teacher_id=s.teacher_id) t where s.teacher_id=person.staff_id;
 select coalesce(sum(public.advance_balance(a.id)),0) into advances from public.finance_advances a where a.staff_id=person.staff_id and a.status in('PAID','PARTIALLY_SETTLED','OVERDUE');
 return jsonb_build_object('manager',manager,'people',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.full_name,'mobile',r.mobile,'email',r.email,'staffId',r.staff_id,'profileId',coalesce(r.profile_id,s.profile_id),'active',r.is_active,'relationship',r.relationship_note,'notes',r.contact_note) order by r.full_name),'[]'::jsonb) from public.referral_people r left join public.staff s on s.id=r.staff_id) else '[]'::jsonb end,
 'selected',rid,'name',person.full_name,'students',students,
 'policy',jsonb_build_object('acquisitionPercent',policy->'bonus_percent','teachingPoolPercent',teacher_policy->'teaching_pool_percent','teachingReviewMaxPercent',teacher_policy->'teaching_pool_review_max_percent','retention3Percent',teacher_policy->'retention_3_month_percent','retention6Percent',teacher_policy->'retention_6_month_percent'),
 'teacher',teaching,'teachingLines',teaching_lines,'teachingPayments',teaching_payments,'teachingEarned',teacher_earned,'teachingSettled',teacher_settled,'advanceOutstanding',advances,
 'ownReferrerId',(select r.id from public.referral_people r left join public.staff s on s.id=r.staff_id where r.is_active and (r.profile_id=auth.uid() or s.profile_id=auth.uid()) order by r.created_at limit 1),
 'earned',(select coalesce(sum(amount),0) from public.referral_reward_entries where referrer_id=rid),'settled',public.referrer_paid(rid),
 'entries',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'amount',amount,'collected',net_collected,'rate',bonus_percent,'date',created_at) order by created_at desc),'[]'::jsonb) from public.referral_reward_entries where referrer_id=rid),
 'settlements',(select coalesce(jsonb_agg(jsonb_build_object('amount',s.amount,'date',s.settled_at,'reference',s.external_reference) order by s.settled_at desc),'[]'::jsonb) from public.finance_payable_settlements s join public.finance_payables p on p.id=s.payable_id where p.referrer_id=rid),
 'accounts',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)),'[]'::jsonb) from public.finance_accounts where organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')) else '[]'::jsonb end);
end; $$;
notify pgrst,'reload schema';
