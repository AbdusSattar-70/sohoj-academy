-- A monotonic duty order remains reliable when a transaction waited for locks.
create sequence public.counter_duty_order_seq;
alter table public.finance_counter_shifts add column event_order bigint;
with ordered as(select id,row_number() over(order by opened_at,id) n from public.finance_counter_shifts) update public.finance_counter_shifts s set event_order=o.n from ordered o where o.id=s.id;
select setval('public.counter_duty_order_seq',coalesce((select max(event_order) from public.finance_counter_shifts),0)+1,false);
alter table public.finance_counter_shifts alter column event_order set default nextval('public.counter_duty_order_seq');
alter table public.finance_counter_shifts alter column event_order set not null;
create unique index counter_duty_order_unique on public.finance_counter_shifts(event_order);
create table public.finance_counter_transfers(
 id uuid primary key default gen_random_uuid(),counter_id uuid not null references public.finance_cash_counters(id),shift_id uuid not null references public.finance_counter_shifts(id),
 kind text not null check(kind in('TOPUP','RETURN')),amount numeric(14,2) not null check(amount>0 and amount<>'NaN'::numeric),
 source_account_id uuid not null references public.finance_accounts(id),destination_account_id uuid not null references public.finance_accounts(id),journal_id uuid not null unique references public.general_ledger_journals(id),close_id uuid references public.finance_daily_closes(id),
 reference text not null check(length(btrim(reference)) between 3 and 120),reason text not null check(length(btrim(reason)) between 5 and 1000),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),check(source_account_id<>destination_account_id),check((kind='TOPUP' and close_id is null) or (kind='RETURN' and close_id is not null))
);
create unique index counter_transfer_reference on public.finance_counter_transfers(counter_id,kind,lower(btrim(reference)));
create table public.finance_counter_transfer_receipts(
 id uuid primary key default gen_random_uuid(),event_order bigint generated always as identity,transfer_id uuid not null references public.finance_counter_transfers(id),actor_id uuid not null references public.profiles(id),
 outcome text not null check(outcome in('RECEIVED','DISPUTED')),counted_amount numeric(14,2) not null check(counted_amount>=0 and counted_amount<>'NaN'::numeric),reason text not null check(length(btrim(reason)) between 5 and 1000),created_at timestamptz not null default now()
);
alter table public.finance_counter_transfers enable row level security;
alter table public.finance_counter_transfer_receipts enable row level security;
revoke all on public.finance_counter_transfers,public.finance_counter_transfer_receipts from public,anon,authenticated;
create trigger counter_transfer_immutable before update or delete on public.finance_counter_transfers for each row execute function public.prevent_permanent_record_delete();
create trigger counter_transfer_receipt_immutable before update or delete on public.finance_counter_transfer_receipts for each row execute function public.prevent_permanent_record_delete();

create or replace function public.finance_post_journal(p_organization_id uuid,p_journal_date date,p_journal_type text,p_source_type text,p_source_id text,p_description text,p_posted_by uuid,p_lines jsonb) returns uuid language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',p_journal_date)::date::text,37));
 perform 1 from public.finance_accounts where id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) order by id for update;
 if p_source_type not in('COUNTER_OPENING_FLOAT','COUNTER_TRANSFER') then
  if exists(select 1 from public.finance_cash_counters cc where cc.account_id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) and not exists(select 1 from public.finance_counter_shifts sh where sh.counter_id=cc.id and sh.closed_at is null and exists(select 1 from public.finance_counter_receipts cr where cr.shift_id=sh.id and cr.outcome='RECEIVED'))) then raise exception 'Open the counter duty and confirm its opening cash before posting counter transactions.';end if;
  if exists(select 1 from public.finance_counter_transfers tr join public.finance_cash_counters cc on cc.id=tr.counter_id where cc.account_id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) and tr.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=tr.id and rr.outcome='RECEIVED')) then raise exception 'Confirm the additional cash receipt or resolve the dispute before using this counter.';end if;
  if not public.has_permission('accounting.reconcile') and exists(select 1 from public.finance_cash_counters cc where cc.account_id in(select (value->>'account_id')::uuid from jsonb_array_elements(p_lines)) and not exists(select 1 from public.finance_counter_shifts sh join public.staff st on st.id=sh.staff_id where sh.counter_id=cc.id and sh.closed_at is null and st.profile_id=auth.uid() and st.status='ACTIVE')) then raise exception 'This counter belongs to another cashier.';end if;
 end if;
 return public.finance_post_journal_engine(p_organization_id,p_journal_date,p_journal_type,p_source_type,p_source_id,p_description,p_posted_by,p_lines);
