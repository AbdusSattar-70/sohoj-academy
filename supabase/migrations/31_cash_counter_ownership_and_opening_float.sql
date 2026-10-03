-- Serialize account balance checks with every controlled journal writer.
alter function public.finance_post_journal(uuid,date,text,text,text,text,uuid,jsonb) rename to finance_post_journal_engine;
revoke all on function public.finance_post_journal_engine(uuid,date,text,text,text,text,uuid,jsonb) from public,anon,authenticated;
create function public.finance_post_journal(p_organization_id uuid,p_journal_date date,p_journal_type text,p_source_type text,p_source_id text,p_description text,p_posted_by uuid,p_lines jsonb) returns uuid language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',p_journal_date)::date::text,37));
 perform 1 from public.finance_accounts where id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) order by id for update;
 if p_source_type<>'COUNTER_OPENING_FLOAT' and exists(select 1 from public.finance_cash_counters cc where cc.account_id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) and not exists(select 1 from public.finance_counter_shifts sh where sh.counter_id=cc.id and sh.closed_at is null and exists(select 1 from public.finance_counter_receipts cr where cr.shift_id=sh.id and cr.outcome='RECEIVED'))) then raise exception 'Open the counter duty and confirm its opening cash before posting counter transactions.';end if;
 if p_source_type<>'COUNTER_OPENING_FLOAT' and not public.has_permission('accounting.reconcile') and exists(select 1 from public.finance_cash_counters cc where cc.account_id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) and not exists(select 1 from public.finance_counter_shifts sh join public.staff st on st.id=sh.staff_id where sh.counter_id=cc.id and sh.closed_at is null and st.profile_id=auth.uid() and st.status='ACTIVE')) then raise exception 'This counter belongs to another cashier.';end if;
 return public.finance_post_journal_engine(p_organization_id,p_journal_date,p_journal_type,p_source_type,p_source_id,p_description,p_posted_by,p_lines);
end $$;
revoke all on function public.finance_post_journal(uuid,date,text,text,text,text,uuid,jsonb) from public,anon,authenticated;

