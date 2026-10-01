create sequence public.daily_close_no_seq;
create table public.finance_daily_closes(
 id uuid primary key default gen_random_uuid(),close_no text not null unique default ('CLS-'||lpad(nextval('public.daily_close_no_seq')::text,6,'0')),
 account_id uuid not null references public.finance_accounts(id),close_date date not null,opening numeric(14,2) not null,receipts numeric(14,2) not null,payments numeric(14,2) not null,
 expected numeric(14,2) not null,actual numeric(14,2) not null,variance numeric(14,2) not null,ledger_token text not null,denominations jsonb,
 statement_reference text not null,explanation text not null,handed_to uuid references public.staff(id),recorded_by uuid not null references public.profiles(id),recorded_at timestamptz not null default now(),
 check(expected=opening+receipts-payments),check(variance=actual-expected)
);
create index finance_daily_close_lookup on public.finance_daily_closes(close_date desc,account_id,recorded_at desc);
create table public.finance_close_resolutions(
 id uuid primary key default gen_random_uuid(),event_order bigint generated always as identity,ledger_token text not null,close_id uuid not null references public.finance_daily_closes(id),action text not null check(action in('NOTE','RESOLVE','REOPEN')),
 reason text not null check(length(btrim(reason))>=5),journal_id uuid references public.general_ledger_journals(id),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
alter table public.finance_daily_closes enable row level security;
alter table public.finance_close_resolutions enable row level security;
create policy daily_close_read on public.finance_daily_closes for select to authenticated using(public.has_permission('accounting.reconcile'));
create policy close_resolution_read on public.finance_close_resolutions for select to authenticated using(public.has_permission('accounting.reconcile'));
grant select on public.finance_daily_closes,public.finance_close_resolutions to authenticated;
revoke insert,update,delete on public.finance_daily_closes,public.finance_close_resolutions from authenticated,anon;
create trigger daily_close_immutable before update or delete on public.finance_daily_closes for each row execute function public.prevent_permanent_record_delete();
create trigger close_resolution_immutable before update or delete on public.finance_close_resolutions for each row execute function public.prevent_permanent_record_delete();

create function public.daily_close_preview(p_account_id uuid,p_date date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare account public.finance_accounts;opening numeric;receipts numeric;payments numeric;token text;
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if p_date is null or p_date>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Choose today or a previous close date.';end if;
 select * into account from public.finance_accounts where id=p_account_id and account_subtype in('CASH','BANK','MOBILE_BANK');if account.id is null then raise exception 'Choose an active cash, bank or mobile account.';end if;
 select coalesce(sum(l.debit-l.credit) filter(where j.journal_date<p_date),0),coalesce(sum(l.debit) filter(where j.journal_date=p_date),0),coalesce(sum(l.credit) filter(where j.journal_date=p_date),0),md5(count(*)::text||':'||coalesce(sum(l.debit),0)::text||':'||coalesce(sum(l.credit),0)::text)
 into opening,receipts,payments,token from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where l.account_id=account.id and j.status='POSTED' and j.journal_date<=p_date;
 return jsonb_build_object('accountId',account.id,'name',account.name,'subtype',account.account_subtype,'date',p_date,'opening',opening,'receipts',receipts,'payments',payments,'expected',opening+receipts-payments,'token',token);
end $$;
revoke all on function public.daily_close_preview(uuid,date) from public,anon;
grant execute on function public.daily_close_preview(uuid,date) to authenticated;

create function public.daily_close_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();request uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;preview jsonb;record public.finance_daily_closes;reason text:=btrim(p_input->>'reason');action text:=p_input->>'action';actual numeric;item jsonb;counted numeric:=0;result jsonb;receiver uuid:=nullif(p_input->>'handed_to','')::uuid;
begin
 if actor is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if request is null or coalesce(length(reason),0)<5 then raise exception 'Request identity and explanation are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(request::text,0));select * into key from public.admission_command_keys where request_id=request;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if action='COUNT' then
  perform 1 from public.finance_accounts where id=(p_input->>'account_id')::uuid and is_active for update;
  if not found then raise exception 'Choose an active cash or statement account.';end if;
  preview:=public.daily_close_preview((p_input->>'account_id')::uuid,(p_input->>'date')::date);
  if preview->>'token' is distinct from p_input->>'preview_token' then raise exception 'The ledger changed. Review a fresh balance before closing.';end if;
  if coalesce(length(btrim(p_input->>'statement_reference')),0)<3 then raise exception 'Record the cash count or bank statement reference.';end if;
  actual:=(p_input->>'actual')::numeric;
  if actual is null or actual<>round(actual,2) then raise exception 'Enter an actual balance with at most two decimal places.';end if;
  if preview->>'subtype'='CASH' then
   if actual<0 or jsonb_typeof(p_input->'denominations')<>'array' or jsonb_array_length(p_input->'denominations')<>10 then raise exception 'Complete the physical cash denomination count.';end if;
   if (select count(distinct (value->>'value')::numeric) from jsonb_array_elements(p_input->'denominations'))<>10 then raise exception 'Each cash denomination must appear once.';end if;
   for item in select value from jsonb_array_elements(p_input->'denominations') loop
    if (item->>'value')::numeric not in(1000,500,200,100,50,20,10,5,2,1) or (item->>'count')::numeric<0 or (item->>'count')::numeric<>trunc((item->>'count')::numeric) or item->>'count' is null then raise exception 'Cash denomination counts must be nonnegative whole numbers.';end if;
    counted:=counted+(item->>'value')::numeric*(item->>'count')::numeric;
   end loop;
   if counted<>actual then raise exception 'Physical denomination total does not match the actual cash balance.';end if;
  end if;
  if receiver is not null and not exists(select 1 from public.staff where id=receiver and status='ACTIVE') then raise exception 'Choose an active handover recipient.';end if;
  if actual<>(preview->>'expected')::numeric and coalesce(length(btrim(p_input->>'variance_note')),0)<10 then raise exception 'Explain the cash or statement difference before recording it.';end if;
  insert into public.finance_daily_closes(account_id,close_date,opening,receipts,payments,expected,actual,variance,ledger_token,denominations,statement_reference,explanation,handed_to,recorded_by)
  values((p_input->>'account_id')::uuid,(p_input->>'date')::date,(preview->>'opening')::numeric,(preview->>'receipts')::numeric,(preview->>'payments')::numeric,(preview->>'expected')::numeric,actual,actual-(preview->>'expected')::numeric,preview->>'token',case when preview->>'subtype'='CASH' then p_input->'denominations' else null end,p_input->>'statement_reference',reason||case when actual<>(preview->>'expected')::numeric then ' · Variance: '||(p_input->>'variance_note') else '' end,receiver,actor) returning * into record;
 elsif action in('NOTE','RESOLVE','REOPEN') then
  select * into record from public.finance_daily_closes where id=(p_input->>'id')::uuid for update;if record.id is null then raise exception 'Close record unavailable.';end if;
  if nullif(p_input->>'journal_id','') is not null and not exists(select 1 from public.general_ledger_journals j join public.general_ledger_lines l on l.journal_id=j.id where j.id=(p_input->>'journal_id')::uuid and l.account_id=record.account_id and j.status='POSTED') then raise exception 'Choose posted correction evidence for this account.';end if;
  preview:=public.daily_close_preview(record.account_id,record.close_date);
  if action='RESOLVE' then
   if not(record.variance=0 and preview->>'token'=record.ledger_token) and not exists(select 1 from public.finance_daily_closes c where c.account_id=record.account_id and c.close_date=record.close_date and substring(c.close_no from 5)::bigint>substring(record.close_no from 5)::bigint and c.variance=0 and c.ledger_token=preview->>'token') then raise exception 'Record a fresh matching physical count or statement before resolution. Original evidence stays intact.';end if;
  end if;
  insert into public.finance_close_resolutions(close_id,action,reason,journal_id,actor_id,ledger_token) values(record.id,action,reason,nullif(p_input->>'journal_id','')::uuid,actor,preview->>'token');
 else raise exception 'Unknown close action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'DAILY_FINANCE_CLOSE',record.id::text,action,reason,to_jsonb(record),request);
 result:=jsonb_build_object('id',record.id,'ok',true);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(request,actor,p_input,result);return result;
end $$;
revoke all on function public.daily_close_command(jsonb) from public,anon;
grant execute on function public.daily_close_command(jsonb) to authenticated;

create function public.daily_close_workspace(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Invalid page.';end if;
 select count(*) into total from public.finance_daily_closes;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.recorded_at desc,r.id),'[]'::jsonb) into rows from(select c.*,a.name,public.daily_close_preview(c.account_id,c.close_date)->>'token'<>c.ledger_token stale,
 coalesce((select ledger_token is distinct from public.daily_close_preview(c.account_id,c.close_date)->>'token' from public.finance_close_resolutions where close_id=c.id and action in('RESOLVE','REOPEN') and action='RESOLVE' order by event_order desc limit 1),false) resolution_stale,
 coalesce((select action from public.finance_close_resolutions where close_id=c.id and action in('RESOLVE','REOPEN') order by event_order desc limit 1),'') resolution,
 (select coalesce(jsonb_agg(jsonb_build_object('action',action,'reason',reason,'date',created_at,'journalId',journal_id) order by created_at),'[]'::jsonb) from public.finance_close_resolutions where close_id=c.id) notes,
 (select full_name from public.staff where id=c.handed_to) receiver,
 (select display_name from public.profiles where id=c.recorded_by) actor
 from public.finance_daily_closes c join public.finance_accounts a on a.id=c.account_id order by c.recorded_at desc,c.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('total',total,'records',rows,
 'people',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no) order by full_name),'[]'::jsonb) from public.staff where status='ACTIVE'),
 'accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'subtype',account_subtype) order by code),'[]'::jsonb) from public.finance_accounts where is_active and account_subtype in('CASH','BANK','MOBILE_BANK')));
end $$;
revoke all on function public.daily_close_workspace(integer) from public,anon;
grant execute on function public.daily_close_workspace(integer) to authenticated;
