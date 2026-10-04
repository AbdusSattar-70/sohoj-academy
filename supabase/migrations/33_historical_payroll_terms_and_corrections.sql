-- Historical agreement evidence is month-specific, not a replacement of current terms.
create table public.staff_payroll_month_terms (
 id uuid primary key default gen_random_uuid(),staff_id uuid not null references public.staff(id),month date not null check(extract(day from month)=1),terms jsonb not null,reason text not null,actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),event_order bigint generated always as identity unique
);
create table public.staff_payroll_adjustments (
 id uuid primary key default gen_random_uuid(),payroll_id uuid not null references public.staff_payroll_records(id),amount numeric(14,2) not null check(amount<>0 and amount<>'NaN'::numeric),posted_on date not null,reason text not null,actor_id uuid not null references public.profiles(id),journal_id uuid not null unique references public.general_ledger_journals(id),created_at timestamptz not null default now()
);
alter table public.staff_payroll_month_terms enable row level security;
alter table public.staff_payroll_adjustments enable row level security;
revoke all on public.staff_payroll_month_terms,public.staff_payroll_adjustments from public,anon,authenticated;
create trigger month_terms_immutable before update or delete on public.staff_payroll_month_terms for each row execute function public.prevent_permanent_record_delete();
create trigger payroll_adjustment_immutable before update or delete on public.staff_payroll_adjustments for each row execute function public.prevent_permanent_record_delete();
create function public.payroll_recovery_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();request uuid:=(p_input->>'request_id')::uuid;reason text:=btrim(p_input->>'reason');key public.admission_command_keys;sid uuid;mon date;rec public.staff_payroll_records;pay public.finance_payables;amount numeric;paid numeric;model text;terms jsonb;org uuid;ea uuid;journal uuid;rid uuid:=gen_random_uuid();res jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 if actor is null or not public.has_permission('payroll.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Payroll management permission required.';end if;
 if request is null or coalesce(length(reason),0) not between 5 and 1000 then raise exception 'Request identity and a clear explanation are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(request::text,0));select * into key from public.admission_command_keys where request_id=request;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if p_input->>'action'='RECOVER_TERMS' then
  sid:=(p_input->>'staff_id')::uuid;mon:=(p_input->>'month')::date;
  perform 1 from public.staff where id=sid and status in('ACTIVE','ON_LEAVE') for update;if not found then raise exception 'Choose current staff.';end if;
  if mon is null or extract(day from mon)<>1 or mon>=date_trunc('month',day)::date then raise exception 'Recovery applies to a completed payroll month.';end if;
  if exists(select 1 from public.staff_payroll_records where staff_id=sid and month=mon) then raise exception 'Salary already posted. Use a payroll adjustment.';end if;
  model:=p_input->>'model';
  if model not in('FIXED','HOURLY','HYBRID') or coalesce((p_input->>'monthly_base')::numeric,-1)<0 or coalesce((p_input->>'hourly_rate')::numeric,-1)<0 or (p_input->>'monthly_base')::numeric='NaN'::numeric or (p_input->>'hourly_rate')::numeric='NaN'::numeric or (p_input->>'monthly_base')::numeric<>round((p_input->>'monthly_base')::numeric,2) or (p_input->>'hourly_rate')::numeric<>round((p_input->>'hourly_rate')::numeric,2) or coalesce((p_input->>'pay_day')::int,0) not between 1 and 28 then raise exception 'Check finite salary, hourly rate and pay day.';end if;
  if (model='FIXED' and ((p_input->>'monthly_base')::numeric<=0 or (p_input->>'hourly_rate')::numeric<>0)) or (model='HOURLY' and ((p_input->>'monthly_base')::numeric<>0 or (p_input->>'hourly_rate')::numeric<=0)) or (model='HYBRID' and (p_input->>'monthly_base')::numeric<=0) then raise exception 'Amounts do not match the agreement model.';end if;
  if (p_input->>'effective_from')::date is null or (p_input->>'effective_from')::date>=mon+interval '1 month' then raise exception 'Agreement must cover this month.';end if;
  terms:=jsonb_build_object('staff_id',sid,'model',model,'monthly_base',(p_input->>'monthly_base')::numeric,'hourly_rate',(p_input->>'hourly_rate')::numeric,'pay_day',(p_input->>'pay_day')::integer,'effective_from',(p_input->>'effective_from')::date,'recorded_by',actor,'reason',reason,'updated_at',now());
  insert into public.staff_payroll_month_terms(id,staff_id,month,terms,reason,actor_id) values(rid,sid,mon,terms,reason,actor);
 elsif p_input->>'action'='ADJUST' then
  select * into rec from public.staff_payroll_records where id=(p_input->>'id')::uuid for update;if not found then raise exception 'Payroll unavailable.';end if;
  select * into pay from public.finance_payables where id=rec.payable_id for update;
  amount:=(p_input->>'amount')::numeric;
  if amount is null or amount=0 or amount='NaN'::numeric or amount<>round(amount,2) then raise exception 'Enter a nonzero finite salary correction.';end if;
  paid:=coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=pay.id),0);
  if pay.original_amount+amount<=0 or pay.original_amount+amount<paid then raise exception 'Adjusted salary must be positive and cannot be below settled salary. Recover actual overpayments separately.';end if;
  org:=pay.organization_id;select id into ea from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYROLL_EXPENSE' and is_active;
  journal:=public.finance_post_journal(org,day,'COMPENSATION_RUN','STAFF_PAYROLL_ADJUSTMENT',rid::text,'Salary correction '||rec.payroll_no,actor,jsonb_build_array(jsonb_build_object('account_id',ea,'debit',greatest(amount,0),'credit',greatest(-amount,0)),jsonb_build_object('account_id',pay.payable_account_id,'debit',greatest(-amount,0),'credit',greatest(amount,0))));
  insert into public.staff_payroll_adjustments(id,payroll_id,amount,posted_on,reason,actor_id,journal_id) values(rid,rec.id,amount,day,reason,actor,journal);
  update public.finance_payables set original_amount=original_amount+amount,status=case when original_amount+amount=paid then 'SETTLED' when paid>0 then 'PARTIALLY_SETTLED' else 'OPEN' end where id=pay.id;
 else raise exception 'Unknown recovery action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'STAFF_PAYROLL',coalesce(rec.id,sid)::text,p_input->>'action',reason,jsonb_build_object('evidenceId',rid,'amount',amount,'terms',terms),request);
 res:=jsonb_build_object('id',rid,'ok',true);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(request,actor,p_input,res);return res;