end $$;
revoke all on function public.finance_post_journal(uuid,date,text,text,text,text,uuid,jsonb) from public,anon,authenticated;

-- Keep existing operations; close/open cannot bypass a pending additional receipt.
alter function public.cash_counter_command(jsonb) rename to cash_counter_base_command;
revoke all on function public.cash_counter_base_command(jsonb) from public,anon,authenticated;
create function public.cash_counter_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_input->>'action' in('CLOSE','OPEN') then
  if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation management permission required.';end if;
  perform pg_advisory_xact_lock(hashtextextended((p_input->>'request_id'),0));
  perform 1 from public.finance_cash_counters where id=(p_input->>'counter_id')::uuid for update;
  -- Completed requests retain their original result, even after a later top-up.
  if not exists(select 1 from public.admission_command_keys where request_id=(p_input->>'request_id')::uuid and actor_id=auth.uid() and payload=p_input) and exists(select 1 from public.finance_counter_transfers tr where tr.counter_id=(p_input->>'counter_id')::uuid and tr.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=tr.id and rr.outcome='RECEIVED')) then raise exception 'Receive the pending additional cash before closing or opening a duty.';end if;
 end if;
 return public.cash_counter_base_command(p_input);
end $$;
revoke all on function public.cash_counter_command(jsonb) from public,anon;
grant execute on function public.cash_counter_command(jsonb) to authenticated;

