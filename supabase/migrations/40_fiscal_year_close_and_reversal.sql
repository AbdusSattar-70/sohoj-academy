create table public.finance_year_events(id uuid primary key default gen_random_uuid(),year_start date not null check(extract(day from year_start)=1),action text not null check(action in('CLOSE','REOPEN')),event_order bigint generated always as identity unique,snapshot jsonb not null,journal_id uuid references public.general_ledger_journals(id),actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create index finance_year_latest on public.finance_year_events(year_start,event_order desc);
alter table public.finance_year_events enable row level security;
revoke all on public.finance_year_events from public,anon,authenticated;
create trigger finance_year_immutable before update or delete on public.finance_year_events for each row execute function public.prevent_permanent_record_delete();
create function public.guard_closed_financial_year() returns trigger language plpgsql security definer set search_path='' as $$
declare day date;state text;
begin
 if tg_table_name='finance_period_events' then day:=new.month;elsif tg_table_name='general_ledger_journals' then day:=new.journal_date;else select journal_date into day from public.general_ledger_journals where id=new.journal_id;end if;
 perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',day)::date::text,37));
 select e.action into state from public.finance_year_events e where day>=e.year_start and day<e.year_start+interval '12 months' order by e.event_order desc limit 1;
 if state='CLOSE' then raise exception 'Financial year is closed. Reopen the year with reversal evidence before changing its months.';end if;return new;
end $$;
revoke all on function public.guard_closed_financial_year() from public,anon,authenticated;
create trigger closed_year_journal before insert on public.general_ledger_journals for each row execute function public.guard_closed_financial_year();
create trigger closed_year_line before insert on public.general_ledger_lines for each row execute function public.guard_closed_financial_year();
create trigger closed_year_month before insert on public.finance_period_events for each row execute function public.guard_closed_financial_year();
create function public.fiscal_year_preview(p_start date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare finish date;last_month date;org uuid;accounts jsonb;months jsonb;dec_report jsonb;state text;snapshot jsonb;profit numeric;pending integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Accounting access required.';end if;
 if p_start is null or extract(day from p_start)<>1 then raise exception 'Choose the first month of a 12-month financial year.';end if;
 finish:=(p_start+interval '12 months')::date;last_month:=(finish-interval '1 month')::date;select id into org from public.organizations where code='SOHOJ' and is_active;
 select action into state from public.finance_year_events where year_start=p_start order by event_order desc limit 1;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.code),'[]'::jsonb),coalesce(-sum(x.balance),0) into accounts,profit from(select a.id,a.code,a.name,a.is_active,coalesce(sum(l.debit-l.credit),0) balance from public.finance_accounts a left join(select l.* from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where j.status='POSTED' and j.journal_date<finish)l on l.account_id=a.id where a.organization_id=org and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE') group by a.id having coalesce(sum(l.debit-l.credit),0)<>0)x;
 select jsonb_agg(jsonb_build_object('month',m::date,'status',coalesce((select action from public.finance_period_events where month=m::date order by event_order desc limit 1),'OPEN')) order by m) into months from generate_series(p_start::timestamp,last_month::timestamp,interval '1 month')m;
 if last_month<=date_trunc('month',now() at time zone 'Asia/Dhaka')::date then dec_report:=public.monthly_financial_report(last_month)-'generatedAt'-'token';end if;
 select count(*) into pending from public.general_ledger_journals j join public.general_ledger_lines l on l.journal_id=j.id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.journal_date<p_start and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE') and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN') and not exists(select 1 from public.finance_year_events e where j.journal_date>=e.year_start and j.journal_date<e.year_start+interval '12 months' and e.action='CLOSE' and e.event_order=(select max(x.event_order) from public.finance_year_events x where x.year_start=e.year_start));
 snapshot:=jsonb_build_object('start',p_start,'through',finish-1,'lastMonth',last_month,'status',coalesce(state,'OPEN'),'accounts',accounts,'months',months,'lastMonthReport',dec_report,'transferResult',profit,'earlierUnclosedLines',pending,'canClose',finish<=(now() at time zone 'Asia/Dhaka')::date,'canManage',public.has_permission('accounting.period.manage'));
 return snapshot||jsonb_build_object('token',md5(snapshot::text),'events',(select coalesce(jsonb_agg(jsonb_build_object('action',e.action,'date',e.created_at,'reason',e.reason,'actor',p.display_name,'journal',coalesce(e.journal_id,(select id from public.general_ledger_journals where source_type='FISCAL_YEAR_REOPEN' and source_id=e.id::text))) order by e.event_order),'[]'::jsonb) from public.finance_year_events e join public.profiles p on p.id=e.actor_id where e.year_start=p_start));
