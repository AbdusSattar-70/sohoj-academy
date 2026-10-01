-- Purchasing is evidence first. Saving a draft never moves cash or creates a liability.
create sequence public.purchase_no_seq;
create table public.finance_purchases(
 id uuid primary key default gen_random_uuid(), purchase_no text not null unique default ('PUR-'||lpad(nextval('public.purchase_no_seq')::text,6,'0')),
 organization_id uuid not null references public.organizations(id),vendor_id uuid not null references public.vendors(id),category_id uuid not null references public.finance_expense_categories(id),
 description text not null,items jsonb not null,total numeric(14,2) not null check(total>0),expected_on date,
 status text not null default 'DRAFT' check(status in('DRAFT','CANCELLED','POSTED')),revision integer not null default 1,
 invoice_reference text,received_on date,expense_id uuid unique references public.finance_expenses(id),
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check((status='POSTED')=(expense_id is not null))
);
create unique index purchase_supplier_invoice on public.finance_purchases(organization_id,vendor_id,lower(btrim(invoice_reference))) where status='POSTED';
create index purchase_register_lookup on public.finance_purchases(organization_id,created_at desc,id);
alter table public.finance_purchases enable row level security;
create policy purchase_read on public.finance_purchases for select to authenticated using(public.has_permission('accounting.expense.manage') and organization_id=(select id from public.organizations where code='SOHOJ' and is_active));
grant select on public.finance_purchases to authenticated;
revoke insert,update,delete on public.finance_purchases from anon,authenticated;
create function public.guard_purchase_history() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='DELETE' then raise exception 'Purchases cannot be deleted. Cancel an unused draft.';end if;
 if old.status<>'DRAFT' then raise exception 'Final purchase evidence is immutable.';end if;return new;end $$;
create trigger purchase_history before update or delete on public.finance_purchases for each row execute function public.guard_purchase_history();