create function public.counter_transfer_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('accounting.reconcile');req uuid:=(p_input->>'request_id')::uuid;k public.admission_command_keys;kind_value text:=p_input->>'action';note text:=btrim(p_input->>'reason');amount_value numeric:=(p_input->>'amount')::numeric;reference_value text:=btrim(p_input->>'reference');outcome_value text:=p_input->>'outcome';
 c public.finance_cash_counters;s public.finance_counter_shifts;tr public.finance_counter_transfers;a public.finance_accounts;other public.finance_accounts;count_record public.finance_daily_closes;preview jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date;rid uuid:=gen_random_uuid();jid uuid;result jsonb;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Active counter access required.';end if;
 if req is null or coalesce(length(note),0) not between 5 and 1000 or amount_value is null or amount_value='NaN'::numeric or amount_value<0 or amount_value<>round(amount_value,2) or amount_value>999999999999.99 then raise exception 'Enter a request identity, valid amount and explanation.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into k from public.admission_command_keys where request_id=req;
 if found then if k.actor_id<>actor or k.payload<>p_input then raise exception 'Request identity conflict.';end if;return k.result;end if;
 if kind_value='RECEIVE' then
  select * into tr from public.finance_counter_transfers where id=(p_input->>'transfer_id')::uuid;
  perform 1 from public.finance_cash_counters where id=tr.counter_id for update;
  select * into tr from public.finance_counter_transfers where id=tr.id for update;
  select * into s from public.finance_counter_shifts where id=tr.shift_id for update;
  if tr.id is null or tr.kind<>'TOPUP' or s.closed_at is not null or not exists(select 1 from public.staff st where st.id=s.staff_id and st.profile_id=actor and st.status='ACTIVE') then raise exception 'Only the assigned active cashier may receive this top-up.';end if;
  if exists(select 1 from public.finance_counter_transfer_receipts where transfer_id=tr.id and outcome='RECEIVED') then raise exception 'Additional cash already received.';end if;
  if outcome_value is null or outcome_value not in('RECEIVED','DISPUTED') or (outcome_value='RECEIVED' and amount_value<>tr.amount) then raise exception 'A different amount must be recorded as Disputed.';end if;
  select * into c from public.finance_cash_counters where id=tr.counter_id;
  perform 1 from public.finance_accounts where id=c.account_id for update;
  insert into public.finance_counter_transfer_receipts(transfer_id,actor_id,outcome,counted_amount,reason) values(tr.id,actor,outcome_value,amount_value,note);
  if outcome_value='RECEIVED' and not exists(select 1 from public.finance_counter_transfers x where x.counter_id=c.id and x.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=x.id and rr.outcome='RECEIVED')) then update public.payment_methods set is_active=true where id=c.payment_method_id;end if;
  rid:=tr.id;
 else
  if not manager or kind_value not in('TOPUP','RETURN') then raise exception 'Reconciliation management permission required.';end if;
  if (p_input->>'actual_confirmed')::boolean is distinct from true then raise exception 'Confirm that the physical transfer or deposit actually happened.';end if;
  if amount_value<=0 or coalesce(length(reference_value),0) not between 3 and 120 then raise exception 'Enter a positive transfer and receipt/deposit reference.';end if;
  perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||date_trunc('month',day)::date::text,37));
  select * into c from public.finance_cash_counters where id=(p_input->>'counter_id')::uuid for update;
  if c.id is null then raise exception 'Counter unavailable.';end if;
  select * into s from public.finance_counter_shifts where counter_id=c.id order by event_order desc limit 1 for update;
  if s.id is null then raise exception 'This counter has no duty history.';end if;
  if exists(select 1 from public.finance_counter_transfers x where x.counter_id=c.id and x.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=x.id and rr.outcome='RECEIVED')) then raise exception 'Receive or resolve the pending top-up first.';end if;
  perform 1 from public.finance_accounts where id=c.account_id or id=(p_input->>'other_account_id')::uuid order by id for update;
  select * into a from public.finance_accounts where id=c.account_id and is_active and account_type='ASSET' and account_subtype='CASH';
  select * into other from public.finance_accounts where id=(p_input->>'other_account_id')::uuid and id<>c.account_id and is_active and account_type='ASSET' and account_subtype in('CASH','BANK','MOBILE_BANK') and organization_id=a.organization_id and not exists(select 1 from public.finance_cash_counters cc where cc.account_id=finance_accounts.id);
  if a.id is null or other.id is null then raise exception 'Choose a different active main cash/bank account, not another counter.';end if;
  if kind_value='TOPUP' then
   if not c.is_active or s.closed_at is not null or not exists(select 1 from public.finance_counter_receipts where shift_id=s.id and outcome='RECEIVED') or not exists(select 1 from public.staff st join public.profiles p on p.id=st.profile_id where st.id=s.staff_id and st.status='ACTIVE' and p.status='ACTIVE') then raise exception 'An open, received duty with an active linked cashier is required.';end if;
   if coalesce(public.finance_account_balance(other.id,day),0)<amount_value then raise exception 'Insufficient source balance.';end if;
   jid:=public.finance_post_journal(a.organization_id,day,'MANUAL','COUNTER_TRANSFER',rid::text,note,actor,jsonb_build_array(jsonb_build_object('account_id',a.id,'debit',amount_value,'credit',0),jsonb_build_object('account_id',other.id,'debit',0,'credit',amount_value)));
   insert into public.finance_counter_transfers(id,counter_id,shift_id,kind,amount,source_account_id,destination_account_id,journal_id,reference,reason,actor_id) values(rid,c.id,s.id,kind_value,amount_value,other.id,a.id,jid,reference_value,note,actor);
   update public.payment_methods set is_active=false where id=c.payment_method_id;
  else
   if s.closed_at is null then raise exception 'Close and reconcile the duty before returning cash.';end if;
   select * into count_record from public.finance_daily_closes where id=(p_input->>'close_id')::uuid and account_id=c.account_id and close_date=day and recorded_at>=s.opened_at and handed_to is null and variance=0;
   preview:=public.daily_close_preview(c.account_id,day);
   if count_record.id is null or count_record.ledger_token<>preview->>'token' then raise exception 'Record a fresh matching cash count before returning cash.';end if;
   if coalesce(public.finance_account_balance(a.id,day),0)<amount_value then raise exception 'Return cannot exceed the current counter balance.';end if;
   jid:=public.finance_post_journal(a.organization_id,day,'MANUAL','COUNTER_TRANSFER',rid::text,note,actor,jsonb_build_array(jsonb_build_object('account_id',other.id,'debit',amount_value,'credit',0),jsonb_build_object('account_id',a.id,'debit',0,'credit',amount_value)));
   insert into public.finance_counter_transfers(id,counter_id,shift_id,kind,amount,source_account_id,destination_account_id,journal_id,close_id,reference,reason,actor_id) values(rid,c.id,s.id,kind_value,amount_value,a.id,other.id,jid,count_record.id,reference_value,note,actor);
  end if;
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'COUNTER_TRANSFER',rid::text,case when kind_value='RECEIVE' then outcome_value else kind_value end,note,p_input,req);
 result:=jsonb_build_object('ok',true,'id',rid);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.counter_transfer_command(jsonb) from public,anon;
