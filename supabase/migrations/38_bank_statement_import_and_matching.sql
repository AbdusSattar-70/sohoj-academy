create table public.finance_bank_imports(id uuid primary key default gen_random_uuid(),account_id uuid not null references public.finance_accounts(id),statement_reference text not null check(length(btrim(statement_reference)) between 3 and 200),actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create table public.finance_bank_transactions(id uuid primary key default gen_random_uuid(),import_id uuid not null references public.finance_bank_imports(id),account_id uuid not null references public.finance_accounts(id),transaction_date date not null,reference text not null check(length(btrim(reference)) between 3 and 200),description text not null default '',amount numeric(14,2) not null check(amount<>0 and amount<>'NaN'::numeric));
create unique index bank_transaction_ref on public.finance_bank_transactions(account_id,lower(btrim(reference)));
create table public.finance_bank_links(id uuid primary key default gen_random_uuid(),transaction_id uuid not null references public.finance_bank_transactions(id),line_id uuid not null references public.general_ledger_lines(id),actor_id uuid not null references public.profiles(id),reason text not null,matched_at timestamptz not null default now(),released_at timestamptz,released_by uuid references public.profiles(id),release_reason text);
create unique index bank_line_matched_once on public.finance_bank_links(line_id) where released_at is null;
create unique index bank_pair_matched_once on public.finance_bank_links(transaction_id,line_id) where released_at is null;
alter table public.finance_bank_imports enable row level security;alter table public.finance_bank_transactions enable row level security;alter table public.finance_bank_links enable row level security;
revoke all on public.finance_bank_imports,public.finance_bank_transactions,public.finance_bank_links from public,anon,authenticated;
create trigger bank_import_immutable before update or delete on public.finance_bank_imports for each row execute function public.prevent_permanent_record_delete();
create trigger bank_transaction_immutable before update or delete on public.finance_bank_transactions for each row execute function public.prevent_permanent_record_delete();
create trigger bank_link_no_delete before delete on public.finance_bank_links for each row execute function public.prevent_permanent_record_delete();
create function public.bank_reconciliation_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');key public.admission_command_keys;org uuid;account uuid;rid uuid:=gen_random_uuid();res jsonb;r jsonb;amount_value numeric;day date;tx public.finance_bank_transactions;lines uuid[];matched numeric;action text:=p_input->>'action';count_lines integer;
begin
 if actor is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 if action='IMPORT' then
  select id into account from public.finance_accounts where id=(p_input->>'account_id')::uuid and organization_id=org and is_active and account_type='ASSET' and account_subtype in('BANK','MOBILE_BANK') for update;
  if account is null or p_input->>'verified_statement' is distinct from 'true' or coalesce(length(btrim(p_input->>'statement_reference')),0) not between 3 and 200 or jsonb_typeof(p_input->'rows') is distinct from 'array' or jsonb_array_length(p_input->'rows') not between 1 and 250 then raise exception 'Choose bank/mobile account, verified statement and 1–250 transactions.';end if;
  insert into public.finance_bank_imports(id,account_id,statement_reference,actor_id,reason) values(rid,account,btrim(p_input->>'statement_reference'),actor,why);
  for r in select value from jsonb_array_elements(p_input->'rows') loop
   day:=(r->>'date')::date;amount_value:=(r->>'amount')::numeric;
   if day is null or day>(now() at time zone 'Asia/Dhaka')::date or amount_value is null or amount_value=0 or amount_value='NaN'::numeric or amount_value<>round(amount_value,2) or coalesce(length(btrim(r->>'reference')),0) not between 3 and 200 or length(coalesce(r->>'description',''))>500 then raise exception 'Check transaction date, unique bank reference and signed finite amount.';end if;
   insert into public.finance_bank_transactions(import_id,account_id,transaction_date,reference,description,amount) values(rid,account,day,btrim(r->>'reference'),coalesce(r->>'description',''),amount_value);
  end loop;
 elsif action in('MATCH','UNMATCH') then
  select t.* into tx from public.finance_bank_transactions t join public.finance_accounts a on a.id=t.account_id where t.id=(p_input->>'id')::uuid and a.organization_id=org for update of t;if tx.id is null then raise exception 'Bank transaction unavailable.';end if;rid:=tx.id;
  if action='MATCH' then
   if exists(select 1 from public.finance_bank_links where transaction_id=tx.id and released_at is null) then raise exception 'Transaction is already matched. Review or release the match first.';end if;
   if jsonb_typeof(p_input->'line_ids') is distinct from 'array' or jsonb_array_length(p_input->'line_ids') not between 1 and 10 then raise exception 'Select one to ten posted cash movement lines.';end if;
   select array_agg(value::uuid) into lines from jsonb_array_elements_text(p_input->'line_ids');
   if cardinality(lines)<>(select count(distinct x) from unnest(lines)x) then raise exception 'Each selected ledger line must appear once.';end if;
   perform 1 from public.general_ledger_lines where id=any(lines) order by id for update;
   select count(*),sum(l.debit-l.credit) into count_lines,matched from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where l.id=any(lines) and l.account_id=tx.account_id and j.status='POSTED' and j.organization_id=org;
   if count_lines<>cardinality(lines) or matched<>tx.amount then raise exception 'Selected account movements must exactly match the statement amount and direction.';end if;
   if exists(select 1 from public.finance_bank_links where line_id=any(lines) and released_at is null) then raise exception 'A ledger line is already matched to another bank transaction.';end if;
   insert into public.finance_bank_links(transaction_id,line_id,actor_id,reason) select tx.id,x,actor,why from unnest(lines)x;
  else
   if not exists(select 1 from public.finance_bank_links where transaction_id=tx.id and released_at is null) then raise exception 'No current match to release.';end if;
   update public.finance_bank_links set released_at=now(),released_by=actor,release_reason=why where transaction_id=tx.id and released_at is null;
  end if;
 else raise exception 'Unknown reconciliation action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'BANK_RECONCILIATION',rid::text,action,why,jsonb_build_object('lineIds',lines,'matchedAmount',matched,'accountId',coalesce(account,tx.account_id)),req);
 res:=jsonb_build_object('id',rid,'message','Statement evidence saved. Ledger balances were not changed.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.bank_reconciliation_command(jsonb) from public,anon;
grant execute on function public.bank_reconciliation_command(jsonb) to authenticated;
create function public.bank_reconciliation_workspace(p_account_id uuid default null,p_page integer default 1,p_search text default '',p_unmatched boolean default true) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_search is null or length(p_search)>100 then raise exception 'Invalid reconciliation filters.';end if;select id into org from public.organizations where code='SOHOJ' and is_active;
 return jsonb_build_object('accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)),'[]'::jsonb) from public.finance_accounts where organization_id=org and account_subtype in('BANK','MOBILE_BANK')),
 'total',(select count(*) from public.finance_bank_transactions t join public.finance_accounts a on a.id=t.account_id where a.organization_id=org and (p_account_id is null or t.account_id=p_account_id) and (not p_unmatched or not exists(select 1 from public.finance_bank_links where transaction_id=t.id and released_at is null)) and (p_search='' or t.reference ilike '%'||p_search||'%' or t.description ilike '%'||p_search||'%')),
 'rows',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select t.*,a.name account,exists(select 1 from public.finance_bank_links where transaction_id=t.id and released_at is null) matched,(select coalesce(jsonb_agg(jsonb_build_object('journal',j.journal_no,'date',j.journal_date,'amount',l.debit-l.credit,'matched_at',bl.matched_at,'reason',bl.reason,'released_at',bl.released_at,'release_reason',bl.release_reason) order by bl.matched_at,bl.id),'[]'::jsonb) from (select * from public.finance_bank_links where transaction_id=t.id order by matched_at desc,id limit 20)bl join public.general_ledger_lines l on l.id=bl.line_id join public.general_ledger_journals j on j.id=l.journal_id where bl.transaction_id=t.id) history from public.finance_bank_transactions t join public.finance_accounts a on a.id=t.account_id where a.organization_id=org and (p_account_id is null or t.account_id=p_account_id) and (not p_unmatched or not exists(select 1 from public.finance_bank_links where transaction_id=t.id and released_at is null)) and (p_search='' or t.reference ilike '%'||p_search||'%' or t.description ilike '%'||p_search||'%') order by t.transaction_date desc,t.id limit 25 offset (p_page-1)*25)x));