create function public.purchase_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;org uuid;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');r public.finance_purchases;before_value jsonb;item jsonb;total_value numeric:=0;quantity numeric;price numeric;result jsonb;expense_result jsonb;vendor uuid;category uuid;received date;amount numeric;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or coalesce(length(reason),0)<5 then raise exception 'Request identity and a clear reason are required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;if org is null then raise exception 'Active academy unavailable.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if action='CREATE_VENDOR' then
  if coalesce(length(btrim(p_input->>'name')),0)<2 then raise exception 'Supplier name is required.';end if;
  perform pg_advisory_xact_lock(hashtextextended(org::text||lower(btrim(p_input->>'name')),22));
  if exists(select 1 from public.vendors where organization_id=org and lower(btrim(name))=lower(btrim(p_input->>'name')) and is_active) then raise exception 'An active supplier with this name already exists. Select the existing supplier.';end if;
  insert into public.vendors(organization_id,name,mobile,email,address,created_by) values(org,btrim(p_input->>'name'),nullif(btrim(p_input->>'mobile'),''),nullif(lower(btrim(p_input->>'email')),''),nullif(btrim(p_input->>'address'),''),actor) returning id into vendor;
  result:=jsonb_build_object('id',vendor,'message','Supplier added. Select the supplier to continue your purchase.');
 elsif action in('SAVE','CANCEL','RECEIVE','PAY') then
  if nullif(p_input->>'id','') is not null then
   select * into r from public.finance_purchases where id=(p_input->>'id')::uuid and organization_id=org for update;
   if r.id is null then raise exception 'Purchase unavailable.';end if;
   if r.revision is distinct from (p_input->>'revision')::integer then raise exception 'This purchase changed. Refresh it before continuing.';end if;
   before_value:=to_jsonb(r);
  elsif action<>'SAVE' then raise exception 'Select a purchase first.';end if;
  if action='SAVE' then
   if r.id is not null and r.status<>'DRAFT' then raise exception 'Only drafts can be edited.';end if;
   vendor:=(p_input->>'vendor_id')::uuid;category:=(p_input->>'category_id')::uuid;
   if not exists(select 1 from public.vendors where id=vendor and organization_id=org and is_active) then raise exception 'Select an active supplier.';end if;
   if not exists(select 1 from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.id=category and c.organization_id=org and c.is_active and a.is_active and a.account_type='EXPENSE') then raise exception 'Select an active operating expense category.';end if;
   if coalesce(length(btrim(p_input->>'description')),0)<3 or jsonb_typeof(p_input->'items') is distinct from 'array' or jsonb_array_length(p_input->'items') not between 1 and 30 then raise exception 'Describe the purchase and add one to thirty items.';end if;
   for item in select value from jsonb_array_elements(p_input->'items') loop
    quantity:=(item->>'quantity')::numeric;price:=(item->>'price')::numeric;
    if coalesce(length(btrim(item->>'name')),0)<2 or quantity is null or quantity<=0 or quantity>100000 or quantity<>round(quantity,3) or price is null or price<=0 or price>999999999999.99 or price<>round(price,2) then raise exception 'Each item needs a name, positive quantity and a positive two-decimal unit price.';end if;
    total_value:=total_value+round(quantity*price,2);
   end loop;
   if total_value>999999999999.99 then raise exception 'Purchase total exceeds the supported amount.';end if;
   if r.id is null then
    insert into public.finance_purchases(organization_id,vendor_id,category_id,description,items,total,expected_on,created_by) values(org,vendor,category,btrim(p_input->>'description'),p_input->'items',total_value,nullif(p_input->>'expected_on','')::date,actor) returning * into r;
   else
    update public.finance_purchases set vendor_id=vendor,category_id=category,description=btrim(p_input->>'description'),items=p_input->'items',total=total_value,expected_on=nullif(p_input->>'expected_on','')::date,revision=revision+1,updated_at=now() where id=r.id returning * into r;
   end if;
   result:=jsonb_build_object('id',r.id,'message','Purchase draft saved. No expense, payment or payable has been posted.');
  elsif action='CANCEL' then
   if r.status<>'DRAFT' then raise exception 'Only unused drafts can be cancelled.';end if;
   update public.finance_purchases set status='CANCELLED',revision=revision+1,updated_at=now() where id=r.id returning * into r;
   result:=jsonb_build_object('id',r.id,'message','Draft cancelled; its history remains available.');
  elsif action='RECEIVE' then
   if r.status<>'DRAFT' then raise exception 'This purchase has already been completed or cancelled.';end if;
   received:=(p_input->>'received_on')::date;
   if received is null or received>(now() at time zone 'Asia/Dhaka')::date or coalesce(length(btrim(p_input->>'invoice_reference')),0)<3 or p_input->>'confirmed_received' is distinct from 'true' then raise exception 'Confirm full receipt, a valid receipt date and supplier invoice reference.';end if;
   perform pg_advisory_xact_lock(hashtextextended(org::text||r.vendor_id::text||lower(btrim(p_input->>'invoice_reference')),23));
   if exists(select 1 from public.finance_purchases where organization_id=org and vendor_id=r.vendor_id and status='POSTED' and lower(btrim(invoice_reference))=lower(btrim(p_input->>'invoice_reference'))) then raise exception 'This supplier invoice is already recorded. Check the purchase register instead of posting it again.';end if;
   if p_input->>'payment_mode'='PAID_NOW' and not public.has_permission('finance.payments.post') then raise exception 'Payment posting access required for paid-now receipt.';end if;
   if p_input->>'payment_mode' not in('PAID_NOW','ON_ACCOUNT') or p_input->>'payment_mode' is null then raise exception 'Choose paid now or payable later.';end if;
   if not exists(select 1 from public.vendors where id=r.vendor_id and organization_id=org and is_active) then raise exception 'Supplier is inactive. Edit the draft and select an active supplier.';end if;
   -- Use a separate request identity for the internal expense engine; the outer identity owns purchase retries.
   expense_result:=public.post_accounting_operation(jsonb_build_object('action','CREATE_EXPENSE_DIRECT','request_id',gen_random_uuid(),'reason',reason,'amount',r.total,'category_id',r.category_id,'vendor_id',r.vendor_id,'expense_date',received,'payment_mode',p_input->>'payment_mode','payment_account_id',p_input->>'payment_account_id','description',r.purchase_no||' · '||r.description,'receipt_reference',btrim(p_input->>'invoice_reference')));
   update public.finance_purchases set status='POSTED',expense_id=(expense_result->>'id')::uuid,received_on=received,invoice_reference=btrim(p_input->>'invoice_reference'),revision=revision+1,updated_at=now() where id=r.id returning * into r;
   result:=jsonb_build_object('id',r.id,'message','Receipt verified and expense posted. Unpaid charges remain supplier payable.');
  elsif action='PAY' then
   if not public.has_permission('finance.payments.post') then raise exception 'Payment posting access required.';end if;
   if r.status<>'POSTED' then raise exception 'Receive and post the purchase before paying a supplier payable.';end if;
   amount:=(p_input->>'amount')::numeric;
   if amount is null or amount<=0 or amount<>round(amount,2) or coalesce(length(btrim(p_input->>'external_reference')),0)<3 then raise exception 'Enter a positive two-decimal payment and its reference.';end if;
   result:=public.finance_accounting_command(jsonb_build_object('action','SETTLE_PAYABLE','request_id',gen_random_uuid(),'reason',reason,'payable_id',(select payable_id from public.finance_expenses where id=r.expense_id),'amount',amount,'payment_account_id',p_input->>'payment_account_id','external_reference',btrim(p_input->>'external_reference')));
   result:=jsonb_build_object('id',r.id,'message','Supplier payment posted; any remaining balance stays due.');
  end if;
 else raise exception 'Unknown purchasing action.';end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data) values(req,actor,case when action='CREATE_VENDOR' then 'VENDOR' else 'PURCHASE' end,result->>'id',action,reason,before_value,case when action='CREATE_VENDOR' then result else to_jsonb(r) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end $$;
revoke all on function public.purchase_command(jsonb) from public,anon;
grant execute on function public.purchase_command(jsonb) to authenticated;

create function public.purchase_workspace(p_page integer default 1,p_status text default 'ALL',p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;result jsonb;
begin
 if auth.uid() is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if p_page<1 or p_page>100000 or p_status not in('ALL','DRAFT','POSTED','CANCELLED') or length(p_search)>100 then raise exception 'Invalid register filters.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select jsonb_build_object('page',p_page,'total',(select count(*) from public.finance_purchases p join public.vendors v on v.id=p.vendor_id where p.organization_id=org and (p_status='ALL' or p.status=p_status) and (p_search='' or p.purchase_no ilike '%'||p_search||'%' or p.description ilike '%'||p_search||'%' or v.name ilike '%'||p_search||'%')),
 'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select p.*,v.name supplier,c.name category,e.expense_no,e.payment_mode,e.payable_id,case when e.payable_id is null then 0 else coalesce(e.amount-(select coalesce(sum(s.amount),0) from public.finance_payable_settlements s where s.payable_id=e.payable_id),0) end remaining
 from public.finance_purchases p join public.vendors v on v.id=p.vendor_id join public.finance_expense_categories c on c.id=p.category_id left join public.finance_expenses e on e.id=p.expense_id
 where p.organization_id=org and (p_status='ALL' or p.status=p_status) and (p_search='' or p.purchase_no ilike '%'||p_search||'%' or p.description ilike '%'||p_search||'%' or v.name ilike '%'||p_search||'%') order by p.created_at desc,p.id limit 25 offset (p_page-1)*25)x),'[]'::jsonb),
 'vendors',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.vendors where organization_id=org and is_active),'[]'::jsonb),
 'categories',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_expense_categories where organization_id=org and is_active),'[]'::jsonb),
 'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_accounts where organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')),'[]'::jsonb),
 'canPay',public.has_permission('finance.payments.post')) into result;return result;
end $$;
revoke all on function public.purchase_workspace(integer,text,text) from public,anon;
grant execute on function public.purchase_workspace(integer,text,text) to authenticated;
