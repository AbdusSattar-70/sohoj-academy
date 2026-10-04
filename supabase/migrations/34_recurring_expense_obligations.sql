create table public.finance_recurring_expenses(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),name text not null check(length(btrim(name)) between 3 and 200),vendor_id uuid not null references public.vendors(id),category_id uuid not null references public.finance_expense_categories(id),amount numeric(14,2) not null check(amount>0 and amount<>'NaN'::numeric),first_month date not null check(extract(day from first_month)=1),due_day integer not null check(due_day between 1 and 28),is_active boolean not null default true,revision integer not null default 1,actor_id uuid not null references public.profiles(id),reason text not null,updated_at timestamptz not null default now()
);
create unique index recurring_expense_name on public.finance_recurring_expenses(organization_id,lower(btrim(name))) where is_active;
create table public.finance_recurring_occurrences(
 id uuid primary key default gen_random_uuid(),schedule_id uuid not null references public.finance_recurring_expenses(id),month date not null,purchase_id uuid not null unique references public.finance_purchases(id),snapshot jsonb not null,event_order bigint generated always as identity unique,actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
create index recurring_occurrence_month on public.finance_recurring_occurrences(schedule_id,month,event_order desc);
alter table public.finance_recurring_expenses enable row level security;
alter table public.finance_recurring_occurrences enable row level security;
revoke all on public.finance_recurring_expenses,public.finance_recurring_occurrences from public,anon,authenticated;
create trigger recurring_no_delete before delete on public.finance_recurring_expenses for each row execute function public.prevent_permanent_record_delete();
create trigger recurring_occurrence_immutable before update or delete on public.finance_recurring_occurrences for each row execute function public.prevent_permanent_record_delete();
create function public.recurring_expense_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');org uuid;key public.admission_command_keys;r public.finance_recurring_expenses;oldval jsonb;mon date;purchase public.finance_purchases;res jsonb;amount_value numeric;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 if nullif(p_input->>'id','') is not null then select * into r from public.finance_recurring_expenses where id=(p_input->>'id')::uuid and organization_id=org for update;if not found then raise exception 'Schedule unavailable.';end if;oldval:=to_jsonb(r);end if;
 if p_input->>'action'='SAVE' then
  if r.id is not null and r.revision is distinct from (p_input->>'revision')::int then raise exception 'Schedule changed. Refresh before editing.';end if;
  amount_value:=(p_input->>'amount')::numeric;
  if amount_value is null or amount_value<=0 or amount_value='NaN'::numeric or amount_value<>round(amount_value,2) then raise exception 'Enter a positive finite amount.';end if;
  if not exists(select 1 from public.vendors where id=(p_input->>'vendor_id')::uuid and organization_id=org and is_active) or not exists(select 1 from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.id=(p_input->>'category_id')::uuid and c.organization_id=org and c.is_active and a.is_active and a.account_type='EXPENSE') then raise exception 'Select an active supplier and expense category.';end if;
  if r.id is null then insert into public.finance_recurring_expenses(organization_id,name,vendor_id,category_id,amount,first_month,due_day,actor_id,reason) values(org,btrim(p_input->>'name'),(p_input->>'vendor_id')::uuid,(p_input->>'category_id')::uuid,amount_value,(p_input->>'first_month')::date,(p_input->>'due_day')::int,actor,why) returning * into r;
  else update public.finance_recurring_expenses set name=btrim(p_input->>'name'),vendor_id=(p_input->>'vendor_id')::uuid,category_id=(p_input->>'category_id')::uuid,amount=amount_value,first_month=(p_input->>'first_month')::date,due_day=(p_input->>'due_day')::int,actor_id=actor,reason=why,revision=revision+1,updated_at=now() where id=r.id returning * into r;end if;
  res:=jsonb_build_object('id',r.id,'message','Schedule saved. No expense or payment posted.');
 elsif p_input->>'action'='SET_ACTIVE' then
  if r.id is null or r.revision is distinct from (p_input->>'revision')::int or p_input->>'is_active' not in('true','false') or p_input->>'is_active' is null then raise exception 'Refresh and select valid schedule status.';end if;
  update public.finance_recurring_expenses set is_active=(p_input->>'is_active')::boolean,revision=revision+1,actor_id=actor,reason=why,updated_at=now() where id=r.id returning * into r;res:=jsonb_build_object('id',r.id,'message','Schedule status saved; previous bills remain.');
 elsif p_input->>'action'='GENERATE' then
  mon:=(p_input->>'month')::date;
  if r.id is null or not r.is_active or mon is null or extract(day from mon)<>1 or mon<r.first_month or mon>date_trunc('month',now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose a due current/past month in the active schedule.';end if;
  select p.* into purchase from public.finance_recurring_occurrences o join public.finance_purchases p on p.id=o.purchase_id where o.schedule_id=r.id and o.month=mon order by o.event_order desc limit 1;
  if purchase.id is not null and purchase.status<>'CANCELLED' then raise exception 'A bill draft already exists. Open it instead of duplicating it.';end if;
  res:=public.purchase_command(jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'reason',why,'vendor_id',r.vendor_id,'category_id',r.category_id,'description',r.name||' · '||to_char(mon,'YYYY-MM'),'expected_on',mon+r.due_day-1,'items',jsonb_build_array(jsonb_build_object('name',r.name,'quantity',1,'price',r.amount))));
  insert into public.finance_recurring_occurrences(schedule_id,month,purchase_id,snapshot,actor_id) values(r.id,mon,(res->>'id')::uuid,to_jsonb(r),actor);
  res:=jsonb_build_object('id',r.id,'purchaseId',res->>'id','message','Monthly draft created. Verify actual bill and receipt in Purchases before posting.');
 else raise exception 'Unknown recurring expense action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'RECURRING_EXPENSE',r.id::text,p_input->>'action',why,oldval,to_jsonb(r)||res,req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.recurring_expense_command(jsonb) from public,anon;
grant execute on function public.recurring_expense_command(jsonb) to authenticated;
create function public.recurring_expense_workspace(p_month date default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;mon date:=coalesce(p_month,date_trunc('month',now() at time zone 'Asia/Dhaka')::date);
begin
 if auth.uid() is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or mon is null or extract(day from mon)<>1 then raise exception 'Invalid month or page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 return jsonb_build_object('month',mon,'total',(select count(*) from public.finance_recurring_expenses where organization_id=org),
 'rows',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select r.*,v.name supplier,c.name category,mon+r.due_day-1 due_on,p.id purchase_id,p.purchase_no,p.status purchase_status from public.finance_recurring_expenses r join public.vendors v on v.id=r.vendor_id join public.finance_expense_categories c on c.id=r.category_id left join lateral(select fp.* from public.finance_recurring_occurrences o join public.finance_purchases fp on fp.id=o.purchase_id where o.schedule_id=r.id and o.month=mon order by o.event_order desc limit 1)p on true where r.organization_id=org order by r.is_active desc,r.name,r.id limit 25 offset (p_page-1)*25)x),
 'vendors',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]'::jsonb) from public.vendors where organization_id=org and is_active),
 'categories',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]'::jsonb) from public.finance_expense_categories where organization_id=org and is_active));
end $$;
revoke all on function public.recurring_expense_workspace(date,integer) from public,anon;
grant execute on function public.recurring_expense_workspace(date,integer) to authenticated;
