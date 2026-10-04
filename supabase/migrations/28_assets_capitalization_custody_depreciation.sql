insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code in('ADMIN','ACCOUNTANT') and p.code in('assets.manage','assets.view') on conflict do nothing;
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select o.id,v.code,v.name,v.type,v.subtype,true from public.organizations o cross join(values('1510','Furniture and Equipment','ASSET','FIXED_ASSET'),('1590','Accumulated Depreciation','ASSET','ACCUMULATED_DEPRECIATION'),('5400','Asset Depreciation','EXPENSE','DEPRECIATION'),('4300','Asset Disposal Gains','REVENUE','ASSET_DISPOSAL_GAIN'),('5500','Asset Disposal Losses','EXPENSE','ASSET_DISPOSAL_LOSS'))v(code,name,type,subtype) where o.code='SOHOJ' on conflict(organization_id,code) do nothing;
alter table public.general_ledger_journals drop constraint general_ledger_journals_journal_type_check;
alter table public.general_ledger_journals add constraint general_ledger_journals_journal_type_check check(journal_type in('INVOICE','INVOICE_CREDIT','PAYMENT','REFUND','ADVANCE_PAYMENT','ADVANCE_SETTLEMENT','ADVANCE_REFUND','EXPENSE','PAYABLE_SETTLEMENT','COMPENSATION_RUN','COMPENSATION_SETTLEMENT','MANUAL','PURCHASE_ADJUSTMENT','SUPPLIER_REFUND','ASSET_ACQUISITION','ASSET_DEPRECIATION','ASSET_DISPOSAL'));
create sequence public.asset_no_seq;
create table public.academy_assets(
 id uuid primary key default gen_random_uuid(),asset_no text not null unique default ('AST-'||lpad(nextval('public.asset_no_seq')::text,6,'0')),organization_id uuid not null references public.organizations(id),name text not null,serial_no text,location text not null,
 vendor_id uuid not null references public.vendors(id),source_purchase_id uuid references public.finance_purchases(id),asset_account_id uuid not null references public.finance_accounts(id),cost numeric(14,2) not null check(cost>0),residual numeric(14,2) not null check(residual>=0 and residual<cost),life_months integer not null check(life_months between 1 and 600),
 acquired_on date not null,in_service_on date not null,depreciation_start date not null check(extract(day from depreciation_start)=1),invoice_reference text not null,
 status text not null default 'DRAFT' check(status in('DRAFT','ACTIVE','INACTIVE','DISPOSED','CANCELLED')),custodian_id uuid references public.staff(id),payable_id uuid references public.finance_payables(id),acquisition_journal_id uuid references public.general_ledger_journals(id),revision integer not null default 1,
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(in_service_on>=acquired_on),check(depreciation_start>=date_trunc('month',in_service_on)::date)
);
create unique index asset_purchase_once on public.academy_assets(source_purchase_id) where source_purchase_id is not null and status<>'CANCELLED';
create unique index asset_supplier_invoice on public.academy_assets(organization_id,vendor_id,lower(btrim(invoice_reference))) where status not in('DRAFT','CANCELLED');
create table public.asset_depreciation_entries(id uuid primary key default gen_random_uuid(),asset_id uuid not null references public.academy_assets(id),month date not null check(extract(day from month)=1),amount numeric(14,2) not null check(amount>=0),journal_id uuid references public.general_ledger_journals(id),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),unique(asset_id,month));
create table public.asset_events(id uuid primary key default gen_random_uuid(),event_order bigint generated always as identity,asset_id uuid not null references public.academy_assets(id),action text not null,actor_id uuid not null references public.profiles(id),reason text not null,payload jsonb not null,created_at timestamptz not null default now());
create table public.asset_disposals(id uuid primary key default gen_random_uuid(),asset_id uuid not null unique references public.academy_assets(id),disposed_on date not null,proceeds numeric(14,2) not null check(proceeds>=0),book_value numeric(14,2) not null check(book_value>=0),journal_id uuid not null references public.general_ledger_journals(id),reference text not null,actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create function public.asset_access(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') and exists(select 1 from public.academy_assets a join public.organizations o on o.id=a.organization_id where a.id=p_id and o.code='SOHOJ' and o.is_active and (public.has_permission('assets.manage') or (public.has_permission('workforce.self.view') and a.status in('ACTIVE','INACTIVE') and a.custodian_id in(select id from public.staff where profile_id=auth.uid() and status in('ACTIVE','ON_LEAVE')))))
$$;
revoke all on function public.asset_access(uuid) from public,anon;grant execute on function public.asset_access(uuid) to authenticated;
alter table public.academy_assets enable row level security;alter table public.asset_depreciation_entries enable row level security;alter table public.asset_events enable row level security;alter table public.asset_disposals enable row level security;
create policy asset_read on public.academy_assets for select to authenticated using(public.asset_access(id));
create policy asset_depreciation_read on public.asset_depreciation_entries for select to authenticated using(public.asset_access(asset_id));
create policy asset_event_read on public.asset_events for select to authenticated using(public.asset_access(asset_id));
create policy asset_disposal_read on public.asset_disposals for select to authenticated using(public.asset_access(asset_id));
grant select on public.academy_assets,public.asset_depreciation_entries,public.asset_events,public.asset_disposals to authenticated;revoke insert,update,delete on public.academy_assets,public.asset_depreciation_entries,public.asset_events,public.asset_disposals from anon,authenticated;
create function public.guard_asset_history() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='DELETE' or old.status in('DISPOSED','CANCELLED') then raise exception 'Asset history cannot be deleted or finalized records changed.';end if;
 if old.status<>'DRAFT' and (to_jsonb(new)-'name'-'serial_no'-'location'-'custodian_id'-'status'-'revision'-'updated_at') is distinct from (to_jsonb(old)-'name'-'serial_no'-'location'-'custodian_id'-'status'-'revision'-'updated_at') then raise exception 'Posted asset financial terms are immutable.';end if;return new;end $$;
create trigger asset_history before update or delete on public.academy_assets for each row execute function public.guard_asset_history();
create trigger asset_depreciation_history before update or delete on public.asset_depreciation_entries for each row execute function public.prevent_permanent_record_delete();
create trigger asset_event_history before update or delete on public.asset_events for each row execute function public.prevent_permanent_record_delete();
create trigger asset_disposal_history before update or delete on public.asset_disposals for each row execute function public.prevent_permanent_record_delete();

create function public.asset_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;manager boolean:=public.has_permission('assets.manage');org uuid;a public.academy_assets;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');source public.finance_purchases;e public.finance_expenses;vendor uuid;account uuid;cost_value numeric;residual_value numeric;life integer;acquired date;service_date date;start_month date;month_value date;next_month date;due_month date;depreciated numeric;amount_value numeric;accumulated uuid;expense_account uuid;gain_account uuid;loss_account uuid;payable_account uuid;payable uuid;journal uuid;event_id uuid;sid uuid;lines jsonb:='[]'::jsonb;record_id uuid:=gen_random_uuid();proceeds_value numeric;book_value numeric;date_value date;result jsonb;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or (not manager and (action<>'ACKNOWLEDGE' or not public.has_permission('workforce.self.view'))) then raise exception 'Asset management access required.';end if;
 if req is null or coalesce(length(reason),0)<5 then raise exception 'Request identity and reason required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 perform pg_advisory_xact_lock_shared(hashtextextended('asset-financial-register',38));
 if nullif(p_input->>'id','') is not null then
  select * into a from public.academy_assets where id=(p_input->>'id')::uuid and organization_id=org for update;if a.id is null or not public.asset_access(a.id) then raise exception 'Asset unavailable.';end if;
  if action<>'ACKNOWLEDGE' and a.revision is distinct from (p_input->>'revision')::integer then raise exception 'Asset changed. Refresh before continuing.';end if;
 elsif action<>'SAVE' then raise exception 'Choose an asset.';end if;
 if action='SAVE' then
  if a.id is not null and a.status<>'DRAFT' then raise exception 'Only draft financial terms can be edited.';end if;
  if coalesce(length(btrim(p_input->>'name')),0)<2 or coalesce(length(btrim(p_input->>'location')),0)<2 or coalesce(length(btrim(p_input->>'invoice_reference')),0)<3 then raise exception 'Enter asset name, location and invoice reference.';end if;
  vendor:=(p_input->>'vendor_id')::uuid;cost_value:=(p_input->>'cost')::numeric;residual_value:=coalesce((p_input->>'residual')::numeric,0);life:=(p_input->>'life_months')::integer;acquired:=(p_input->>'acquired_on')::date;service_date:=(p_input->>'in_service_on')::date;start_month:=(p_input->>'depreciation_start')::date;
  if nullif(p_input->>'source_purchase_id','') is not null then
   select * into source from public.finance_purchases where id=(p_input->>'source_purchase_id')::uuid and organization_id=org for update;
   if source.status is distinct from 'POSTED' or exists(select 1 from public.purchase_adjustments where purchase_id=source.id) then raise exception 'Select a posted, unadjusted purchase for capitalization.';end if;vendor:=source.vendor_id;cost_value:=source.total;acquired:=source.received_on;
  end if;
  if cost_value is null or cost_value<=0 or cost_value<>round(cost_value,2) or residual_value<0 or residual_value>=cost_value or residual_value<>round(residual_value,2) or life is null or life not between 1 and 600 or acquired is null or service_date is null or acquired>(now() at time zone 'Asia/Dhaka')::date or service_date<acquired or start_month is null or extract(day from start_month)<>1 or start_month<date_trunc('month',service_date)::date then raise exception 'Check cost, residual, useful life, acquisition/service dates and first depreciation month.';end if;
  if not exists(select 1 from public.vendors where id=vendor and organization_id=org and is_active) then raise exception 'Choose an active supplier.';end if;
  select id into account from public.finance_accounts where id=(p_input->>'asset_account_id')::uuid and organization_id=org and is_active and account_type='ASSET' and account_subtype='FIXED_ASSET';if account is null then raise exception 'Choose an active fixed-asset account.';end if;
  if a.id is null then insert into public.academy_assets(organization_id,name,serial_no,location,vendor_id,source_purchase_id,asset_account_id,cost,residual,life_months,acquired_on,in_service_on,depreciation_start,invoice_reference,created_by) values(org,btrim(p_input->>'name'),nullif(btrim(p_input->>'serial_no'),''),btrim(p_input->>'location'),vendor,source.id,account,cost_value,residual_value,life,acquired,service_date,start_month,btrim(p_input->>'invoice_reference'),actor) returning * into a;
  else update public.academy_assets set name=btrim(p_input->>'name'),serial_no=nullif(btrim(p_input->>'serial_no'),''),location=btrim(p_input->>'location'),vendor_id=vendor,source_purchase_id=source.id,asset_account_id=account,cost=cost_value,residual=residual_value,life_months=life,acquired_on=acquired,in_service_on=service_date,depreciation_start=start_month,invoice_reference=btrim(p_input->>'invoice_reference'),revision=revision+1,updated_at=now() where id=a.id returning * into a;end if;
 elsif action='ACQUIRE' then
  if a.status<>'DRAFT' or p_input->>'confirmed' is distinct from 'true' then raise exception 'Verify the asset and invoice before capitalization.';end if;
  date_value:=(p_input->>'date')::date;if date_value is null or date_value<a.acquired_on or date_value>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose a valid capitalization date.';end if;
  if date_value>(a.depreciation_start+interval '1 month - 1 day')::date then raise exception 'Capitalization date must precede the end of the first depreciation month. Review draft dates.';end if;
  if exists(select 1 from public.finance_period_events x where x.month>=a.depreciation_start and x.month<(a.depreciation_start+make_interval(months=>a.life_months))::date and x.action='CLOSE' and x.event_order=(select max(event_order) from public.finance_period_events where month=x.month)) then raise exception 'Scheduled depreciation includes a closed month. Reopen it or review draft schedule before capitalization.';end if;
  if not exists(select 1 from public.finance_accounts where id=a.asset_account_id and is_active) then raise exception 'Asset ledger account is inactive.';end if;
  if a.source_purchase_id is not null then
   select * into source from public.finance_purchases where id=a.source_purchase_id for update;
   if source.status<>'POSTED' or source.total<>a.cost or exists(select 1 from public.purchase_adjustments where purchase_id=source.id) then raise exception 'Source purchase changed. Review the draft.';end if;
   select * into e from public.finance_expenses where id=source.expense_id;payable:=e.payable_id;account:=e.expense_account_id;
  elsif p_input->>'payment_mode'='ON_ACCOUNT' then
   select id into payable_account from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' and is_active;
   insert into public.finance_payables(organization_id,payable_type,vendor_id,source_type,source_id,payable_account_id,original_amount,due_on,created_by) values(org,'VENDOR',a.vendor_id,'ASSET',a.id::text,payable_account,a.cost,a.acquired_on+30,actor) returning id into payable;account:=payable_account;
  elsif p_input->>'payment_mode'='PAID_NOW' then
   if not public.has_permission('finance.payments.post') then raise exception 'Actual payment access required.';end if;
   select id into account from public.finance_accounts where id=(p_input->>'payment_account_id')::uuid and organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose an active paying account.';end if;
  else raise exception 'Choose paid now or supplier payable.';end if;
  journal:=public.finance_post_journal(org,date_value,'ASSET_ACQUISITION','ASSET_ACQUISITION',a.id::text,a.asset_no||' · '||a.invoice_reference,actor,jsonb_build_array(jsonb_build_object('account_id',a.asset_account_id,'debit',a.cost,'credit',0),jsonb_build_object('account_id',account,'debit',0,'credit',a.cost)));
  update public.academy_assets set status='ACTIVE',acquisition_journal_id=journal,payable_id=payable,revision=revision+1,updated_at=now() where id=a.id returning * into a;
 elsif action in('DETAILS','TRANSFER','MARK_INACTIVE','ACTIVATE','CANCEL') then
  if action='CANCEL' then if a.status<>'DRAFT' then raise exception 'Only unused drafts can be cancelled.';end if;update public.academy_assets set status='CANCELLED',revision=revision+1,updated_at=now() where id=a.id returning * into a;
  elsif action='MARK_INACTIVE' then if a.status<>'ACTIVE' then raise exception 'Only active assets may be marked inactive.';end if;update public.academy_assets set status='INACTIVE',revision=revision+1,updated_at=now() where id=a.id returning * into a;
  elsif action='ACTIVATE' then if a.status<>'INACTIVE' then raise exception 'Only inactive assets may be reactivated.';end if;update public.academy_assets set status='ACTIVE',revision=revision+1,updated_at=now() where id=a.id returning * into a;
  elsif action='TRANSFER' then
   if a.status<>'ACTIVE' or coalesce(length(btrim(p_input->>'location')),0)<2 then raise exception 'Choose an active asset and its location.';end if;sid:=nullif(p_input->>'custodian_id','')::uuid;
   if sid is not null and not exists(select 1 from public.staff s left join public.branches b on b.id=s.branch_id where s.id=sid and s.status in('ACTIVE','ON_LEAVE') and (s.branch_id is null or b.organization_id=org)) then raise exception 'Choose active academy staff or unassigned custody.';end if;
   update public.academy_assets set custodian_id=sid,location=btrim(p_input->>'location'),revision=revision+1,updated_at=now() where id=a.id returning * into a;
  else
   if a.status not in('ACTIVE','INACTIVE') or coalesce(length(btrim(p_input->>'name')),0)<2 then raise exception 'Edit details of an active or inactive asset.';end if;update public.academy_assets set name=btrim(p_input->>'name'),serial_no=nullif(btrim(p_input->>'serial_no'),''),revision=revision+1,updated_at=now() where id=a.id returning * into a;
  end if;
 elsif action='ACKNOWLEDGE' then
  if a.custodian_id is null or not exists(select 1 from public.staff where id=a.custodian_id and profile_id=actor and status in('ACTIVE','ON_LEAVE')) then raise exception 'Only the assigned custodian may acknowledge receipt.';end if;
  select ev.id into event_id from public.asset_events ev where ev.asset_id=a.id and ev.action='TRANSFER' order by event_order desc limit 1;if event_id is distinct from (p_input->>'transfer_id')::uuid then raise exception 'Assignment changed. Review the current custody.';end if;
  if exists(select 1 from public.asset_events ev where ev.asset_id=a.id and ev.action='ACKNOWLEDGE' and ev.payload->>'transfer_id'=event_id::text) then raise exception 'Custody already acknowledged.';end if;
 elsif action='DEPRECIATE' then
  if a.status not in('ACTIVE','INACTIVE') then raise exception 'Depreciate acquired assets only.';end if;
  month_value:=(p_input->>'month')::date;select coalesce(sum(amount),0),coalesce((max(month)+interval '1 month')::date,a.depreciation_start) into depreciated,next_month from public.asset_depreciation_entries where asset_id=a.id;
  if month_value is distinct from next_month or extract(day from month_value)<>1 or month_value>=date_trunc('month',now() at time zone 'Asia/Dhaka')::date or month_value>=(a.depreciation_start+make_interval(months=>a.life_months))::date then raise exception 'Post the next complete scheduled depreciation month, in order.';end if;
  if (select pe.action from public.finance_period_events pe where pe.month=month_value order by pe.event_order desc limit 1)='CLOSE' then raise exception 'Depreciation month is closed. Reopen it before posting.';end if;
  amount_value:=round((a.cost-a.residual)*((extract(year from month_value)::integer-extract(year from a.depreciation_start)::integer)*12+extract(month from month_value)::integer-extract(month from a.depreciation_start)::integer+1)/a.life_months,2)-depreciated;
  if amount_value<0 then raise exception 'Invalid depreciation schedule.';end if;
  select id into accumulated from public.finance_accounts where organization_id=org and account_subtype='ACCUMULATED_DEPRECIATION';select id into expense_account from public.finance_accounts where organization_id=org and account_subtype='DEPRECIATION';
  if amount_value>0 then journal:=public.finance_post_journal(org,(month_value+interval '1 month - 1 day')::date,'ASSET_DEPRECIATION','ASSET_DEPRECIATION',record_id::text,a.asset_no||' depreciation '||month_value,actor,jsonb_build_array(jsonb_build_object('account_id',expense_account,'debit',amount_value,'credit',0),jsonb_build_object('account_id',accumulated,'debit',0,'credit',amount_value)));end if;
  insert into public.asset_depreciation_entries(id,asset_id,month,amount,journal_id,actor_id) values(record_id,a.id,month_value,amount_value,journal,actor);
 elsif action='PAY' then
  if a.payable_id is null or not public.has_permission('finance.payments.post') then raise exception 'An asset supplier payable and payment access are required.';end if;
  amount_value:=(p_input->>'amount')::numeric;if amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) or coalesce(length(btrim(p_input->>'reference')),0)<3 then raise exception 'Enter actual amount and payment reference.';end if;
  perform public.finance_accounting_command(jsonb_build_object('action','SETTLE_PAYABLE','request_id',gen_random_uuid(),'reason',reason,'payable_id',a.payable_id,'amount',amount_value,'payment_account_id',p_input->>'payment_account_id','external_reference',p_input->>'reference'));
 elsif action='DISPOSE' then
  if a.status not in('ACTIVE','INACTIVE') or p_input->>'confirmed' is distinct from 'true' then raise exception 'Confirm disposal of an acquired asset.';end if;date_value:=(p_input->>'date')::date;proceeds_value:=coalesce((p_input->>'proceeds')::numeric,0);
  if date_value is null or date_value<a.in_service_on or date_value>(now() at time zone 'Asia/Dhaka')::date or proceeds_value<0 or proceeds_value<>round(proceeds_value,2) or coalesce(length(btrim(p_input->>'reference')),0)<3 then raise exception 'Check disposal date, actual proceeds and reference.';end if;
  select coalesce(sum(amount),0),coalesce((max(month)+interval '1 month')::date,a.depreciation_start) into depreciated,next_month from public.asset_depreciation_entries where asset_id=a.id;
  due_month:=least((date_trunc('month',date_value)-interval '1 month')::date,(a.depreciation_start+make_interval(months=>a.life_months-1))::date);
  if next_month<=due_month then raise exception 'Post all completed depreciation months before disposal.';end if;
  if exists(select 1 from public.asset_depreciation_entries where asset_id=a.id and month>=date_trunc('month',date_value)::date) then raise exception 'Disposal cannot predate already posted depreciation.';end if;
  book_value:=a.cost-depreciated;select id into accumulated from public.finance_accounts where organization_id=org and account_subtype='ACCUMULATED_DEPRECIATION';select id into gain_account from public.finance_accounts where organization_id=org and account_subtype='ASSET_DISPOSAL_GAIN';select id into loss_account from public.finance_accounts where organization_id=org and account_subtype='ASSET_DISPOSAL_LOSS';
  if proceeds_value>0 then if not public.has_permission('finance.payments.post') then raise exception 'Actual collection access required.';end if;select id into account from public.finance_accounts where id=(p_input->>'payment_account_id')::uuid and organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose active proceeds receiving account.';end if;lines:=lines||jsonb_build_array(jsonb_build_object('account_id',account,'debit',proceeds_value,'credit',0));end if;
  if depreciated>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',accumulated,'debit',depreciated,'credit',0));end if;
  if proceeds_value<book_value then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',loss_account,'debit',book_value-proceeds_value,'credit',0));elsif proceeds_value>book_value then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',gain_account,'debit',0,'credit',proceeds_value-book_value));end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',a.asset_account_id,'debit',0,'credit',a.cost));journal:=public.finance_post_journal(org,date_value,'ASSET_DISPOSAL','ASSET_DISPOSAL',record_id::text,a.asset_no||' disposal',actor,lines);
  insert into public.asset_disposals(id,asset_id,disposed_on,proceeds,book_value,journal_id,reference,actor_id,reason) values(record_id,a.id,date_value,proceeds_value,book_value,journal,p_input->>'reference',actor,reason);update public.academy_assets set status='DISPOSED',custodian_id=null,revision=revision+1,updated_at=now() where id=a.id returning * into a;
 elsif action='MAINTENANCE' then
  if a.status not in('ACTIVE','INACTIVE') or coalesce(length(btrim(p_input->>'details')),0)<5 then raise exception 'Describe maintenance of an acquired asset.';end if;
  if nullif(p_input->>'expense_id','') is not null and not exists(select 1 from public.finance_expenses where id=(p_input->>'expense_id')::uuid and organization_id=org and status='POSTED') then raise exception 'Link a posted academy maintenance expense.';end if;
 else raise exception 'Unknown asset action.';end if;
 insert into public.asset_events(asset_id,action,actor_id,reason,payload) values(a.id,action,actor,reason,p_input||jsonb_build_object('journal_id',journal,'amount',amount_value));
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'ASSET',a.id::text,action,reason,to_jsonb(a)||jsonb_build_object('command',p_input));result:=jsonb_build_object('id',a.id,'message','Asset action recorded with custody/accounting evidence.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.asset_command(jsonb) from public,anon;grant execute on function public.asset_command(jsonb) to authenticated;
create function public.asset_workspace(p_page integer default 1,p_status text default 'ALL',p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('assets.manage');org uuid;total integer;rows jsonb;
begin
 if auth.uid() is null or (not manager and not public.has_permission('workforce.self.view')) or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Asset workspace access required.';end if;
 if p_page is null or p_page not between 1 and 100000 or p_status not in('ALL','DRAFT','ACTIVE','INACTIVE','DISPOSED','CANCELLED') or length(p_search)>100 then raise exception 'Invalid asset filter.';end if;select id into org from public.organizations where code='SOHOJ' and is_active;
 select count(*) into total from public.academy_assets a where a.organization_id=org and public.asset_access(a.id) and (p_status='ALL' or a.status=p_status) and (p_search='' or concat_ws(' ',a.name,a.asset_no,a.location,a.serial_no) ilike '%'||p_search||'%');
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select a.*,s.full_name custodian,coalesce((select sum(amount) from public.asset_depreciation_entries where asset_id=a.id),0) depreciated,case when a.status='DISPOSED' then 0 else a.cost-coalesce((select sum(amount) from public.asset_depreciation_entries where asset_id=a.id),0) end book_value,
 coalesce((select (max(month)+interval '1 month')::date from public.asset_depreciation_entries where asset_id=a.id),a.depreciation_start) next_month,
 case when a.payable_id is null then 0 else (select p.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=p.id),0) from public.finance_payables p where p.id=a.payable_id) end remaining,
 (select id from public.asset_events where asset_id=a.id and action='TRANSFER' order by event_order desc limit 1) transfer_id,
 exists(select 1 from public.staff where id=a.custodian_id and profile_id=auth.uid()) own_custody,
 exists(select 1 from public.asset_events e where e.asset_id=a.id and e.action='ACKNOWLEDGE' and e.payload->>'transfer_id'=(select id::text from public.asset_events where asset_id=a.id and action='TRANSFER' order by event_order desc limit 1)) acknowledged,
 coalesce((select jsonb_agg(jsonb_build_object('action',t.action,'reason',t.reason,'date',t.created_at,'actor',p.display_name,'details',t.payload->>'details') order by t.event_order desc) from(select * from public.asset_events where asset_id=a.id order by event_order desc limit 20)t join public.profiles p on p.id=t.actor_id),'[]'::jsonb) events
 from public.academy_assets a left join public.staff s on s.id=a.custodian_id where a.organization_id=org and public.asset_access(a.id) and (p_status='ALL' or a.status=p_status) and (p_search='' or concat_ws(' ',a.name,a.asset_no,a.location,a.serial_no) ilike '%'||p_search||'%') order by a.created_at desc,a.id limit 25 offset (p_page-1)*25)x;
 return jsonb_build_object('manager',manager,'canPay',manager and public.has_permission('finance.payments.post'),'page',p_page,'total',total,'rows',rows,
 'accounts',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_accounts where organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')),'[]'::jsonb) else '[]'::jsonb end,
 'assetAccounts',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_accounts where organization_id=org and is_active and account_subtype='FIXED_ASSET'),'[]'::jsonb) else '[]'::jsonb end,
 'vendors',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.vendors where organization_id=org and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'staff',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name) order by s.full_name) from public.staff s left join public.branches b on b.id=s.branch_id where s.status in('ACTIVE','ON_LEAVE') and (s.branch_id is null or b.organization_id=org)),'[]'::jsonb) else '[]'::jsonb end,
 'purchases',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',purchase_no||' · '||description) order by created_at desc) from public.finance_purchases p where organization_id=org and status='POSTED' and not exists(select 1 from public.purchase_adjustments where purchase_id=p.id) and not exists(select 1 from public.academy_assets where source_purchase_id=p.id and status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,
 'locations',coalesce((select jsonb_agg(location order by location) from(select distinct location from public.academy_assets where organization_id=org and public.asset_access(id))l),'[]'::jsonb));
