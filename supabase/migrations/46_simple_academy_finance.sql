-- Operator-facing finance: reuse the protected posting engine without exposing accounting setup.
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'4310','Other Academy Income','REVENUE','OTHER_ACADEMY_INCOME',true from public.organizations where code='SOHOJ' on conflict(organization_id,code) do nothing;
insert into public.finance_expense_categories(organization_id,code,name,expense_account_id,is_active)
select o.id,v.code,v.name,a.id,true from public.organizations o join public.finance_accounts a on a.organization_id=o.id and a.account_subtype='OPERATING_EXPENSE'
cross join(values('SIMPLE_MATERIALS','Learning materials'),('SIMPLE_REFRESHMENTS','Refreshments'),('SIMPLE_OTHER','Other running cost'))v(code,name)
where o.code='SOHOJ' and not exists(select 1 from public.finance_expense_categories c where c.organization_id=o.id and lower(btrim(c.name))=lower(v.name)) on conflict(organization_id,code) do nothing;
create table public.academy_money_entries(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations,
 kind text not null check(kind in('OTHER_INCOME','OWNER_FUNDS')),entry_date date not null,
 amount numeric(14,2) not null check(amount>0 and amount<>'NaN'::numeric),account_id uuid not null references public.finance_accounts,
 description text not null check(length(btrim(description)) between 3 and 300),reference text,
 journal_id uuid not null references public.general_ledger_journals,created_by uuid not null references public.profiles,created_at timestamptz not null default now()
);
create unique index academy_money_reference on public.academy_money_entries(organization_id,reference) where reference is not null;
alter table public.academy_money_entries enable row level security;
revoke all on public.academy_money_entries from public,anon,authenticated;
create trigger academy_money_immutable before update or delete on public.academy_money_entries for each row execute function public.prevent_permanent_record_delete();
-- This private projection omits investment/disposal/depreciation and closing transfers.
create view public.academy_operating_lines with(security_barrier=true) as
select j.organization_id,j.journal_date,j.journal_type,j.source_type,j.source_id,j.description,l.account_id,a.account_type,a.account_subtype,l.debit,l.credit
from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id join public.finance_accounts a on a.id=l.account_id
where j.status='POSTED' and j.source_type not in('FISCAL_YEAR_CLOSE','FISCAL_YEAR_REOPEN')
 and j.source_type not like 'ASSET%' and a.account_subtype not in('DEPRECIATION','ASSET_DISPOSAL_GAIN','ASSET_DISPOSAL_LOSS')
 and (j.journal_type<>'MANUAL' or j.source_type='SIMPLE_OPERATING_INCOME')
 and not exists(select 1 from public.academy_assets ast where ast.source_purchase_id::text=j.source_id and ast.status not in('DRAFT','CANCELLED'))
 and not (j.source_type='PAYABLE_SETTLEMENT' and exists(select 1 from public.admission_command_keys k join public.finance_payables p on p.id::text=k.payload->>'payable_id' where k.request_id::text=j.source_id and p.source_type='ASSET'));