create table public.finance_cash_counters(
 id uuid primary key default gen_random_uuid(),account_id uuid not null unique references public.finance_accounts(id),payment_method_id uuid not null unique references public.payment_methods(id),name text not null check(length(btrim(name)) between 3 and 120),is_active boolean not null default true,revision integer not null default 1,
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
create table public.finance_counter_shifts(
 id uuid primary key default gen_random_uuid(),counter_id uuid not null references public.finance_cash_counters(id),staff_id uuid not null references public.staff(id),work_date date not null,
 opening_balance numeric(14,2) not null check(opening_balance>=0 and opening_balance<>'NaN'::numeric),float_amount numeric(14,2) not null check(float_amount>=0 and float_amount<>'NaN'::numeric),source_account_id uuid references public.finance_accounts(id),journal_id uuid references public.general_ledger_journals(id),
 opened_by uuid not null references public.profiles(id),reason text not null,opened_at timestamptz not null default now(),closed_at timestamptz,close_id uuid unique references public.finance_daily_closes(id),closed_by uuid references public.profiles(id),
 check((closed_at is null and close_id is null and closed_by is null) or (closed_at is not null and close_id is not null and closed_by is not null))
);
create unique index counter_one_open_shift on public.finance_counter_shifts(counter_id) where closed_at is null;
create unique index staff_one_open_counter on public.finance_counter_shifts(staff_id) where closed_at is null;
create table public.finance_counter_receipts(
 id uuid primary key default gen_random_uuid(),event_order bigint generated always as identity,shift_id uuid not null references public.finance_counter_shifts(id),actor_id uuid not null references public.profiles(id),outcome text not null check(outcome in('RECEIVED','DISPUTED')),counted_amount numeric(14,2) not null check(counted_amount>=0 and counted_amount<>'NaN'::numeric),reason text not null,created_at timestamptz not null default now()
);
alter table public.finance_cash_counters enable row level security;
alter table public.finance_counter_shifts enable row level security;
alter table public.finance_counter_receipts enable row level security;
revoke all on public.finance_cash_counters,public.finance_counter_shifts,public.finance_counter_receipts from anon,authenticated;
create trigger counter_no_delete before delete on public.finance_cash_counters for each row execute function public.prevent_permanent_record_delete();
create trigger counter_shift_no_delete before delete on public.finance_counter_shifts for each row execute function public.prevent_permanent_record_delete();
create trigger counter_receipt_immutable before update or delete on public.finance_counter_receipts for each row execute function public.prevent_permanent_record_delete();

create function public.cash_counter_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('accounting.reconcile');req uuid:=(p_input->>'request_id')::uuid;k public.admission_command_keys;action text:=p_input->>'action';note text:=btrim(p_input->>'reason');c public.finance_cash_counters;s public.finance_counter_shifts;sid uuid;account public.finance_accounts;source public.finance_accounts;amount numeric:=coalesce((p_input->>'amount')::numeric,0);balance numeric;day date:=(now() at time zone 'Asia/Dhaka')::date;result jsonb;preview jsonb;close_record public.finance_daily_closes;journal uuid;rid uuid:=gen_random_uuid();receipt_outcome text:=p_input->>'outcome';
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Active counter access required.';end if;
 if req is null or coalesce(length(note),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 if amount='NaN'::numeric or amount<0 or amount<>round(amount,2) or amount>999999999999.99 then raise exception 'Enter a nonnegative amount with at most two decimals.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into k from public.admission_command_keys where request_id=req;
 if found then if k.actor_id<>actor or k.payload<>p_input then raise exception 'Request identity conflict.';end if;return k.result;end if;
 if action='RECEIVE' then
  select * into s from public.finance_counter_shifts where id=(p_input->>'shift_id')::uuid for update;
  if s.id is null or s.closed_at is not null or not exists(select 1 from public.staff where id=s.staff_id and profile_id=actor and status='ACTIVE') then raise exception 'Only the assigned active cashier can receive this open shift.';end if;
  if exists(select 1 from public.finance_counter_receipts where shift_id=s.id and outcome='RECEIVED') then raise exception 'Matching receipt already recorded.';end if;
  if receipt_outcome is null or receipt_outcome not in('RECEIVED','DISPUTED') or (receipt_outcome='RECEIVED' and amount<>s.opening_balance) then raise exception 'A different count must be recorded as Disputed.';end if;
  insert into public.finance_counter_receipts(shift_id,actor_id,outcome,counted_amount,reason) values(s.id,actor,receipt_outcome,amount,note);
  if receipt_outcome='RECEIVED' then update public.payment_methods set is_active=true where id=(select payment_method_id from public.finance_cash_counters where id=s.counter_id);end if;rid:=s.id;
 else
  if not manager then raise exception 'Reconciliation management permission required.';end if;
  perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',day)::date::text,37));
  if action='CREATE' then
   if nullif(p_input->>'account_id','') is null then
    insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,created_by) select id,'TILL-'||left(replace(rid::text,'-',''),12),btrim(p_input->>'name'),'ASSET','CASH',actor from public.organizations where code='SOHOJ' returning * into account;
   else
    select * into account from public.finance_accounts where id=(p_input->>'account_id')::uuid and is_active and account_subtype='CASH' and account_type='ASSET' and organization_id in(select id from public.organizations where code='SOHOJ') for update;
   end if;
   if account.id is null then raise exception 'Choose an active academy cash account.';end if;
   insert into public.payment_methods(id,organization_id,code,name,is_active) values(rid,account.organization_id,'COUNTER-'||left(replace(rid::text,'-',''),12),btrim(p_input->>'name'),false);
   insert into public.finance_payment_account_map(payment_method_id,account_id) values(rid,account.id);
   insert into public.finance_cash_counters(id,account_id,payment_method_id,name,created_by) values(rid,account.id,rid,btrim(p_input->>'name'),actor);
  else
   select * into c from public.finance_cash_counters where id=(p_input->>'counter_id')::uuid for update;
   if c.id is null then raise exception 'Counter unavailable.';end if;rid:=c.id;
   if action='EDIT' then
    if c.revision is distinct from (p_input->>'revision')::integer then raise exception 'Counter changed; reload before editing.';end if;
    if not coalesce((p_input->>'is_active')::boolean,true) and exists(select 1 from public.finance_counter_shifts where counter_id=c.id and closed_at is null) then raise exception 'Close the shift before inactivation.';end if;
    update public.finance_cash_counters set name=btrim(p_input->>'name'),is_active=(p_input->>'is_active')::boolean,revision=revision+1 where id=c.id;
    update public.payment_methods set name=btrim(p_input->>'name') where id=c.payment_method_id;
   elsif action='OPEN' then
    sid:=(p_input->>'staff_id')::uuid;
    if not c.is_active or not exists(select 1 from jsonb_array_elements(public.cash_handover_recipients()) r where r->>'id'=sid::text) and not exists(select 1 from public.staff where id=sid and profile_id=actor and status='ACTIVE' and public.has_permission('workforce.self.view')) then raise exception 'Choose an active account-linked cashier.';end if;
    -- Lock all funding accounts in a consistent order before reading balances.
    perform 1 from public.finance_accounts where id=c.account_id or id=nullif(p_input->>'source_account_id','')::uuid order by id for update;
    select * into account from public.finance_accounts where id=c.account_id and is_active and account_type='ASSET' and account_subtype='CASH';
    if account.id is null then raise exception 'Counter cash account inactive.';end if;
    balance:=coalesce(public.finance_account_balance(account.id,day),0);
    if balance<0 then raise exception 'Resolve the negative counter balance first.';end if;
    if amount>0 then
     select * into source from public.finance_accounts where id=(p_input->>'source_account_id')::uuid and id<>account.id and organization_id=account.organization_id and is_active and account_type='ASSET' and account_subtype in('CASH','BANK','MOBILE_BANK');
     if source.id is null or coalesce(public.finance_account_balance(source.id,day),0)<amount then raise exception 'Choose a different funded cash/bank account with enough available balance.';end if;
     if exists(select 1 from public.finance_counter_shifts sh join public.finance_cash_counters cc on cc.id=sh.counter_id where cc.account_id=source.id and sh.closed_at is null) then raise exception 'Do not fund from another open counter.';end if;
     journal:=public.finance_post_journal(account.organization_id,day,'MANUAL','COUNTER_OPENING_FLOAT',rid::text||':'||req::text,note,actor,jsonb_build_array(jsonb_build_object('account_id',account.id,'debit',amount,'credit',0),jsonb_build_object('account_id',source.id,'debit',0,'credit',amount)));
    end if;
    rid:=gen_random_uuid();insert into public.finance_counter_shifts(id,counter_id,staff_id,work_date,opening_balance,float_amount,source_account_id,journal_id,opened_by,reason) values(rid,c.id,sid,day,balance+amount,amount,source.id,journal,actor,note);
   elsif action='CLOSE' then
    select * into s from public.finance_counter_shifts where counter_id=c.id and closed_at is null for update;
    if s.id is null then raise exception 'No open counter shift.';end if;
    if not exists(select 1 from public.finance_counter_receipts where shift_id=s.id and outcome='RECEIVED') then raise exception 'A matching cashier receipt is required. Resolve any dispute using new evidence, not an overwritten receipt.';end if;
    perform 1 from public.finance_accounts where id=c.account_id for update;
    select * into close_record from public.finance_daily_closes where id=(p_input->>'close_id')::uuid and account_id=c.account_id and recorded_at>=s.opened_at and close_date=day and handed_to is null;
    preview:=public.daily_close_preview(c.account_id,day);
    if close_record.id is null or close_record.variance<>0 or close_record.ledger_token<>preview->>'token' then raise exception 'Record a fresh matching cash count today without handover before closing.';end if;
    update public.finance_counter_shifts set closed_at=now(),close_id=close_record.id,closed_by=actor where id=s.id;update public.payment_methods set is_active=false where id=c.payment_method_id;rid:=s.id;
   else raise exception 'Unknown counter action.';end if;
  end if;
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'CASH_COUNTER',rid::text,action,note,p_input,req);
 result:=jsonb_build_object('ok',true,'id',rid);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.cash_counter_command(jsonb) from public,anon;
