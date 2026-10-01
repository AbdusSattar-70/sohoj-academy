-- Workforce evidence is separate from student attendance and approved teaching workload.
insert into public.permissions(code,name,description) values
 ('workforce.self.view','View my work','Own attendance and compensation terms'),
 ('workforce.manage','Manage workforce','Record staff attendance and agreed compensation terms') on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.system_roles r cross join public.permissions p
where (p.code='workforce.self.view' and r.code in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT')) or (p.code='workforce.manage' and r.code='ADMIN') on conflict do nothing;

create table public.staff_attendance_records(
 id uuid primary key default gen_random_uuid(),staff_id uuid not null references public.staff(id),work_date date not null,
 status text not null check(status in('PRESENT','ABSENT','LEAVE','HOLIDAY')),
 started_at timestamptz,ended_at timestamptz,break_minutes integer not null default 0 check(break_minutes between 0 and 1440),
 recorded_by uuid not null references public.profiles(id),reason text not null check(length(btrim(reason))>=5),
 updated_at timestamptz not null default now(),unique(staff_id,work_date),
 check((status='PRESENT' and started_at is not null and ended_at is not null and ended_at>started_at and ended_at-started_at<=interval '24 hours' and extract(epoch from ended_at-started_at)/60>break_minutes) or (status<>'PRESENT' and started_at is null and ended_at is null and break_minutes=0))
);
create index staff_attendance_date_idx on public.staff_attendance_records(work_date,staff_id);
create table public.staff_compensation_terms(
 staff_id uuid primary key references public.staff(id),model text not null check(model in('FIXED','HOURLY','REVENUE_SHARE','HYBRID')),
 monthly_base numeric(14,2) not null default 0 check(monthly_base>=0),hourly_rate numeric(14,2) not null default 0 check(hourly_rate>=0),
 pay_day integer not null check(pay_day between 1 and 28),effective_from date not null,
 recorded_by uuid not null references public.profiles(id),reason text not null check(length(btrim(reason))>=5),updated_at timestamptz not null default now(),
 check((model='FIXED' and monthly_base>0 and hourly_rate=0) or (model='HOURLY' and monthly_base=0 and hourly_rate>0) or (model='REVENUE_SHARE' and monthly_base=0 and hourly_rate=0) or (model='HYBRID' and monthly_base>0))
);
alter table public.staff_attendance_records enable row level security;
alter table public.staff_compensation_terms enable row level security;
create policy staff_attendance_scope on public.staff_attendance_records for select to authenticated using(public.has_permission('workforce.manage') or (public.has_permission('workforce.self.view') and staff_id in(select id from public.staff where profile_id=auth.uid() and status='ACTIVE')));
create policy compensation_terms_scope on public.staff_compensation_terms for select to authenticated using(public.has_permission('workforce.manage') or (public.has_permission('workforce.self.view') and staff_id in(select id from public.staff where profile_id=auth.uid() and status='ACTIVE')));
grant select on public.staff_attendance_records,public.staff_compensation_terms to authenticated;
revoke insert,update,delete on public.staff_attendance_records,public.staff_compensation_terms from anon,authenticated;
create trigger attendance_no_delete before delete on public.staff_attendance_records for each row execute function public.prevent_permanent_record_delete();
create trigger terms_no_delete before delete on public.staff_compensation_terms for each row execute function public.prevent_permanent_record_delete();

create function public.workforce_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();sid uuid:=(p_input->>'staff_id')::uuid;request uuid:=(p_input->>'request_id')::uuid;old_key public.admission_command_keys;
 action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');before_data jsonb;after_data jsonb;result jsonb;day date;start_time timestamptz;end_time timestamptz;
begin
 if actor is null or not public.has_permission('workforce.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Workforce management permission required.';end if;
 if request is null or coalesce(length(reason),0)<5 then raise exception 'A request ID and clear reason are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(request::text,0));
 select * into old_key from public.admission_command_keys where request_id=request;
 if found then if old_key.actor_id<>actor or old_key.payload<>p_input then raise exception 'Request identity conflict.';end if;return old_key.result;end if;
 perform 1 from public.staff where id=sid and status in('ACTIVE','ON_LEAVE') for update;
 if not found then raise exception 'Choose an active staff identity.';end if;
 if action='RECORD_ATTENDANCE' then
  day:=(p_input->>'work_date')::date;
  if day is null or day>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Actual attendance cannot be recorded for a future date.';end if;
  if p_input->>'status'='PRESENT' then
   start_time:=(p_input->>'started_at')::timestamptz;end_time:=(p_input->>'ended_at')::timestamptz;
   if start_time is null or end_time is null or end_time>now() or (start_time at time zone 'Asia/Dhaka')::date<>day then raise exception 'Check the actual start, end and Bangladesh work date.';end if;
  end if;
  if start_time is not null and exists(select 1 from public.staff_attendance_records where staff_id=sid and work_date<>day and status='PRESENT' and started_at<end_time and ended_at>start_time) then raise exception 'These work hours overlap another attendance record.';end if;
  select to_jsonb(a) into before_data from public.staff_attendance_records a where staff_id=sid and work_date=day;
  insert into public.staff_attendance_records(staff_id,work_date,status,started_at,ended_at,break_minutes,recorded_by,reason)
  values(sid,day,p_input->>'status',start_time,end_time,case when p_input->>'status'='PRESENT' then coalesce((p_input->>'break_minutes')::integer,0) else 0 end,actor,reason)
  on conflict(staff_id,work_date) do update set status=excluded.status,started_at=excluded.started_at,ended_at=excluded.ended_at,break_minutes=excluded.break_minutes,recorded_by=actor,reason=excluded.reason,updated_at=now()
  returning to_jsonb(staff_attendance_records.*) into after_data;
 elsif action='SAVE_TERMS' then
  if (p_input->>'effective_from')::date>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Future compensation scheduling is not available yet.';end if;
  select to_jsonb(t) into before_data from public.staff_compensation_terms t where staff_id=sid;
  insert into public.staff_compensation_terms(staff_id,model,monthly_base,hourly_rate,pay_day,effective_from,recorded_by,reason)
  values(sid,p_input->>'model',coalesce((p_input->>'monthly_base')::numeric,0),coalesce((p_input->>'hourly_rate')::numeric,0),(p_input->>'pay_day')::integer,(p_input->>'effective_from')::date,actor,reason)
  on conflict(staff_id) do update set model=excluded.model,monthly_base=excluded.monthly_base,hourly_rate=excluded.hourly_rate,pay_day=excluded.pay_day,effective_from=excluded.effective_from,recorded_by=actor,reason=excluded.reason,updated_at=now()
  returning to_jsonb(staff_compensation_terms.*) into after_data;
 else raise exception 'Unknown workforce action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id)
 values(actor,'STAFF_WORKFORCE',sid::text,action,reason,before_data,after_data,request);
 result:=jsonb_build_object('id',sid,'ok',true);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(request,actor,p_input,result);return result;
end $$;
revoke all on function public.workforce_command(jsonb) from public,anon;
grant execute on function public.workforce_command(jsonb) to authenticated;

create function public.staff_work_workspace(p_month date default null,p_staff_id uuid default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('workforce.manage');sid uuid;first_day date:=date_trunc('month',coalesce(p_month,(now() at time zone 'Asia/Dhaka')::date))::date;last_day date;rows jsonb;terms jsonb;total integer;present integer;hours numeric;effective_hours numeric;pay_date date;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Workforce access required.';end if;
 select id into sid from public.staff where profile_id=actor and status='ACTIVE';
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
 'previousMonthPaid',(select coalesce(sum(s.amount),0) from public.finance_payable_settlements s join public.finance_payables p on p.id=s.payable_id where (p.staff_id=sid or p.referrer_id in(select id from public.referral_people where staff_id=sid)) and (p.payable_type='TEACHER_COMPENSATION' or p.referrer_id is not null) and s.payment_account_id is not null and s.advance_id is null and s.settled_at>=((date_trunc('month',now() at time zone 'Asia/Dhaka')-interval '1 month') at time zone 'Asia/Dhaka') and s.settled_at<(date_trunc('month',now() at time zone 'Asia/Dhaka') at time zone 'Asia/Dhaka')),
 'hourlyEstimate',round(effective_hours*coalesce((terms->>'hourly_rate')::numeric,0),2),
 'people',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name,'number',staff_no) order by full_name),'[]'::jsonb) from public.staff where status in('ACTIVE','ON_LEAVE')) else '[]'::jsonb end);
end $$;
revoke all on function public.staff_work_workspace(date,uuid,integer) from public,anon;
grant execute on function public.staff_work_workspace(date,uuid,integer) to authenticated;
