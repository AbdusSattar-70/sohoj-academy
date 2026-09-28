-- Admission referral capture and independently approved external acquisition reward.
create table public.referral_people (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  staff_id uuid unique references public.staff(id),
  full_name text not null check(length(btrim(full_name))>=2),
  mobile text,
  relationship_note text,
  contact_note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check(staff_id is not null or mobile ~ '^01[3-9][0-9]{8}$'),
  unique(organization_id,mobile)
);
create table public.admission_referrals (
  admission_id uuid primary key references public.admission_cases(id),
  source text not null check(source in('ORGANIC','REFERRED')),
  referrer_id uuid references public.referral_people(id),
  captured_by uuid not null references public.profiles(id),
  captured_at timestamptz not null default now(),
  reason text not null,
  check((source='ORGANIC' and referrer_id is null) or
        (source='REFERRED' and referrer_id is not null))
);
create table public.referral_bonus_awards (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admission_cases(id),
  referrer_id uuid not null references public.referral_people(id),
  period_start date not null,
  net_collected numeric(14,2) not null check(net_collected>0),
  policy_version_id uuid not null references public.business_rule_versions(id),
  bonus_percent numeric(7,3) not null check(bonus_percent>=0),
  amount numeric(14,2) not null check(amount>0),
  status text not null default 'PENDING' check(status in('PENDING','APPROVED','REJECTED')),
  approval_id uuid not null unique references public.approval_requests(id),
  payable_id uuid unique references public.finance_payables(id),
  requested_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create unique index referral_bonus_one_live_award on public.referral_bonus_awards(admission_id)
  where status in('PENDING','APPROVED');
alter table public.finance_payables add column referrer_id uuid references public.referral_people(id);
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'2130','Referral Reward Payable','LIABILITY','REFERRER_PAYABLE',true from public.organizations
on conflict(organization_id,code) do nothing;
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'5200','Student Acquisition Expense','EXPENSE','ACQUISITION_EXPENSE',true from public.organizations
on conflict(organization_id,code) do nothing;

alter table public.referral_people enable row level security;
alter table public.admission_referrals enable row level security;
alter table public.referral_bonus_awards enable row level security;
grant select on public.referral_people,public.admission_referrals,public.referral_bonus_awards to authenticated;
revoke insert,update,delete on public.referral_people,public.admission_referrals,public.referral_bonus_awards from anon,authenticated;
create policy referral_people_read on public.referral_people for select to authenticated
  using(public.has_permission('admissions.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));
create policy admission_referrals_read on public.admission_referrals for select to authenticated
  using(public.has_permission('admissions.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));
create policy referral_bonus_awards_read on public.referral_bonus_awards for select to authenticated
  using(public.has_permission('staff.compensation.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));

-- Preserve previously recorded teacher referrals and mark all historical
-- admissions without one as Organic. Existing financial history is untouched.
insert into public.referral_people(organization_id,staff_id,full_name,mobile,created_by)
select o.id,s.id,s.full_name,null,tr.captured_by
from public.teacher_referrals tr join public.staff s on s.id=tr.teacher_id
cross join lateral (select id from public.organizations where code='SOHOJ' limit 1) o
on conflict(staff_id) do nothing;
insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
select a.id,case when tr.id is null then 'ORGANIC' else 'REFERRED' end,
 rp.id,coalesce(tr.captured_by,a.created_by),'Historical referral classification'
from public.admission_cases a left join public.teacher_referrals tr on tr.admission_id=a.id
left join public.referral_people rp on rp.staff_id=tr.teacher_id
where a.status not in('DRAFT','READY') and coalesce(tr.captured_by,a.created_by) is not null
on conflict(admission_id) do nothing;

-- Keep the referral decision explicit before an admission is accepted.
create function public.require_admission_referral_choice() returns trigger language plpgsql
set search_path=public as $$
begin
 if new.status='ACCEPTED' and old.status is distinct from new.status and
    not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
   raise exception 'Record a referrer or select Organic before accepting this admission.';
 end if;
 return new;
end $$;
create trigger admission_referral_choice_gate before update of status on public.admission_cases
 for each row execute function public.require_admission_referral_choice();
revoke execute on function public.require_admission_referral_choice() from public,anon,authenticated;

create function public.teacher_referral_matches_admission() returns trigger language plpgsql
set search_path=public as $$
begin
 if not exists(select 1 from public.admission_referrals ar
   join public.referral_people rp on rp.id=ar.referrer_id
   where ar.admission_id=new.admission_id and ar.source='REFERRED' and rp.staff_id=new.teacher_id) then
  raise exception 'Teacher referral must match the verified admission referral.';
 end if;
 return new;
end $$;
create trigger teacher_referral_match before insert or update on public.teacher_referrals
 for each row execute function public.teacher_referral_matches_admission();
revoke execute on function public.teacher_referral_matches_admission() from public,anon,authenticated;

create function public.referral_command(p_input jsonb) returns jsonb language plpgsql security definer
set search_path=public as $$
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
 approval public.approval_requests;
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
    action='REQUEST_BONUS' and not public.has_permission('staff.compensation.manage') or
    action='DECIDE_BONUS' and not public.has_permission('staff.compensation.approve') or
    action not in('CAPTURE','REQUEST_BONUS','DECIDE_BONUS') then
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
  if a.id is null or a.status not in('DRAFT','READY') then
   raise exception 'Referral choice must be recorded before admission acceptance.'; end if;
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
 elsif action='REQUEST_BONUS' then
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
  insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
   values('REFERRAL_BONUS','ADMISSION',a.id::text,'REQUEST_BONUS',
      jsonb_build_object('admission_id',a.id,'referrer_id',person.id,'period_start',first_month,'net_collected',collected,'policy_version_id',policy.id,'bonus_percent',rate,'amount',amount),
      reason,actor,req) returning * into approval;
  insert into public.referral_bonus_awards(admission_id,referrer_id,period_start,net_collected,policy_version_id,
      bonus_percent,amount,approval_id,requested_by)
   values(a.id,person.id,first_month,collected,policy.id,rate,amount,approval.id,actor)
   returning * into award;
  result:=jsonb_build_object('id',award.id,'message','Referral reward submitted for independent approval.');
 else
  select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid
    and workflow_type='REFERRAL_BONUS' and status='PENDING' for update;
  if approval.id is null or approval.requested_by=actor then
    raise exception 'A different authorized staff member must review the pending reward.'; end if;
  select * into award from public.referral_bonus_awards where approval_id=approval.id for update;
  if p_input->>'decision' not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
  if p_input->>'decision'='APPROVED' then
   select * into a from public.admission_cases where id=award.admission_id for update;
   select * into referral from public.admission_referrals where admission_id=a.id;
   if a.status<>'ACTIVE_ENROLLMENT' or referral.referrer_id<>award.referrer_id or
      exists(select 1 from public.finance_payables where source_type='REFERRAL_BONUS' and source_id=a.id::text) then
      raise exception 'Admission or referral changed; review this reward again.'; end if;
   select coalesce(sum(n.tuition_collected),0) into collected
    from public.finance_net_collected_tuition(award.period_start,(award.period_start+interval '1 month - 1 day')::date) n
    where n.admission_id=a.id;
   if collected<award.net_collected then
     raise exception 'Net collected tuition decreased after the request; reject and recalculate the reward.';
   end if;
   select id into org from public.organizations where code='SOHOJ' and is_active;
   insert into public.finance_payables(organization_id,payable_type,referrer_id,source_type,source_id,payable_account_id,
     original_amount,due_on,created_by)
   values(org,'OTHER',award.referrer_id,'REFERRAL_BONUS',a.id::text,
     (select id from public.finance_accounts where organization_id=org and code='2130'),award.amount,current_date,actor)
   returning * into payable;
   perform public.finance_post_journal(org,current_date,'COMPENSATION_RUN','REFERRAL_BONUS',award.id::text,
      'Approved referral acquisition reward',actor,jsonb_build_array(
       jsonb_build_object('account_id',(select id from public.finance_accounts where organization_id=org and code='5200'),'debit',award.amount,'credit',0),
       jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',award.amount)));
   update public.referral_bonus_awards set status='APPROVED',payable_id=payable.id,
     reviewed_by=actor,reviewed_at=now() where id=award.id;
  else
   update public.referral_bonus_awards set status='REJECTED',reviewed_by=actor,
      reviewed_at=now() where id=award.id;
  end if;
  update public.approval_requests set status=(p_input->>'decision')::public.approval_status,
    decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
  result:=jsonb_build_object('id',award.id,'message','Referral reward reviewed.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ADMISSION_REFERRAL',result->>'id',action,reason,result,jsonb_build_object('module','referrals'));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end $$;
revoke execute on function public.referral_command(jsonb) from public,anon;
grant execute on function public.referral_command(jsonb) to authenticated;
