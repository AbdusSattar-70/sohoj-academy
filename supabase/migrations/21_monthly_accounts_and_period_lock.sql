insert into public.permissions(code,name,description) values('accounting.period.manage','Close and reopen accounting months','Controlled period close with immutable evidence') on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code in('ADMIN','ACCOUNTANT') and p.code='accounting.period.manage' on conflict do nothing;
create table public.finance_period_events(
 id uuid primary key default gen_random_uuid(),event_order bigint generated always as identity,month date not null check(extract(day from month)=1),
 action text not null check(action in('CLOSE','REOPEN')),snapshot jsonb not null,reason text not null check(length(btrim(reason))>=10),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
create index finance_period_latest on public.finance_period_events(month,event_order desc);
alter table public.finance_period_events enable row level security;
create policy finance_period_read on public.finance_period_events for select to authenticated using(public.has_permission('accounting.view'));
grant select on public.finance_period_events to authenticated;
revoke insert,update,delete on public.finance_period_events from authenticated,anon;
create trigger finance_period_immutable before update or delete on public.finance_period_events for each row execute function public.prevent_permanent_record_delete();

create function public.guard_closed_financial_month() returns trigger language plpgsql security definer set search_path='' as $$
declare day date;month_value date;state text;
begin
 if tg_table_name='general_ledger_journals' then day:=new.journal_date;else select journal_date into day from public.general_ledger_journals where id=new.journal_id;end if;
 month_value:=date_trunc('month',day)::date;
 perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||month_value::text,37));
 select action into state from public.finance_period_events where month=month_value order by event_order desc limit 1;
 if state='CLOSE' then raise exception 'Accounting month % is closed. An authorised reopen with a reason is required.',to_char(month_value,'YYYY-MM');end if;
 return new;
end $$;
revoke all on function public.guard_closed_financial_month() from public,anon,authenticated;
create trigger closed_month_journal_guard before insert on public.general_ledger_journals for each row execute function public.guard_closed_financial_month();
create trigger closed_month_line_guard before insert on public.general_ledger_lines for each row execute function public.guard_closed_financial_month();

create function public.finance_account_ledger_token(p_account uuid,p_date date) returns text language sql stable security definer set search_path='' as $$
 select md5(count(*)::text||':'||coalesce(sum(l.debit),0)::text||':'||coalesce(sum(l.credit),0)::text) from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where l.account_id=p_account and j.status='POSTED' and j.journal_date<=p_date
$$;
revoke all on function public.finance_account_ledger_token(uuid,date) from public,anon,authenticated;

create function public.monthly_financial_report(p_month date default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare first_day date:=coalesce(p_month,date_trunc('month',now() at time zone 'Asia/Dhaka')::date);next_month date;accounts jsonb;cash jsonb;checks jsonb;revenue numeric;reductions numeric;expenses numeric;assets numeric;liabilities numeric;equity numeric;earnings numeric;cash_open numeric;cash_end numeric;snapshot jsonb;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Accounting report permission required.';end if;
 if extract(day from first_day)<>1 or first_day>date_trunc('month',now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose a current or previous accounting month.';end if;
 next_month:=(first_day+interval '1 month')::date;
 with totals as(select a.id,a.code,a.name,a.account_type,a.account_subtype,
 coalesce(sum(l.debit-l.credit) filter(where l.journal_date<first_day),0) opening,
 coalesce(sum(l.debit) filter(where l.journal_date>=first_day),0) debit,
 coalesce(sum(l.credit) filter(where l.journal_date>=first_day),0) credit,
 coalesce(sum(l.debit-l.credit),0) closing
 from public.finance_accounts a left join(select l.*,j.journal_date from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where j.status='POSTED' and j.journal_date<next_month) l on l.account_id=a.id group by a.id,a.code,a.name,a.account_type,a.account_subtype)
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'type',account_type,'subtype',account_subtype,'opening',opening,'debit',debit,'credit',credit,'closing',closing,'endingDebit',greatest(closing,0),'endingCredit',greatest(-closing,0)) order by code),'[]'::jsonb),
 coalesce(sum(credit-debit) filter(where account_type='REVENUE'),0),coalesce(sum(debit-credit) filter(where account_type='CONTRA_REVENUE'),0),coalesce(sum(debit-credit) filter(where account_type='EXPENSE'),0),
 coalesce(sum(closing) filter(where account_type='ASSET'),0),coalesce(sum(-closing) filter(where account_type='LIABILITY'),0),coalesce(sum(-closing) filter(where account_type='EQUITY'),0),
 coalesce(sum(-closing) filter(where account_type in('REVENUE','CONTRA_REVENUE','EXPENSE')),0),
 coalesce(sum(opening) filter(where account_subtype in('CASH','BANK','MOBILE_BANK')),0),coalesce(sum(closing) filter(where account_subtype in('CASH','BANK','MOBILE_BANK')),0)
 into accounts,revenue,reductions,expenses,assets,liabilities,equity,earnings,cash_open,cash_end from totals;
 select coalesce(jsonb_agg(jsonb_build_object('type',journal_type,'source',source_type,'net',amount) order by journal_type,source_type),'[]'::jsonb) into cash from(select j.journal_type,j.source_type,sum(l.debit-l.credit) amount from public.general_ledger_lines l join public.finance_accounts a on a.id=l.account_id join public.general_ledger_journals j on j.id=l.journal_id where a.account_subtype in('CASH','BANK','MOBILE_BANK') and j.status='POSTED' and j.journal_date>=first_day and j.journal_date<next_month group by j.journal_type,j.source_type having sum(l.debit-l.credit)<>0) x;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'matched',exists(select 1 from public.finance_daily_closes c where c.account_id=a.id and c.close_date=next_month-1 and c.variance=0 and c.ledger_token=public.finance_account_ledger_token(a.id,next_month-1))) order by a.code),'[]'::jsonb) into checks from public.finance_accounts a where a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK');
 snapshot:=jsonb_build_object('month',first_day,'through',next_month-1,'accounts',accounts,'revenue',revenue,'reductions',reductions,'expenses',expenses,'profit',revenue-reductions-expenses,'assets',assets,'liabilities',liabilities,'equity',equity,'retainedResult',earnings,'balanceDifference',assets-liabilities-equity-earnings,'cashOpening',cash_open,'cashClosing',cash_end,'cashMovements',cash,'closeChecks',checks,
 'status',coalesce((select action from public.finance_period_events where month=first_day order by event_order desc limit 1),'OPEN'),
 'canClose',next_month<=(now() at time zone 'Asia/Dhaka')::date,'canManage',public.has_permission('accounting.period.manage'),
 'events',(select coalesce(jsonb_agg(jsonb_build_object('action',action,'reason',reason,'date',created_at,'actor',(select display_name from public.profiles where id=actor_id)) order by event_order),'[]'::jsonb) from public.finance_period_events where month=first_day));
 return snapshot||jsonb_build_object('token',md5(snapshot::text),'generatedAt',now());