end $$;
revoke all on function public.payroll_recovery_command(jsonb) from public,anon;
grant execute on function public.payroll_recovery_command(jsonb) to authenticated;

create or replace function public.staff_payroll_preview(p_input jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid:=(p_input->>'staff_id')::uuid;month_value date:=(p_input->>'month')::date;last_day date;eligible date;terms public.staff_compensation_terms;person public.staff;hours numeric:=0;base numeric:=0;hourly numeric:=0;allowance numeric:=0;corrections numeric:=0;item jsonb;attendance jsonb;snapshot jsonb;
begin
 if auth.uid() is null or not public.has_permission('payroll.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Payroll management permission required.';end if;
 if month_value is null or extract(day from month_value)<>1 or month_value>date_trunc('month',now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose a current or previous payroll month.';end if;
 last_day:=(month_value+interval '1 month')::date;
 select * into person from public.staff where id=sid and status in('ACTIVE','ON_LEAVE');if person.id is null then raise exception 'Choose current staff.';end if;
 select (jsonb_populate_record(null::public.staff_compensation_terms,t.terms)).* into terms from public.staff_payroll_month_terms t where t.staff_id=sid and t.month=month_value order by t.event_order desc limit 1; if not found then select * into terms from public.staff_compensation_terms where staff_id=sid;end if;if terms.staff_id is null then raise exception 'Configure agreed compensation terms before payroll.';end if;
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


create or replace function public.staff_payroll_workspace(p_id uuid default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('payroll.manage');sid uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Payroll access required.';end if;
 select id into sid from public.staff where profile_id=auth.uid();
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Invalid page.';end if;
 if p_id is not null and not exists(select 1 from public.staff_payroll_records where id=p_id and (manager or staff_id=sid)) then raise exception 'Payslip unavailable.';end if;
 select count(*) into total from public.staff_payroll_records where (manager or staff_id=sid) and (p_id is null or id=p_id);
 select coalesce(jsonb_agg(to_jsonb(r) order by r.month desc,r.id),'[]'::jsonb) into rows from(select r.id,r.payroll_no,r.staff_id,r.month,r.snapshot,r.gross,r.corrections,p.original_amount net,r.due_on,r.posted_at,p.status, r.net original_net, (select coalesce(jsonb_agg(jsonb_build_object('date',c.posted_on,'amount',c.amount,'reason',c.reason,'actor',pr.display_name) order by c.created_at,c.id),'[]'::jsonb) from public.staff_payroll_adjustments c join public.profiles pr on pr.id=c.actor_id where c.payroll_id=r.id) adjustments,coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0) settled,
 (select coalesce(jsonb_agg(jsonb_build_object('date',s.settled_at,'amount',s.amount,'offset',s.advance_id is not null,'reference',s.external_reference) order by s.settled_at),'[]'::jsonb) from public.finance_payable_settlements s where s.payable_id=r.payable_id) payments
 from public.staff_payroll_records r join public.finance_payables p on p.id=r.payable_id where (manager or r.staff_id=sid) and (p_id is null or r.id=p_id) order by r.month desc,r.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('manager',manager,'total',total,'records',rows,
 'people',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no) order by full_name),'[]'::jsonb) from public.staff where status in('ACTIVE','ON_LEAVE')) else '[]'::jsonb end,
 'accounts',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by code),'[]'::jsonb) from public.finance_accounts where is_active and account_subtype in('CASH','BANK','MOBILE_BANK')) else '[]'::jsonb end,
 'advances',case when manager then(select coalesce(jsonb_agg(jsonb_build_object('id',id,'staffId',staff_id,'name',advance_no,'balance',public.advance_balance(id))),'[]'::jsonb) from public.finance_advances where beneficiary_type='STAFF' and public.advance_balance(id)>0) else '[]'::jsonb end);
end $$;
revoke all on function public.staff_payroll_workspace(uuid,integer) from public,anon;
grant execute on function public.staff_payroll_workspace(uuid,integer) to authenticated;


create or replace function public.my_salary_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid;last_record public.staff_payroll_records;
begin
 if auth.uid() is null or not public.has_permission('workforce.self.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Own workforce access required.';end if;
 select id into sid from public.staff where profile_id=auth.uid();
 select * into last_record from public.staff_payroll_records where staff_id=sid order by month desc limit 1;
 return jsonb_build_object('latestMonth',last_record.month,'latestNet',(select original_amount from public.finance_payables where id=last_record.payable_id),
 'outstanding',(select coalesce(sum(p.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0)),0) from public.staff_payroll_records r join public.finance_payables p on p.id=r.payable_id where r.staff_id=sid),
 'nextDue',(select min(r.due_on) from public.staff_payroll_records r where r.staff_id=sid and (select original_amount from public.finance_payables where id=r.payable_id)>coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=r.payable_id),0)));
end $$;
revoke all on function public.my_salary_summary() from public,anon;
grant execute on function public.my_salary_summary() to authenticated;