grant execute on function public.counter_transfer_command(jsonb) to authenticated;

create or replace function public.cash_counter_workspace(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.reconcile');sid uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Counter access required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Invalid page.';end if;
 select id into sid from public.staff where profile_id=auth.uid() and status='ACTIVE';
 select count(*) into total from public.finance_cash_counters c where manager or exists(select 1 from public.finance_counter_shifts s where s.counter_id=c.id and s.staff_id=sid);
 select coalesce(jsonb_agg(to_jsonb(r) order by r.name,r.id),'[]'::jsonb) into rows from (
 select c.id,c.name,c.account_id,c.is_active,c.revision,a.name account,
 (select coalesce(jsonb_agg(to_jsonb(sh) order by sh.event_order desc),'[]'::jsonb) from (select s.id,s.event_order,s.opened_at,s.work_date,s.opening_balance,s.float_amount,s.closed_at,s.staff_id,st.full_name cashier,
 (select outcome from public.finance_counter_receipts where shift_id=s.id order by event_order desc limit 1) outcome,
 (select coalesce(jsonb_agg(jsonb_build_object('outcome',outcome,'amount',counted_amount,'note',reason,'at',created_at) order by event_order),'[]'::jsonb) from public.finance_counter_receipts where shift_id=s.id) receipts,
 (s.staff_id=sid and s.closed_at is null and not exists(select 1 from public.finance_counter_receipts where shift_id=s.id and outcome='RECEIVED')) can_receive
 from public.finance_counter_shifts s join public.staff st on st.id=s.staff_id where s.counter_id=c.id and (manager or s.staff_id=sid) order by s.event_order desc limit 10) sh) shifts,
 case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.close_no||' · '||d.close_date::text) order by d.recorded_at desc),'[]'::jsonb) from (select * from public.finance_daily_closes where account_id=c.account_id and close_date=(now() at time zone 'Asia/Dhaka')::date and handed_to is null and variance=0 order by recorded_at desc limit 10) d) else '[]'::jsonb end counts
 from public.finance_cash_counters c join public.finance_accounts a on a.id=c.account_id where manager or exists(select 1 from public.finance_counter_shifts s where s.counter_id=c.id and s.staff_id=sid) order by c.name,c.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('manager',manager,'total',total,'records',rows,
 'accounts',case when manager then (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'kind',a.account_subtype,'registered',exists(select 1 from public.finance_cash_counters cc where cc.account_id=a.id)) order by a.name),'[]'::jsonb) from public.finance_accounts a where a.is_active and a.account_subtype in('CASH','BANK','MOBILE_BANK') and a.organization_id in(select id from public.organizations where code='SOHOJ')) else '[]'::jsonb end,
 'people',case when manager then public.cash_handover_recipients()||(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no)),'[]'::jsonb) from public.staff where profile_id=auth.uid() and status='ACTIVE' and public.has_permission('workforce.self.view')) else '[]'::jsonb end);