grant execute on function public.cash_counter_command(jsonb) to authenticated;

create function public.cash_counter_workspace(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.reconcile');sid uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Counter access required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Invalid page.';end if;
 select id into sid from public.staff where profile_id=auth.uid() and status='ACTIVE';
 select count(*) into total from public.finance_cash_counters c where manager or exists(select 1 from public.finance_counter_shifts s where s.counter_id=c.id and s.staff_id=sid);
 select coalesce(jsonb_agg(to_jsonb(r) order by r.name,r.id),'[]'::jsonb) into rows from (
 select c.id,c.name,c.account_id,c.is_active,c.revision,a.name account,
 (select coalesce(jsonb_agg(to_jsonb(sh) order by sh.opened_at desc),'[]'::jsonb) from (select s.id,s.opened_at,s.work_date,s.opening_balance,s.float_amount,s.closed_at,s.staff_id,st.full_name cashier,
 (select outcome from public.finance_counter_receipts where shift_id=s.id order by event_order desc limit 1) outcome,
 (select coalesce(jsonb_agg(jsonb_build_object('outcome',outcome,'amount',counted_amount,'note',reason,'at',created_at) order by event_order),'[]'::jsonb) from public.finance_counter_receipts where shift_id=s.id) receipts,
 (s.staff_id=sid and s.closed_at is null and not exists(select 1 from public.finance_counter_receipts where shift_id=s.id and outcome='RECEIVED')) can_receive
 from public.finance_counter_shifts s join public.staff st on st.id=s.staff_id where s.counter_id=c.id and (manager or s.staff_id=sid) order by s.opened_at desc limit 10) sh) shifts,
 case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.close_no||' · '||d.close_date::text) order by d.recorded_at desc),'[]'::jsonb) from (select * from public.finance_daily_closes where account_id=c.account_id and close_date=(now() at time zone 'Asia/Dhaka')::date and handed_to is null and variance=0 order by recorded_at desc limit 10) d) else '[]'::jsonb end counts
 from public.finance_cash_counters c join public.finance_accounts a on a.id=c.account_id where manager or exists(select 1 from public.finance_counter_shifts s where s.counter_id=c.id and s.staff_id=sid) order by c.name,c.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('manager',manager,'total',total,'records',rows,
 'accounts',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'kind',a.account_subtype,'registered',exists(select 1 from public.finance_cash_counters cc where cc.account_id=a.id)) order by a.name),'[]'::jsonb) from public.finance_accounts a where a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK') and a.organization_id in(select id from public.organizations where code='SOHOJ')) else '[]'::jsonb end,
 'people',case when manager then public.cash_handover_recipients()||(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no)),'[]'::jsonb) from public.staff where profile_id=auth.uid() and status='ACTIVE' and public.has_permission('workforce.self.view')) else '[]'::jsonb end);
end $$;
revoke all on function public.cash_counter_workspace(integer) from public,anon;
grant execute on function public.cash_counter_workspace(integer) to authenticated;
