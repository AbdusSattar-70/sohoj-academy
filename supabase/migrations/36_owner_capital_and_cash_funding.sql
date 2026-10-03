insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'3100','Owner Contributed Capital','EQUITY','OWNER_CAPITAL',true from public.organizations where code='SOHOJ' on conflict(organization_id,code) do nothing;
create table public.finance_owners(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),name text not null check(length(btrim(name)) between 2 and 200),contact text not null default '',is_active boolean not null default true,revision integer not null default 1,actor_id uuid not null references public.profiles(id),reason text not null);
create unique index owner_active_name on public.finance_owners(organization_id,lower(btrim(name))) where is_active;
create table public.finance_capital_movements(id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.finance_owners(id),kind text not null check(kind in('CONTRIBUTION','CAPITAL_RETURN')),amount numeric(14,2) not null check(amount>0 and amount<>'NaN'::numeric),account_id uuid not null references public.finance_accounts(id),reference text not null check(length(btrim(reference)) between 3 and 200),journal_id uuid not null unique references public.general_ledger_journals(id),actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create unique index capital_reference on public.finance_capital_movements(account_id,lower(btrim(reference)));
alter table public.finance_owners enable row level security;
alter table public.finance_capital_movements enable row level security;
revoke all on public.finance_owners,public.finance_capital_movements from public,anon,authenticated;
create trigger owner_no_delete before delete on public.finance_owners for each row execute function public.prevent_permanent_record_delete();
create trigger capital_immutable before update or delete on public.finance_capital_movements for each row execute function public.prevent_permanent_record_delete();
create function public.owner_capital_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');key public.admission_command_keys;org uuid;owner public.finance_owners;beforeval jsonb;amount_value numeric;balance numeric;account uuid;equity uuid;rid uuid:=gen_random_uuid();jid uuid;kind text:=p_input->>'kind';res jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 if actor is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Capital management permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 if p_input->>'action' in('SAVE_OWNER','SET_ACTIVE') then
  if nullif(p_input->>'id','') is not null then select * into owner from public.finance_owners where id=(p_input->>'id')::uuid and organization_id=org for update;if not found or owner.revision is distinct from (p_input->>'revision')::int then raise exception 'Owner changed or unavailable. Refresh first.';end if;beforeval:=to_jsonb(owner);end if;
  if p_input->>'action'='SET_ACTIVE' then
   if owner.id is null or p_input->>'is_active' is null then raise exception 'Select owner and status.';end if;
   update public.finance_owners set is_active=(p_input->>'is_active')::boolean,revision=revision+1,actor_id=actor,reason=why where id=owner.id returning * into owner;
  elsif owner.id is null then insert into public.finance_owners(organization_id,name,contact,actor_id,reason) values(org,btrim(p_input->>'name'),coalesce(p_input->>'contact',''),actor,why) returning * into owner;
  else update public.finance_owners set name=btrim(p_input->>'name'),contact=coalesce(p_input->>'contact',''),revision=revision+1,actor_id=actor,reason=why where id=owner.id returning * into owner;end if;
  res:=jsonb_build_object('id',owner.id,'message','Owner details saved; capital evidence stays intact.');
 elsif p_input->>'action'='POST' then
  -- Same period/account ordering as the ledger writer; lock owner before checking returned capital.
  perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',day)::date::text,37));
  select * into owner from public.finance_owners where id=(p_input->>'owner_id')::uuid and organization_id=org and is_active for update;if not found then raise exception 'Select an active owner.';end if;
  amount_value:=(p_input->>'amount')::numeric;
  if amount_value is null or amount_value<=0 or amount_value='NaN'::numeric or amount_value<>round(amount_value,2) or kind is null or kind not in('CONTRIBUTION','CAPITAL_RETURN') or p_input->>'actual_confirmed' is distinct from 'true' then raise exception 'Confirm actual money movement and positive finite amount.';end if;
  select id into account from public.finance_accounts where id=(p_input->>'account_id')::uuid and organization_id=org and is_active and account_type='ASSET' and account_subtype in('CASH','BANK','MOBILE_BANK') and not exists(select 1 from public.finance_cash_counters c where c.account_id=finance_accounts.id);
  select id into equity from public.finance_accounts where organization_id=org and account_subtype='OWNER_CAPITAL' and is_active;
  if account is null or equity is null then raise exception 'Choose an active main cash/bank/mobile account; counters are funded separately.';end if;
  perform 1 from public.finance_accounts where id in(account,equity) order by id for update;
  if kind='CAPITAL_RETURN' then
   select coalesce(sum(case when m.kind='CONTRIBUTION' then m.amount else -m.amount end),0) into balance from public.finance_capital_movements m where m.owner_id=owner.id;
   if amount_value>balance or amount_value>public.finance_account_balance(account,day) then raise exception 'Return cannot exceed this owner contributed capital or available funds. Profit distributions use a separate agreed workflow.';end if;
  end if;
  jid:=public.finance_post_journal(org,day,'MANUAL','OWNER_CAPITAL',rid::text,'Actual owner capital '||owner.name,actor,jsonb_build_array(jsonb_build_object('account_id',account,'debit',case when kind='CONTRIBUTION' then amount_value else 0 end,'credit',case when kind='CAPITAL_RETURN' then amount_value else 0 end),jsonb_build_object('account_id',equity,'debit',case when kind='CAPITAL_RETURN' then amount_value else 0 end,'credit',case when kind='CONTRIBUTION' then amount_value else 0 end)));
  insert into public.finance_capital_movements(id,owner_id,kind,amount,account_id,reference,journal_id,actor_id,reason) values(rid,owner.id,kind,amount_value,account,btrim(p_input->>'reference'),jid,actor,why);
  res:=jsonb_build_object('id',rid,'amount',amount_value,'kind',kind,'message','Actual capital movement posted. This is not student revenue or academy expense.');
 else raise exception 'Unknown capital action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'OWNER_CAPITAL',res->>'id',p_input->>'action',why,beforeval,to_jsonb(owner)||res,req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.owner_capital_command(jsonb) from public,anon;
grant execute on function public.owner_capital_command(jsonb) to authenticated;
create function public.owner_capital_workspace(p_page integer default 1,p_owner_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Capital management permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Invalid page.';end if;select id into org from public.organizations where code='SOHOJ' and is_active;
 return jsonb_build_object('owners',(select coalesce(jsonb_agg(to_jsonb(x) order by x.name),'[]'::jsonb) from(select o.*,coalesce((select sum(case when m.kind='CONTRIBUTION' then m.amount else -m.amount end) from public.finance_capital_movements m where m.owner_id=o.id),0) capital_balance from public.finance_owners o where o.organization_id=org order by o.name limit 200)x),
 'accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name)),'[]'::jsonb) from public.finance_accounts a where a.organization_id=org and a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK') and not exists(select 1 from public.finance_cash_counters c where c.account_id=a.id)),
 'total',(select count(*) from public.finance_capital_movements m join public.finance_owners o on o.id=m.owner_id where o.organization_id=org and (p_owner_id is null or o.id=p_owner_id)),
 'rows',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select m.*,o.name owner,a.name account,pr.display_name actor from public.finance_capital_movements m join public.finance_owners o on o.id=m.owner_id join public.finance_accounts a on a.id=m.account_id join public.profiles pr on pr.id=m.actor_id where o.organization_id=org and (p_owner_id is null or o.id=p_owner_id) order by m.created_at desc,m.id limit 25 offset (p_page-1)*25)x));
end $$;
revoke all on function public.owner_capital_workspace(integer,uuid) from public,anon;
grant execute on function public.owner_capital_workspace(integer,uuid) to authenticated;