revoke all on public.academy_operating_lines from public,anon,authenticated;
create function public.simple_finance_workspace(p_month date default null,p_page integer default 1,p_query text default '') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare org uuid;mon date:=coalesce(p_month,date_trunc('month',now() at time zone 'Asia/Dhaka')::date);revenue numeric;reductions numeric;expenses numeric;collected numeric;paid numeric;current_due numeric;current_cost_due numeric;balances jsonb;categories jsonb;records jsonb;total int;breakdown jsonb;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Finance viewing permission required.';end if;
 if mon is null or extract(day from mon)<>1 or mon>date_trunc('month',now() at time zone 'Asia/Dhaka')::date or p_page is null or p_page not between 1 and 10000 or p_query is null or length(p_query)>160 then raise exception 'Choose a current/past month and a valid search page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select coalesce(sum(credit-debit) filter(where account_type='REVENUE'),0),coalesce(sum(debit-credit) filter(where account_type='CONTRA_REVENUE'),0),coalesce(sum(debit-credit) filter(where account_type='EXPENSE'),0),
 coalesce(sum(debit-credit) filter(where account_subtype in('CASH','BANK','MOBILE_BANK') and source_type in('ADMISSION_PAYMENT','REFUND_PAYOUT','SIMPLE_OPERATING_INCOME')),0),
 coalesce(sum(credit-debit) filter(where account_subtype in('CASH','BANK','MOBILE_BANK') and source_type not in('ADMISSION_PAYMENT','REFUND_PAYOUT','SIMPLE_OPERATING_INCOME')),0)
 into revenue,reductions,expenses,collected,paid from public.academy_operating_lines where organization_id=org and journal_date>=mon and journal_date<mon+interval '1 month';
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into breakdown from(select account_subtype kind,sum(debit-credit) amount from public.academy_operating_lines where organization_id=org and account_type='EXPENSE' and journal_date>=mon and journal_date<mon+interval '1 month' group by account_subtype order by account_subtype)x;
 select coalesce(sum(b.due),0) into current_due from public.admission_invoices i join public.admission_cases ac on ac.id=i.admission_id join public.batches ba on ba.id=ac.batch_id cross join lateral public.invoice_balance(i.id)b where ba.organization_id=org;
 select coalesce(sum(greatest(p.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=p.id),0),0)),0) into current_cost_due from public.finance_payables p where p.organization_id=org and p.status<>'VOIDED' and p.source_type in('EXPENSE','PURCHASE','STAFF_PAYROLL','COMPENSATION_RUN','REFERRAL_ACCRUAL') and not exists(select 1 from public.academy_assets ast where ast.source_purchase_id::text=p.source_id and ast.status not in('DRAFT','CANCELLED')); 
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'balance',coalesce(public.finance_account_balance(a.id,(now() at time zone 'Asia/Dhaka')::date),0)) order by a.code),'[]') into balances from public.finance_accounts a where a.organization_id=org and a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK') and not exists(select 1 from public.finance_cash_counters c where c.account_id=a.id);
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name) order by c.name),'[]') into categories from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.organization_id=org and c.is_active and a.account_subtype='OPERATING_EXPENSE';
 with entries as(
 select e.id,e.expense_date "day",'EXPENSE'::text kind,e.description,e.amount,e.payable_id,
 case when e.payable_id is null then 0 else greatest(e.amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=e.payable_id),0),0) end remaining,c.name category
 from public.finance_expenses e join public.finance_expense_categories c on c.id=e.category_id where e.organization_id=org and e.status in('POSTED','RECONCILED')
 union all select m.id,m.entry_date,m.kind,m.description,m.amount,null::uuid,0,null::text from public.academy_money_entries m where m.organization_id=org),
 matched as(select * from entries where "day">=mon and "day"<mon+interval '1 month' and(p_query='' or description ilike '%'||p_query||'%' or category ilike '%'||p_query||'%')),
 paged as(select * from matched order by "day" desc,id limit 25 offset(p_page-1)*25)
 select (select count(*) from matched),coalesce((select jsonb_agg(to_jsonb(paged) order by "day" desc,id) from paged),'[]') into total,records;
 return jsonb_build_object('month',mon,'revenue',revenue,'reductions',reductions,'netIncome',revenue-reductions,'expenses',expenses,'profit',revenue-reductions-expenses,'collected',collected,'paid',paid,'cashResult',collected-paid,'studentDue',current_due,'costDue',current_cost_due,'accounts',balances,'categories',categories,'expenseBreakdown',breakdown,'rows',records,'total',total,'page',p_page,'canExpense',public.has_permission('accounting.expense.manage'),'canPay',public.has_permission('finance.payments.post'),'canIncome',public.has_permission('accounting.expense.manage'));