end $$;
revoke all on function public.asset_workspace(integer,text,text) from public,anon;grant execute on function public.asset_workspace(integer,text,text) to authenticated;

create or replace function public.finance_document_entity_allowed(p_type text,p_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.expense.manage');
begin if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then return false;end if;
 if p_type='REIMBURSEMENT' then return exists(select 1 from public.staff_reimbursements r join public.organizations o on o.id=r.organization_id join public.staff s on s.id=r.staff_id where r.id=p_id and o.code='SOHOJ' and o.is_active and (manager or (public.has_permission('workforce.self.view') and s.profile_id=auth.uid() and s.status in('ACTIVE','ON_LEAVE'))));end if;
 if p_type='ASSET' then return public.has_permission('assets.manage') and public.asset_access(p_id);end if;
 if not manager then return false;end if;
 if p_type='PURCHASE' then return exists(select 1 from public.finance_purchases p join public.organizations o on o.id=p.organization_id where p.id=p_id and o.code='SOHOJ' and o.is_active);
 elsif p_type='EXPENSE' then return exists(select 1 from public.finance_expenses e join public.organizations o on o.id=e.organization_id where e.id=p_id and o.code='SOHOJ' and o.is_active);end if;return false;
end $$;


create or replace function public.purchase_adjustment_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;p public.finance_purchases;e public.finance_expenses;payable public.finance_payables;a public.purchase_adjustments;action text:=p_input->>'action';amount_value numeric:=(p_input->>'amount')::numeric;cash_value numeric:=coalesce((p_input->>'cash_refund')::numeric,0);credit_value numeric:=0;due_value numeric;account uuid;refund_account uuid;lines jsonb:='[]'::jsonb;journal uuid;record_id uuid:=gen_random_uuid();date_value date:=(p_input->>'date')::date;reason text:=btrim(p_input->>'reason');reference_value text:=btrim(p_input->>'reference');result jsonb;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) or cash_value<0 or cash_value<>round(cash_value,2) or date_value is null or date_value>(now() at time zone 'Asia/Dhaka')::date or coalesce(length(reason),0)<10 or coalesce(length(reference_value),0)<3 then raise exception 'Enter an amount, valid date, document reference and clear explanation.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if action='ADJUST' then
  select * into p from public.finance_purchases where id=(p_input->>'purchase_id')::uuid for update;
  if p.status is distinct from 'POSTED' or not public.finance_document_entity_allowed('PURCHASE',p.id) then raise exception 'Choose a posted purchase.';end if;
  if exists(select 1 from public.academy_assets where source_purchase_id=p.id and status in('ACTIVE','INACTIVE','DISPOSED')) then raise exception 'This purchase was capitalized. Use asset disposal/correction rather than reversing operating expense again.';end if;
  select * into e from public.finance_expenses where id=p.expense_id;
  if date_value<e.expense_date then raise exception 'Adjustment cannot precede its expense.';end if;
  if p_input->>'kind' not in('RETURN','CORRECTION') or p_input->>'confirmed' is distinct from 'true' then raise exception 'Confirm the supplier credit note or expense correction.';end if;
  if amount_value>e.amount-coalesce((select sum(amount) from public.purchase_adjustments where purchase_id=p.id),0) then raise exception 'Adjustment exceeds the remaining original expense.';end if;
  if exists(select 1 from public.purchase_adjustments where purchase_id=p.id and lower(btrim(reference))=lower(reference_value)) then raise exception 'This correction reference is already recorded.';end if;
  if e.payable_id is not null then
   select * into payable from public.finance_payables where id=e.payable_id for update;
   credit_value:=least(amount_value,greatest(0,payable.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=payable.id),0)));
  end if;
  if cash_value>amount_value-credit_value then raise exception 'Cash refund exceeds the paid portion after supplier credit.';end if;
  due_value:=amount_value-credit_value-cash_value;
  if credit_value>0 then
   insert into public.finance_payable_settlements(payable_id,amount,settled_by,reason,external_reference,settlement_kind) values(payable.id,credit_value,actor,reason,reference_value,'CREDIT_NOTE');
   update public.finance_payables set status=case when original_amount<=(select sum(amount) from public.finance_payable_settlements where payable_id=payable.id) then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=payable.id;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',payable.payable_account_id,'debit',credit_value,'credit',0));
  end if;
  if cash_value>0 then
   if not public.has_permission('finance.payments.post') then raise exception 'Payment access required to record money received.';end if;
   select id into account from public.finance_accounts where id=nullif(p_input->>'payment_account_id','')::uuid and organization_id=p.organization_id and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose an active refund-receiving account.';end if;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',account,'debit',cash_value,'credit',0));
  end if;
  if due_value>0 then select id into refund_account from public.finance_accounts where organization_id=p.organization_id and account_subtype='SUPPLIER_REFUND_RECEIVABLE';lines:=lines||jsonb_build_array(jsonb_build_object('account_id',refund_account,'debit',due_value,'credit',0));end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',e.expense_account_id,'debit',0,'credit',amount_value));
  journal:=public.finance_post_journal(p.organization_id,date_value,'PURCHASE_ADJUSTMENT','PURCHASE_ADJUSTMENT',record_id::text,p.purchase_no||' · '||reference_value,actor,lines);
  insert into public.purchase_adjustments(id,purchase_id,kind,reference,adjustment_date,amount,payable_credit,cash_refund,refund_due,payment_account_id,journal_id,reason,actor_id) values(record_id,p.id,p_input->>'kind',reference_value,date_value,amount_value,credit_value,cash_value,due_value,account,journal,reason,actor);
 elsif action='COLLECT_REFUND' then
  select * into a from public.purchase_adjustments where id=(p_input->>'adjustment_id')::uuid for update;
  if a.id is null or not public.finance_document_entity_allowed('PURCHASE',a.purchase_id) or not public.has_permission('finance.payments.post') then raise exception 'Refund collection access required.';end if;
  select * into p from public.finance_purchases where id=a.purchase_id;
  if date_value<a.adjustment_date or amount_value>a.refund_due-coalesce((select sum(amount) from public.purchase_refund_receipts where adjustment_id=a.id),0) then raise exception 'Refund exceeds outstanding supplier refund or precedes its credit note.';end if;
  select id into account from public.finance_accounts where id=(p_input->>'payment_account_id')::uuid and organization_id=p.organization_id and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose an active receiving account.';end if;
  select id into refund_account from public.finance_accounts where organization_id=p.organization_id and account_subtype='SUPPLIER_REFUND_RECEIVABLE';
  journal:=public.finance_post_journal(p.organization_id,date_value,'SUPPLIER_REFUND','SUPPLIER_REFUND',record_id::text,reference_value,actor,jsonb_build_array(jsonb_build_object('account_id',account,'debit',amount_value,'credit',0),jsonb_build_object('account_id',refund_account,'debit',0,'credit',amount_value)));
  insert into public.purchase_refund_receipts(id,adjustment_id,amount,receipt_date,payment_account_id,reference,reason,actor_id,journal_id) values(record_id,a.id,amount_value,date_value,account,reference_value,reason,actor,journal);
 else raise exception 'Unknown purchase adjustment action.';end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'PURCHASE',p.id::text,action,reason,p_input||jsonb_build_object('journal_id',journal));result:=jsonb_build_object('id',record_id,'message','Compensating entry posted. Original expense and payment history remain unchanged.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.purchase_adjustment_command(jsonb) from public,anon;
grant execute on function public.purchase_adjustment_command(jsonb) to authenticated;

create or replace function public.finance_period_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;month_value date:=(p_input->>'month')::date;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');state text;key public.admission_command_keys;report jsonb;result jsonb;rid uuid;
begin
 if actor is null or not public.has_permission('accounting.period.manage') or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Accounting period management permission required.';end if;
 if req is null or coalesce(length(reason),0)<10 or month_value is null then raise exception 'Request identity, month and clear explanation are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 perform pg_advisory_xact_lock(hashtextextended('asset-financial-register',38));
 perform pg_advisory_xact_lock(hashtextextended('finance-period:'||month_value::text,37));
 report:=public.monthly_financial_report(month_value);
 select e.action into state from public.finance_period_events e where month=month_value order by event_order desc limit 1;
 if action='CLOSE' then
  if exists(select 1 from public.academy_assets a where a.organization_id=(select id from public.organizations where code='SOHOJ' and is_active) and a.status in('ACTIVE','INACTIVE') and a.depreciation_start<=month_value and month_value<(a.depreciation_start+make_interval(months=>a.life_months))::date and not exists(select 1 from public.asset_depreciation_entries where asset_id=a.id and month=month_value)) then raise exception 'Post all scheduled asset depreciation for this month before closing.';end if;
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
