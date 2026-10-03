-- Orders are commitments, not expenses. Only verified received/invoiced portions post.
create sequence public.procurement_order_no_seq;
create table public.procurement_orders(id uuid primary key default gen_random_uuid(),order_no text not null unique default ('PO-'||lpad(nextval('public.procurement_order_no_seq')::text,6,'0')),organization_id uuid not null references public.organizations(id),vendor_id uuid not null references public.vendors(id),category_id uuid not null references public.finance_expense_categories(id),description text not null,items jsonb not null,total numeric(14,2) not null check(total>0 and total<>'NaN'::numeric),expected_on date,status text not null default 'OPEN' check(status in('OPEN','COMPLETE','CLOSED','CANCELLED')),revision integer not null default 1,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create index procurement_register on public.procurement_orders(organization_id,created_at desc,id);
create table public.procurement_receipts(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.procurement_orders(id),purchase_id uuid not null unique references public.finance_purchases(id),items jsonb not null,invoice_total numeric(14,2) not null check(invoice_total>0 and invoice_total<>'NaN'::numeric),price_variance_reason text,actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create index procurement_order_receipts on public.procurement_receipts(order_id,created_at desc,id);
alter table public.procurement_orders enable row level security;alter table public.procurement_receipts enable row level security;
revoke all on public.procurement_orders,public.procurement_receipts from public,anon,authenticated;
create function public.guard_procurement_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Orders cannot be deleted. Close or cancel the outstanding commitment.';end if;
 if old.status<>'OPEN' then raise exception 'Completed or closed order history is immutable.';end if;
 if exists(select 1 from public.procurement_receipts where order_id=old.id) and (new.items is distinct from old.items or new.vendor_id<>old.vendor_id or new.category_id<>old.category_id or new.total<>old.total or new.description<>old.description) then raise exception 'Received order terms are immutable. Use a new order for additional or changed commitments.';end if;
 return new;
end $$;
create trigger procurement_history before update or delete on public.procurement_orders for each row execute function public.guard_procurement_history();
create trigger procurement_receipt_history before update or delete on public.procurement_receipts for each row execute function public.prevent_permanent_record_delete();
create function public.procurement_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;org uuid;r public.procurement_orders;why text:=btrim(p_input->>'reason');action text:=p_input->>'action';item jsonb;ordered jsonb;idx integer;quantity numeric;price numeric;total_value numeric:=0;already numeric;receipt_items jsonb:='[]'::jsonb;purchase_items jsonb:='[]'::jsonb;variance boolean:=false;invoice_total numeric:=(p_input->>'invoice_total')::numeric;purchase uuid;rid uuid;vendor uuid;category uuid;result jsonb;before_value jsonb;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and clear explanation required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if nullif(p_input->>'id','') is not null then
  select * into r from public.procurement_orders where id=(p_input->>'id')::uuid and organization_id=org for update;
  if r.id is null or r.revision is distinct from (p_input->>'revision')::integer or r.status<>'OPEN' then raise exception 'Order changed or is no longer open. Review the register.';end if;before_value:=to_jsonb(r);
 elsif action<>'SAVE' then raise exception 'Choose an open order.';end if;
 if action='SAVE' then
  vendor:=(p_input->>'vendor_id')::uuid;category:=(p_input->>'category_id')::uuid;
  if not exists(select 1 from public.vendors where id=vendor and organization_id=org and is_active) or not exists(select 1 from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.id=category and c.organization_id=org and c.is_active and a.is_active and a.account_type='EXPENSE') then raise exception 'Choose active supplier and operating expense category.';end if;
  if coalesce(length(btrim(p_input->>'description')),0) not between 3 and 1000 or jsonb_typeof(p_input->'items') is distinct from 'array' or jsonb_array_length(p_input->'items') not between 1 and 30 then raise exception 'Describe the order and add one to thirty lines.';end if;
  for item in select value from jsonb_array_elements(p_input->'items') loop
   quantity:=(item->>'quantity')::numeric;price:=(item->>'price')::numeric;
   if coalesce(length(btrim(item->>'name')),0) not between 2 and 200 or quantity is null or quantity::text in('NaN','Infinity','-Infinity') or quantity<=0 or quantity>100000 or round(quantity,3)<>quantity or price is null or price::text in('NaN','Infinity','-Infinity') or price<=0 or round(price,2)<>price then raise exception 'Each ordered line needs a name, positive quantity (three decimals) and finite two-decimal price.';end if;
   total_value:=total_value+round(quantity*price,2);
  end loop;
  if total_value>999999999999.99 then raise exception 'Order total exceeds supported value.';end if;
  if r.id is null then insert into public.procurement_orders(organization_id,vendor_id,category_id,description,items,total,expected_on,created_by) values(org,vendor,category,btrim(p_input->>'description'),p_input->'items',total_value,nullif(p_input->>'expected_on','')::date,actor) returning * into r;
  else update public.procurement_orders set vendor_id=vendor,category_id=category,description=btrim(p_input->>'description'),items=p_input->'items',total=total_value,expected_on=nullif(p_input->>'expected_on','')::date,revision=revision+1 where id=r.id returning * into r;end if;
  result:=jsonb_build_object('id',r.id,'message','Order saved. No expense, cash movement or payable was created.');
 elsif action='CLOSE' then
  update public.procurement_orders set status=case when exists(select 1 from public.procurement_receipts where order_id=r.id) then 'CLOSED' else 'CANCELLED' end,revision=revision+1 where id=r.id returning * into r;
  result:=jsonb_build_object('id',r.id,'message','Outstanding commitment closed. Existing receipts, expenses and supplier balances remain unchanged.');
 elsif action='RECEIVE' then
  if jsonb_typeof(p_input->'items') is distinct from 'array' or jsonb_array_length(p_input->'items') not between 1 and 30 or p_input->>'confirmed_received' is distinct from 'true' then raise exception 'Select received lines and confirm actual delivery and invoice.';end if;
  if exists(select 1 from jsonb_array_elements(p_input->'items')i group by i->>'line' having count(*)>1) then raise exception 'A received order line may appear only once.';end if;
  for item in select value from jsonb_array_elements(p_input->'items') loop
   idx:=(item->>'line')::integer;quantity:=(item->>'quantity')::numeric;price:=(item->>'price')::numeric;
   if idx is null or idx<1 or idx>jsonb_array_length(r.items) then raise exception 'Received line does not belong to this order.';end if;ordered:=r.items->(idx-1);
   if quantity is null or quantity::text in('NaN','Infinity','-Infinity') or quantity<=0 or quantity>100000 or round(quantity,3)<>quantity or price is null or price::text in('NaN','Infinity','-Infinity') or price<=0 or round(price,2)<>price then raise exception 'Received quantity and invoiced unit price must be positive and finite.';end if;
   select coalesce(sum((x->>'quantity')::numeric),0) into already from public.procurement_receipts pr cross join lateral jsonb_array_elements(pr.items)x where pr.order_id=r.id and (x->>'line')::integer=idx;
   if already+quantity>(ordered->>'quantity')::numeric then raise exception 'Line % receipt exceeds the outstanding ordered quantity.',idx;end if;
   variance:=variance or price<>(ordered->>'price')::numeric;total_value:=total_value+round(quantity*price,2);
   receipt_items:=receipt_items||jsonb_build_array(jsonb_build_object('line',idx,'name',ordered->>'name','quantity',quantity,'price',price));purchase_items:=purchase_items||jsonb_build_array(jsonb_build_object('name',ordered->>'name','quantity',quantity,'price',price));
  end loop;
  if invoice_total is null or invoice_total::text in('NaN','Infinity','-Infinity') or invoice_total<>total_value or round(invoice_total,2)<>invoice_total or total_value>999999999999.99 then raise exception 'Supplier invoice total must exactly match this received portion. Do not post a whole-order invoice as a partial bill.';end if;
  if variance and coalesce(length(btrim(p_input->>'price_variance_reason')),0) not between 5 and 1000 then raise exception 'Explain the verified invoice price difference from the order.';end if;
  purchase:=(public.purchase_command(jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'vendor_id',r.vendor_id,'category_id',r.category_id,'description',r.order_no||' · '||r.description,'items',purchase_items,'reason',why))->>'id')::uuid;
  perform public.purchase_command(jsonb_build_object('action','RECEIVE','request_id',gen_random_uuid(),'id',purchase,'revision',1,'received_on',p_input->>'received_on','invoice_reference',p_input->>'invoice_reference','confirmed_received',true,'payment_mode',p_input->>'payment_mode','payment_account_id',p_input->>'payment_account_id','reason',why));
  insert into public.procurement_receipts(order_id,purchase_id,items,invoice_total,price_variance_reason,actor_id,reason) values(r.id,purchase,receipt_items,total_value,nullif(btrim(p_input->>'price_variance_reason'),''),actor,why) returning id into rid;
  update public.procurement_orders set revision=revision+1,status=case when not exists(select 1 from jsonb_array_elements(items) with ordinality o(value,n) where (o.value->>'quantity')::numeric>(select coalesce(sum((x->>'quantity')::numeric),0) from public.procurement_receipts pr cross join lateral jsonb_array_elements(pr.items)x where pr.order_id=r.id and (x->>'line')::integer=o.n)) then 'COMPLETE' else 'OPEN' end where id=r.id returning * into r;
  result:=jsonb_build_object('id',r.id,'purchaseId',purchase,'message',case when r.status='COMPLETE' then 'All ordered quantities received. Find this order under COMPLETE; each received invoice remains in Purchases.' else 'Received portion and matching invoice posted. Outstanding quantities remain in this open order.' end);
 else raise exception 'Unknown procurement action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'PROCUREMENT_ORDER',r.id::text,action,why,before_value,to_jsonb(r)||jsonb_build_object('receipt_id',rid,'purchase_id',purchase),req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.procurement_command(jsonb) from public,anon;grant execute on function public.procurement_command(jsonb) to authenticated;
create function public.procurement_workspace(p_page integer default 1,p_status text default 'OPEN',p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if p_page not between 1 and 10000 or p_status not in('ALL','OPEN','COMPLETE','CLOSED','CANCELLED') or length(coalesce(p_search,''))>100 then raise exception 'Invalid order filters.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select count(*) into total from public.procurement_orders o join public.vendors v on v.id=o.vendor_id where o.organization_id=org and (p_status='ALL' or o.status=p_status) and (coalesce(p_search,'')='' or o.order_no ilike '%'||p_search||'%' or o.description ilike '%'||p_search||'%' or v.name ilike '%'||p_search||'%');
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select o.*,v.name supplier,(select jsonb_agg(value||jsonb_build_object('line',n,'received',coalesce((select sum((x->>'quantity')::numeric) from public.procurement_receipts r cross join lateral jsonb_array_elements(r.items)x where r.order_id=o.id and (x->>'line')::integer=n),0)) order by n) from jsonb_array_elements(o.items) with ordinality i(value,n)) lines,(select count(*) from public.procurement_receipts where order_id=o.id) receipt_count,(select coalesce(jsonb_agg(to_jsonb(h)),'[]'::jsonb) from(select r.id,r.purchase_id,r.items,r.invoice_total,r.price_variance_reason,r.created_at,r.reason,p.purchase_no,p.invoice_reference,p.received_on,p.revision,coalesce((select e.amount-coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=e.payable_id),0) from public.finance_expenses e where e.id=p.expense_id and e.payable_id is not null),0) remaining from public.procurement_receipts r join public.finance_purchases p on p.id=r.purchase_id where r.order_id=o.id order by r.created_at desc,r.id limit 10)h) receipts from public.procurement_orders o join public.vendors v on v.id=o.vendor_id where o.organization_id=org and (p_status='ALL' or o.status=p_status) and (coalesce(p_search,'')='' or o.order_no ilike '%'||p_search||'%' or o.description ilike '%'||p_search||'%' or v.name ilike '%'||p_search||'%') order by o.created_at desc,o.id limit 25 offset (p_page-1)*25)x;
 return jsonb_build_object('total',total,'rows',rows,'canPay',public.has_permission('finance.payments.post'),'vendors',(select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) from(select id,name from public.vendors where organization_id=org and is_active order by name,id limit 200)v),'categories',(select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) from(select c.id,c.name from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.organization_id=org and c.is_active and a.is_active and a.account_type='EXPENSE' order by c.name,c.id limit 200)c),'accounts',(select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from(select id,name from public.finance_accounts where organization_id=org and is_active and account_type='ASSET' and account_subtype in('CASH','BANK','MOBILE_BANK') order by name,id limit 200)a));
end $$;
revoke all on function public.procurement_workspace(integer,text,text) from public,anon;grant execute on function public.procurement_workspace(integer,text,text) to authenticated;