end $$;
create function public.simple_finance_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;cmd text:=p_input->>'action';why text:=btrim(p_input->>'reason');org uuid;key public.admission_command_keys;normalized jsonb;result jsonb;account uuid;target uuid;amount_value numeric;day_value date;description_value text;cat public.finance_expense_categories;expense public.finance_expenses;payable public.finance_payables;reference_value text;entry_id uuid:=gen_random_uuid();journal uuid;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Sign in with an active academy account.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and a short reason are required.';end if;
 if cmd not in('EXPENSE','PAY_COST','OTHER_INCOME','OWNER_FUNDS','CATEGORY') then raise exception 'Choose a supported academy money action.';end if;
 if cmd='PAY_COST' then if not public.has_permission('finance.payments.post') then raise exception 'Expense payment permission required.';end if;
 elsif not public.has_permission('accounting.expense.manage') then raise exception 'Income/expense management permission required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform set_config('TimeZone','Asia/Dhaka',true);
 perform pg_advisory_xact_lock(hashtextextended(req::text,7));
 if cmd='EXPENSE' then
  description_value:=coalesce(nullif(btrim(p_input->>'description'),''),(select name from public.finance_expense_categories where id=(p_input->>'category_id')::uuid and organization_id=org));
  normalized:=jsonb_build_object('request_id',req,'action','CREATE_EXPENSE_DIRECT','expense_date',p_input->>'date','category_id',p_input->>'category_id','description',description_value,'amount',p_input->>'amount','payment_mode',p_input->>'payment_mode','payment_account_id',p_input->>'account_id','receipt_reference',p_input->>'reference','reason',why);
 elsif cmd='PAY_COST' then
  normalized:=jsonb_build_object('request_id',req,'action','SETTLE_PAYABLE','payable_id',p_input->>'payable_id','amount',p_input->>'amount','payment_account_id',p_input->>'account_id','external_reference',p_input->>'reference','reason',why);
 else normalized:=p_input;end if;
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>normalized then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 if cmd='CATEGORY' then
  description_value:=btrim(p_input->>'description');if coalesce(length(description_value),0) not between 2 and 120 then raise exception 'Enter a short category name.';end if;
  perform pg_advisory_xact_lock(hashtextextended(org::text||'simple-category:'||lower(description_value),0));
  select * into cat from public.finance_expense_categories where organization_id=org and lower(btrim(name))=lower(description_value) order by id limit 1;
  if cat.id is not null and not cat.is_active then raise exception 'This category is inactive; choose an active category.';end if;
  if cat.id is null then
   select id into target from public.finance_accounts where organization_id=org and is_active and account_subtype='OPERATING_EXPENSE';
   insert into public.finance_expense_categories(organization_id,code,name,expense_account_id,created_by) values(org,'SIMPLE_'||upper(replace(entry_id::text,'-','')),description_value,target,actor) returning * into cat;
  end if;
  result:=jsonb_build_object('id',cat.id,'message','Expense category ready.');
 else
  amount_value:=(p_input->>'amount')::numeric;day_value:=nullif(p_input->>'date','')::date;
  if amount_value is null or amount_value<=0 or amount_value='NaN'::numeric or amount_value<>round(amount_value,2) or amount_value>999999999999.99 then raise exception 'Enter a positive BDT amount with at most two decimal places.';end if;
  if cmd<>'PAY_COST' and(day_value is null or day_value>(now() at time zone 'Asia/Dhaka')::date) then raise exception 'Choose the actual income/expense date, not a future date.';end if;
  perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',case when cmd='PAY_COST' then (now() at time zone 'Asia/Dhaka')::date else day_value end)::date::text,37));
  if cmd='PAY_COST' or cmd in('OTHER_INCOME','OWNER_FUNDS') or p_input->>'payment_mode'='PAID_NOW' then
   select id into account from public.finance_accounts where id=(p_input->>'account_id')::uuid and organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK') and not exists(select 1 from public.finance_cash_counters c where c.account_id=finance_accounts.id);
   if account is null then raise exception 'Choose an active cash, bank or mobile money source.';end if;
  end if;
  if cmd='EXPENSE' then
   if not exists(select 1 from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.id=(p_input->>'category_id')::uuid and c.organization_id=org and c.is_active and a.account_subtype='OPERATING_EXPENSE') then raise exception 'Choose an active running-expense category.';end if;
   select expense_account_id into target from public.finance_expense_categories where id=(p_input->>'category_id')::uuid;
   perform 1 from public.finance_accounts where id in(account,target) order by id for update;
   if p_input->>'payment_mode'='PAID_NOW' and amount_value>coalesce(public.finance_account_balance(account,day_value),0) then raise exception 'Not enough recorded money. Record actual opening/owner funds or collections first, or choose pay later.';end if;
   return public.finance_accounting_command(normalized);
  elsif cmd='PAY_COST' then
   select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid and organization_id=org and source_type='EXPENSE' for update;
   if not found then raise exception 'Choose an unpaid running-expense record.';end if;
   perform 1 from public.finance_accounts where id in(account,payable.payable_account_id) order by id for update;
   if amount_value>coalesce(public.finance_account_balance(account,(now() at time zone 'Asia/Dhaka')::date),0) then raise exception 'Not enough recorded funds for this payment.';end if;
   return public.finance_accounting_command(normalized);
  else
   description_value:=btrim(p_input->>'description');if coalesce(length(description_value),0) not between 3 and 300 then raise exception 'Enter a short income/funding description.';end if;
   reference_value:=nullif(btrim(p_input->>'reference'),'');
   select id into target from public.finance_accounts where organization_id=org and is_active and account_subtype=case when cmd='OWNER_FUNDS' then 'OWNER_CAPITAL' else 'OTHER_ACADEMY_INCOME' end;
   if target is null then raise exception 'The academy money setup is incomplete.';end if;
   perform 1 from public.finance_accounts where id in(account,target) order by id for update;
   journal:=public.finance_post_journal(org,day_value,'MANUAL',case when cmd='OWNER_FUNDS' then 'SIMPLE_OWNER_FUNDS' else 'SIMPLE_OPERATING_INCOME' end,entry_id::text,description_value,actor,jsonb_build_array(jsonb_build_object('account_id',account,'debit',amount_value,'credit',0),jsonb_build_object('account_id',target,'debit',0,'credit',amount_value)));
   insert into public.academy_money_entries(id,organization_id,kind,entry_date,amount,account_id,description,reference,journal_id,created_by) values(entry_id,org,cmd,day_value,amount_value,account,description_value,reference_value,journal,actor);
   result:=jsonb_build_object('id',entry_id,'message','Academy money entry saved.');
  end if;
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'ACADEMY_MONEY',result->>'id',cmd,why,result,req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,normalized,result);return result;
end $$;
revoke all on function public.simple_finance_workspace(date,integer,text),public.simple_finance_command(jsonb) from public,anon;
grant execute on function public.simple_finance_workspace(date,integer,text),public.simple_finance_command(jsonb) to authenticated;
notify pgrst,'reload schema';
create function public.simple_teaching_workspace(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;begin
 if auth.uid() is null or not public.has_permission('staff.compensation.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Teaching earnings management permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 return jsonb_build_object('page',p_page,'total',(select count(*) from public.teacher_compensation_runs where organization_id=org),'accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name) order by a.code),'[]') from public.finance_accounts a where a.organization_id=org and a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK') and not exists(select 1 from public.finance_cash_counters c where c.account_id=a.id)),
 'rows',(select coalesce(jsonb_agg(to_jsonb(x) order by period_end desc,id),'[]') from(select r.id,r.run_no,r.period_start,r.period_end,r.status,r.total_amount,
 (select coalesce(jsonb_agg(jsonb_build_object('teacherId',s.id,'teacher',s.full_name,'earned',p.original_amount,'remaining',greatest(p.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=p.id),0),0)) order by s.full_name),'[]') from public.finance_payables p join public.staff s on s.id=p.staff_id where p.organization_id=org and p.source_type='COMPENSATION_RUN' and p.source_id like r.id::text||':%' and p.status<>'VOIDED') people
 from public.teacher_compensation_runs r where r.organization_id=org order by r.period_end desc,r.id limit 25 offset(p_page-1)*25)x));
end $$;
revoke all on function public.simple_teaching_workspace(integer) from public,anon;
grant execute on function public.simple_teaching_workspace(integer) to authenticated;