end $$;
revoke all on function public.bank_reconciliation_workspace(uuid,integer,text,boolean) from public,anon;
grant execute on function public.bank_reconciliation_workspace(uuid,integer,text,boolean) to authenticated;
create function public.bank_match_candidates(p_id uuid,p_page integer default 1,p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare tx public.finance_bank_transactions;org uuid;
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_search is null or length(p_search)>100 then raise exception 'Invalid ledger filters.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;select t.* into tx from public.finance_bank_transactions t join public.finance_accounts a on a.id=t.account_id where t.id=p_id and a.organization_id=org;if tx.id is null then raise exception 'Transaction unavailable.';end if;
 return jsonb_build_object('total',(select count(*) from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where l.account_id=tx.account_id and j.status='POSTED' and sign(l.debit-l.credit)=sign(tx.amount) and not exists(select 1 from public.finance_bank_links where line_id=l.id and released_at is null) and (p_search='' or j.journal_no ilike '%'||p_search||'%' or j.description ilike '%'||p_search||'%')),
 'rows',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select l.id,j.journal_no,j.journal_date,j.description,l.debit-l.credit amount from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where l.account_id=tx.account_id and j.status='POSTED' and sign(l.debit-l.credit)=sign(tx.amount) and not exists(select 1 from public.finance_bank_links where line_id=l.id and released_at is null) and (p_search='' or j.journal_no ilike '%'||p_search||'%' or j.description ilike '%'||p_search||'%') order by abs(j.journal_date-tx.transaction_date),j.journal_date desc,l.id limit 25 offset (p_page-1)*25)x));
end $$;
revoke all on function public.bank_match_candidates(uuid,integer,text) from public,anon;
grant execute on function public.bank_match_candidates(uuid,integer,text) to authenticated;