end $$;
revoke all on function public.cash_counter_workspace(integer) from public,anon;
grant execute on function public.cash_counter_workspace(integer) to authenticated;

create function public.counter_transfer_workspace(p_page integer default 1,p_counter_ids uuid[] default '{}',p_pending boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.reconcile');sid uuid;rows jsonb;total integer;balances jsonb;pending_ids jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Counter access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or coalesce(cardinality(p_counter_ids),0)>25 then raise exception 'Invalid page or counter selection.';end if;
 select id into sid from public.staff where profile_id=auth.uid() and status='ACTIVE';
 select count(*) into total from public.finance_counter_transfers tr join public.finance_counter_shifts sh on sh.id=tr.shift_id where (manager or sh.staff_id=sid) and (not coalesce(p_pending,false) or (tr.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=tr.id and rr.outcome='RECEIVED')));
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) into rows from (
 select tr.id,tr.counter_id,cc.name counter,tr.kind,tr.amount,tr.reference,tr.reason,tr.created_at,sh.staff_id,st.full_name cashier,src.name source,dst.name destination,pr.display_name actor,
 case when tr.kind='RETURN' then 'RETURNED' else coalesce((select outcome from public.finance_counter_transfer_receipts where transfer_id=tr.id order by event_order desc limit 1),'PENDING') end outcome,
 (tr.kind='TOPUP' and sh.staff_id=sid and sh.closed_at is null and not exists(select 1 from public.finance_counter_transfer_receipts where transfer_id=tr.id and outcome='RECEIVED')) can_receive,
 (select coalesce(jsonb_agg(jsonb_build_object('outcome',outcome,'amount',counted_amount,'note',reason,'at',created_at) order by event_order),'[]'::jsonb) from public.finance_counter_transfer_receipts where transfer_id=tr.id) receipts
 from public.finance_counter_transfers tr join public.finance_cash_counters cc on cc.id=tr.counter_id join public.finance_counter_shifts sh on sh.id=tr.shift_id join public.staff st on st.id=sh.staff_id join public.finance_accounts src on src.id=tr.source_account_id join public.finance_accounts dst on dst.id=tr.destination_account_id join public.profiles pr on pr.id=tr.actor_id where (manager or sh.staff_id=sid) and (not coalesce(p_pending,false) or (tr.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts rr where rr.transfer_id=tr.id and rr.outcome='RECEIVED'))) order by tr.created_at desc,tr.id limit 25 offset (p_page-1)*25) r;
 select coalesce(jsonb_agg(jsonb_build_object('id',cc.id,'amount',coalesce(public.finance_account_balance(cc.account_id,(now() at time zone 'Asia/Dhaka')::date),0))),'[]'::jsonb) into balances from public.finance_cash_counters cc where manager and cc.id=any(p_counter_ids);
 select coalesce(jsonb_agg(distinct tr.counter_id),'[]'::jsonb) into pending_ids from public.finance_counter_transfers tr join public.finance_counter_shifts sh on sh.id=tr.shift_id where tr.counter_id=any(p_counter_ids) and (manager or sh.staff_id=sid) and tr.kind='TOPUP' and not exists(select 1 from public.finance_counter_transfer_receipts where transfer_id=tr.id and outcome='RECEIVED');
 return jsonb_build_object('records',rows,'total',total,'balances',balances,'pendingCounterIds',pending_ids);
end $$;
revoke all on function public.counter_transfer_workspace(integer,uuid[],boolean) from public,anon;
grant execute on function public.counter_transfer_workspace(integer,uuid[],boolean) to authenticated;
