-- Request-only staff onboarding and own financial statements. No historical identities are deleted.
alter table public.staff_access_requests drop constraint staff_access_requests_status_check;
alter table public.staff_access_requests add constraint staff_access_requests_status_check check(status in('PENDING','VERIFIED','INVITED','ACTIVE','DECLINED','INACTIVE'));
-- Backfill only accounts that have actually signed in; staff lifecycle ACTIVE alone is not proof.
update public.staff_access_requests r set status='ACTIVE' from auth.users u
where r.profile_id=u.id and r.status='INVITED' and nullif(to_jsonb(u)->>'last_sign_in_at','') is not null;

create function public.sync_staff_referrer() returns trigger language plpgsql security definer set search_path=public as $$
declare existing public.referral_people; other_count integer; org uuid;
begin
 if new.profile_id is null or new.status<>'ACTIVE' then return new;end if;
 select organization_id into org from public.branches where id=new.branch_id;
 if org is null then select id into org from public.organizations order by created_at limit 1;end if;
 select * into existing from public.referral_people where staff_id=new.id;
 if existing.id is not null then
  if existing.profile_id is null and not exists(select 1 from public.referral_people where profile_id=new.profile_id and id<>existing.id) then update public.referral_people set profile_id=new.profile_id where id=existing.id;end if;
  return new;
 end if;
 select * into existing from public.referral_people where profile_id=new.profile_id;
 if existing.id is not null then
  if existing.staff_id is not null and existing.staff_id<>new.id then raise exception 'This account is linked to another staff identity. Resolve the identity before continuing.';end if;
  update public.referral_people set staff_id=new.id where id=existing.id;return new;
 end if;
 -- Preserve a unique existing external referrer with the same mobile instead of issuing a duplicate ID.
 select * into existing from public.referral_people where organization_id=org and mobile=new.mobile;
 if existing.id is not null then
  if existing.staff_id is not null or existing.profile_id is not null or lower(btrim(existing.full_name))<>lower(btrim(new.full_name)) then
   return new; -- ambiguous identity: portal shows an empty account; admin must verify the link
  end if;
  update public.referral_people set staff_id=new.id,profile_id=new.profile_id where id=existing.id;return new;
 end if;
 insert into public.referral_people(organization_id,staff_id,full_name,mobile,email,profile_id,created_by)
 values(org,new.id,new.full_name,new.mobile,new.email,new.profile_id,coalesce(auth.uid(),new.created_by)) on conflict(staff_id) do nothing;
 return new;
end $$;
revoke all on function public.sync_staff_referrer() from public,anon,authenticated;
create trigger staff_referrer_identity after insert or update of profile_id on public.staff for each row execute function public.sync_staff_referrer();
-- Reuse existing referral records; no UPDATE of immutable reward contracts or posted journals.
do $$ declare s public.staff;begin for s in select * from public.staff where profile_id is not null and status='ACTIVE' loop
 update public.staff set profile_id=profile_id where id=s.id;
end loop;end $$;

create function public.complete_own_staff_access() returns void language plpgsql security definer set search_path=public as $$
declare updated public.staff_access_requests;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then return;end if;
 for updated in update public.staff_access_requests r set status='ACTIVE' where r.profile_id=auth.uid() and r.status='INVITED'
 and exists(select 1 from public.staff s where s.profile_id=auth.uid() and s.status='ACTIVE')
 and exists(select 1 from public.user_role_assignments a join public.system_roles ro on ro.id=a.role_id where a.profile_id=auth.uid() and a.is_active and ro.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date)) returning r.* loop
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason) values(auth.uid(),'STAFF_ACCESS_REQUEST',updated.id::text,'ACCOUNT_ACTIVATED','Verified account accessed the academy workspace');
 end loop;