end $$;
revoke all on function public.fiscal_year_preview(date) from public,anon;
grant execute on function public.fiscal_year_preview(date) to authenticated;
create function public.fiscal_year_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');key public.admission_command_keys;start_date date:=(p_input->>'start')::date;finish date;last_month date;mon date;preview jsonb;latest public.finance_year_events;org uuid;retained uuid;rid uuid:=gen_random_uuid();jid uuid;lines jsonb:='[]'::jsonb;item jsonb;balance numeric;result_value numeric:=0;report jsonb;res jsonb;
begin
 if actor is null or not public.has_permission('accounting.period.manage') or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Year-end management permission required.';end if;
 if req is null or start_date is null or extract(day from start_date)<>1 or coalesce(length(why),0) not between 10 and 1000 then raise exception 'Choose start month, request identity and detailed explanation.';end if;
 finish:=(start_date+interval '12 months')::date;last_month:=(finish-interval '1 month')::date;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 -- Same global-before-period order as asset/period commands. All writers share a month lock.
 perform pg_advisory_xact_lock(hashtextextended('asset-financial-register',38));
 for mon in select m::date from generate_series(start_date::timestamp,last_month::timestamp,interval '1 month')m order by m loop perform pg_advisory_xact_lock(hashtextextended('finance-period:'||mon::text,37));end loop;
 if exists(select 1 from public.finance_year_events where year_start<>start_date and year_start<finish and year_start+interval '12 months'>start_date) then raise exception 'Financial year overlaps an existing year definition.';end if;
 preview:=public.fiscal_year_preview(start_date);
 if preview->>'token' is distinct from p_input->>'preview_token' then raise exception 'Year-end evidence changed. Review a fresh preview.';end if;
 select * into latest from public.finance_year_events where year_start=start_date order by event_order desc limit 1;
 select id into org from public.organizations where code='SOHOJ' and is_active;select id into retained from public.finance_accounts where organization_id=org and account_subtype='RETAINED_EARNINGS' and is_active;
 if retained is null then raise exception 'Activate the retained earnings account.';end if;
 if p_input->>'action'='CLOSE' then
  if latest.action='CLOSE' or not (preview->>'canClose')::boolean or (preview->>'earlierUnclosedLines')::int>0 then raise exception 'Close a completed year once; finish earlier unclosed financial years first.';end if;
  if exists(select 1 from jsonb_array_elements(preview->'months')m where (m->>'month')::date<last_month and m->>'status'<>'CLOSE') then raise exception 'Close the first eleven months before year-end.';end if;
  if preview->'lastMonthReport'->>'status'='CLOSE' then raise exception 'Reopen the final month explicitly before year-end posting.';end if;
  if (preview->'lastMonthReport'->>'balanceDifference')::numeric<>0 or exists(select 1 from jsonb_array_elements(preview->'lastMonthReport'->'closeChecks')c where not(c->>'matched')::boolean) then raise exception 'Verify final month cash/statement balances and trial balance first.';end if;
  for item in select value from jsonb_array_elements(preview->'accounts') loop
   if not(item->>'is_active')::boolean then raise exception 'Reactivate nonzero income/expense account % for closing.',item->>'code';end if;
   balance:=(item->>'balance')::numeric;result_value:=result_value-balance;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',item->>'id','debit',greatest(-balance,0),'credit',greatest(balance,0)));
  end loop;
  if result_value<>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',retained,'debit',greatest(-result_value,0),'credit',greatest(result_value,0)));end if;
  if jsonb_array_length(lines)>0 then jid:=public.finance_post_journal(org,finish-1,'MANUAL','FISCAL_YEAR_CLOSE',rid::text,'Year-end retained result transfer',actor,lines);end if;
  report:=public.monthly_financial_report(last_month);perform public.finance_period_command(jsonb_build_object('action','CLOSE','request_id',gen_random_uuid(),'month',last_month,'preview_token',report->>'token','reason',why));
  insert into public.finance_year_events(id,year_start,action,snapshot,journal_id,actor_id,reason) values(rid,start_date,'CLOSE',preview,jid,actor,why);
 elsif p_input->>'action'='REOPEN' then
  if latest.action is distinct from 'CLOSE' then raise exception 'Only a closed year can reopen.';end if;
  if exists(select 1 from public.finance_year_events e where e.year_start>start_date and e.action='CLOSE' and e.event_order=(select max(x.event_order) from public.finance_year_events x where x.year_start=e.year_start)) then raise exception 'Reopen later closed financial years first.';end if;
  -- This event and all reversal work commit atomically; a failure restores the closed state.
  insert into public.finance_year_events(id,year_start,action,snapshot,actor_id,reason) values(rid,start_date,'REOPEN',preview,actor,why);
  perform public.finance_period_command(jsonb_build_object('action','REOPEN','request_id',gen_random_uuid(),'month',last_month,'reason',why));
  if latest.journal_id is not null then
   select jsonb_agg(jsonb_build_object('account_id',account_id,'debit',credit,'credit',debit) order by line_no) into lines from public.general_ledger_lines where journal_id=latest.journal_id;
   jid:=public.finance_post_journal(org,finish-1,'MANUAL','FISCAL_YEAR_REOPEN',rid::text,'Reverse year-end retained result transfer',actor,lines);
  end if;
 else raise exception 'Choose close or reopen financial year.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'FINANCIAL_YEAR',start_date::text,p_input->>'action',why,jsonb_build_object('eventId',rid,'journalId',jid),req);
 res:=jsonb_build_object('id',rid,'message','Year-end action completed atomically with retained-result evidence.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.fiscal_year_command(jsonb) from public,anon;
grant execute on function public.fiscal_year_command(jsonb) to authenticated;

create or replace function public.monthly_financial_report(p_month date default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 select coalesce(sum(l.credit-l.debit) filter(where a.account_type='REVENUE'),0),coalesce(sum(l.debit-l.credit) filter(where a.account_type='CONTRA_REVENUE'),0),coalesce(sum(l.debit-l.credit) filter(where a.account_type='EXPENSE'),0) into revenue,reductions,expenses from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id where j.status='POSTED' and j.journal_date>=first_day and j.journal_date<next_month and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN');
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


create or replace function public.finance_operating_summary() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare revenue numeric; contra numeric; expenses numeric;
begin
 if not public.has_permission('accounting.view') then raise exception 'Accounting view permission required.'; end if;
 select coalesce(sum(case when a.account_type='REVENUE' then l.credit-l.debit else 0 end),0),
 coalesce(sum(case when a.account_type='CONTRA_REVENUE' then l.debit-l.credit else 0 end),0),
 coalesce(sum(case when a.account_type='EXPENSE' then l.debit-l.credit else 0 end),0) into revenue,contra,expenses
 from public.general_ledger_lines l join public.finance_accounts a on a.id=l.account_id join public.general_ledger_journals j on j.id=l.journal_id where j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN');
 return jsonb_build_object('revenue',revenue,'discountsAndReversals',contra,'expenses',expenses,'profitLoss',revenue-contra-expenses,
 'balances',(select coalesce(jsonb_object_agg(a.id::text,public.finance_account_balance(a.id,current_date)),'{}'::jsonb) from public.finance_accounts a where is_active));
end; $$;


create or replace function public.finance_planning_workspace(p_month date default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare mon date:=coalesce(p_month,date_trunc('month',now() at time zone 'Asia/Dhaka')::date);org uuid;centres jsonb;lines jsonb;unassigned numeric;cash numeric;burn numeric;planned_cash numeric;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Accounting permission required.';end if;
 if mon is null or extract(day from mon)<>1 or p_page is null or p_page not between 1 and 10000 then raise exception 'Invalid month or page.';end if;select id into org from public.organizations where code='SOHOJ' and is_active;
 with posted as(select l.id,l.debit-l.credit signed,a.account_type,coalesce(al.allocation,case when l.cost_centre_id is not null then jsonb_build_array(jsonb_build_object('centre_id',l.cost_centre_id,'amount',abs(l.debit-l.credit))) else '[]'::jsonb end) allocation from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id left join lateral(select allocation from public.finance_line_allocations where line_id=l.id order by event_order desc limit 1)al on true where j.organization_id=org and j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN') and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE')),
 allocated as(select (v->>'centre_id')::uuid centre_id,sum(case when p.account_type in('REVENUE','CONTRA_REVENUE') then -(v->>'amount')::numeric*sign(p.signed) else 0 end) revenue,sum(case when p.account_type='EXPENSE' then (v->>'amount')::numeric*sign(p.signed) else 0 end) expense from posted p cross join lateral jsonb_array_elements(coalesce(p.allocation,'[]'::jsonb))v group by v->>'centre_id')
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'offering_id',c.offering_id,'revision',c.revision,'is_active',c.is_active,'revenue',coalesce(a.revenue,0),'expense',coalesce(a.expense,0),'profit',coalesce(a.revenue,0)-coalesce(a.expense,0),'budget',to_jsonb(b)) order by c.name),'[]'::jsonb) into centres from (select * from public.finance_cost_centres where organization_id=org order by name,id limit 25 offset (p_page-1)*25)c left join allocated a on a.centre_id=c.id left join public.finance_budgets b on b.centre_id=c.id and b.month=mon where c.organization_id=org;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into lines from(select l.id,j.journal_date,j.description,j.source_type,a.name account,a.account_type,l.debit-l.credit signed,coalesce(al.event_order,0) expected_order,coalesce(al.allocation,case when l.cost_centre_id is not null then jsonb_build_array(jsonb_build_object('centre_id',l.cost_centre_id,'amount',abs(l.debit-l.credit))) else '[]'::jsonb end) allocations from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id left join lateral(select event_order,allocation from public.finance_line_allocations where line_id=l.id order by event_order desc limit 1)al on true where j.organization_id=org and j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN') and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE') order by j.journal_date desc,l.id limit 25 offset (p_page-1)*25)x;
 select coalesce(sum(abs(l.debit-l.credit)-coalesce((select sum((v->>'amount')::numeric) from public.finance_line_allocations al cross join lateral jsonb_array_elements(al.allocation)v where al.id=(select id from public.finance_line_allocations where line_id=l.id order by event_order desc limit 1)),case when l.cost_centre_id is not null and not exists(select 1 from public.finance_line_allocations where line_id=l.id) then abs(l.debit-l.credit) else 0 end)),0) into unassigned from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN') and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE');
 select coalesce(sum(public.finance_account_balance(a.id,(now() at time zone 'Asia/Dhaka')::date)),0) into cash from public.finance_accounts a where a.organization_id=org and a.account_subtype in('CASH','BANK','MOBILE_BANK');
 select coalesce(sum(b.cash_out-b.cash_in),0),coalesce(sum(b.cash_in-b.cash_out),0) into burn,planned_cash from public.finance_budgets b join public.finance_cost_centres c on c.id=b.centre_id where c.organization_id=org and b.month=mon;
 return jsonb_build_object('month',mon,'canManage',public.has_permission('accounting.period.manage'),'centres',centres,'lines',lines,'unallocated',unassigned,'cashAvailableToday',cash,'plannedCashMovement',planned_cash,'runwayMonths',case when burn>0 then round(cash/burn,2) else null end,
 'centreChoices',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'is_active',x.is_active)),'[]'::jsonb) from(select id,name,is_active from public.finance_cost_centres where organization_id=org order by is_active desc,name,id limit 200)x),
 'total',greatest((select count(*) from public.finance_cost_centres where organization_id=org),(select count(*) from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN') and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_type in('REVENUE','CONTRA_REVENUE','EXPENSE'))),
 'offerings',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name||' · '||x.code)),'[]'::jsonb) from(select id,name,code from public.programme_offerings where organization_id=org order by code limit 200)x));
end $$;
revoke all on function public.finance_planning_workspace(date,integer) from public,anon;
grant execute on function public.finance_planning_workspace(date,integer) to authenticated;