end $$;
revoke all on function public.monthly_financial_report(date) from public,anon;
grant execute on function public.monthly_financial_report(date) to authenticated;

create function public.finance_period_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;month_value date:=(p_input->>'month')::date;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');state text;key public.admission_command_keys;report jsonb;result jsonb;rid uuid;
begin
 if actor is null or not public.has_permission('accounting.period.manage') or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Accounting period management permission required.';end if;
 if req is null or coalesce(length(reason),0)<10 or month_value is null then raise exception 'Request identity, month and clear explanation are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 perform pg_advisory_xact_lock(hashtextextended('finance-period:'||month_value::text,37));
 report:=public.monthly_financial_report(month_value);
 select e.action into state from public.finance_period_events e where month=month_value order by event_order desc limit 1;
 if action='CLOSE' then
  if state='CLOSE' then raise exception 'This month is already closed.';end if;
  if not (report->>'canClose')::boolean then raise exception 'Close a completed month only.';end if;
  if report->>'token' is distinct from p_input->>'preview_token' then raise exception 'The financial preview changed. Refresh and review before closing.';end if;
  if (report->>'balanceDifference')::numeric<>0 or exists(select 1 from jsonb_array_elements(report->'closeChecks') c where not(c->>'matched')::boolean) then raise exception 'Resolve the balance difference and verify all active cash/bank/mobile month-end counts or statements first.';end if;
  if exists(select 1 from public.general_ledger_journals j left join public.general_ledger_lines l on l.journal_id=j.id where j.status='POSTED' and j.journal_date between month_value and (report->>'through')::date group by j.id having count(l.id)<2 or sum(l.debit)<>sum(l.credit)) then raise exception 'Unbalanced or incomplete journals prevent closing.';end if;
 elsif action='REOPEN' then
  if state is distinct from 'CLOSE' then raise exception 'Only a closed month can be reopened.';end if;
 else raise exception 'Choose close or reopen.';end if;
 insert into public.finance_period_events(month,action,snapshot,reason,actor_id) values(month_value,action,report,reason,actor) returning id into rid;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'ACCOUNTING_PERIOD',month_value::text,action,reason,jsonb_build_object('eventId',rid,'profit',report->'profit'),req);
 result:=jsonb_build_object('id',rid,'ok',true);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.finance_period_command(jsonb) from public,anon;
grant execute on function public.finance_period_command(jsonb) to authenticated;

-- Fixed salary belongs to the earned month; settlement remains on the actual payment date.
create or replace function public.staff_payroll_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  perform public.finance_post_journal(org,(record.month+interval '1 month - 1 day')::date,'COMPENSATION_RUN','STAFF_PAYROLL',record.id::text,'Staff payroll '||(preview->>'number')||' '||(preview->>'month'),actor,jsonb_build_array(jsonb_build_object('account_id',expense_account,'debit',record.net,'credit',0),jsonb_build_object('account_id',salary_account,'debit',0,'credit',record.net)));
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