end $$;
revoke all on function public.complete_own_staff_access() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.my_erp_context()
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 perform public.complete_own_staff_access();
 return (select jsonb_build_object(
    'profile_id', p.id,
    'display_name', p.display_name,
    'status', p.status,
    'staff_id', s.id,
    'staff_no', s.staff_no,
    'staff_name', s.full_name,
    'roles', coalesce((
      select jsonb_agg(distinct sr.code order by sr.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct pe.code order by pe.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      join public.role_permissions rp on rp.role_id = sr.id
      join public.permissions pe on pe.id = rp.permission_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb)
  )
  from public.profiles p
  left join public.staff s on s.profile_id = p.id
  where p.id = auth.uid());
end
$function$;

CREATE OR REPLACE FUNCTION public.review_staff_access(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.staff_access_requests; role_value text:=p_input->>'assigned_role'; user_id uuid; matched_staff uuid; matching_count integer;
begin
 if auth.uid() is null or not public.has_permission('system.users.manage') then raise exception 'User management permission required.'; end if;
 if not exists(select 1 from public.user_role_assignments a join public.system_roles ro on ro.id=a.role_id
 where a.profile_id=auth.uid() and a.is_active and ro.code='ADMIN' and ro.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date)) then raise exception 'Super admin verification required.'; end if;
 select * into r from public.staff_access_requests where id=(p_input->>'id')::uuid for update;
 if r.id is null then raise exception 'Request not found.'; end if;
 if p_input->>'action'='DECLINE' then
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be declined.'; end if;
  update public.staff_access_requests set status='DECLINED',reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='VERIFY' then
  if role_value not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT') then raise exception 'Choose a role.'; end if;
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be verified.'; end if;
  update public.staff_access_requests set status='VERIFIED',assigned_role=role_value,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='COMPLETE_INVITATION' then
  if r.status not in('VERIFIED','INVITED') then raise exception 'Verify the request before inviting.'; end if;
  -- Identity is resolved from the verified request email, never an arbitrary caller ID.
  select id into user_id from auth.users where lower(email)=r.email;
  if user_id is null then raise exception 'Supabase invitation has not created the user yet.'; end if;
  insert into public.profiles(id,display_name) values(user_id,r.full_name) on conflict(id) do nothing;
  select id into matched_staff from public.staff where profile_id=user_id;
  if matched_staff is null then
   select count(*),min(id::text)::uuid into matching_count,matched_staff from public.staff where profile_id is null and status='ACTIVE'
    and (lower(email)=r.email or (email is null and mobile=r.mobile and lower(btrim(full_name))=lower(btrim(r.full_name))));
   if matching_count>1 then raise exception 'Multiple existing identities match this request. Verify and correct the existing staff records first.';end if;
   if matched_staff is not null then update public.staff set profile_id=user_id,email=r.email where id=matched_staff;
   else insert into public.staff(profile_id,full_name,email,mobile,joined_on,created_by) values(user_id,r.full_name,r.email,r.mobile,current_date,auth.uid()) returning id into matched_staff;end if;
  end if;
  if not exists(select 1 from public.system_roles where code=r.assigned_role and is_active) then raise exception 'Assigned role is unavailable.'; end if;
  insert into public.user_role_assignments(profile_id,role_id,assigned_by)
   select user_id,id,auth.uid() from public.system_roles where code=r.assigned_role and is_active
   on conflict do nothing;
  insert into public.staff_role_assignments(staff_id,staff_role_id,is_primary,assigned_by)
   select s.id,role.id,true,auth.uid() from public.staff s join public.staff_roles role on role.code=r.assigned_role and role.is_active
   where s.profile_id=user_id and not exists(select 1 from public.staff_role_assignments old where old.staff_id=s.id and old.is_primary and old.effective_to is null);
  update public.staff_access_requests set status='INVITED',profile_id=user_id,invitation_sent_at=now() where id=r.id;
 else raise exception 'Unsupported staff verification action.';
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason)
 values(auth.uid(),'STAFF_ACCESS_REQUEST',r.id::text,p_input->>'action',coalesce(p_input->>'reason','Verified staff invitation'));
 return jsonb_build_object('id',r.id);
end $function$;

-- Old clients cannot bypass the request/verification identity path.
create or replace function public.create_staff_member(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
begin raise exception 'Staff identities are issued from verified access requests. Use People → Staff access requests.';end $$;
revoke all on function public.create_staff_member(jsonb) from public,anon,authenticated;

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
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'run',r.run_no,'from',r.period_start,'to',r.period_end,'type',l.line_type,'amount',l.amount,'netTuition',l.calculation->'netCollectedTuition','poolPercent',l.calculation->'poolPercent','approvedSessions',l.calculation->'approvedSessions','batchApprovedSessions',l.calculation->'batchApprovedSessions') order by r.period_end desc,l.id),'[]'::jsonb),coalesce(sum(l.amount),0) into teaching_lines,teacher_earned
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
