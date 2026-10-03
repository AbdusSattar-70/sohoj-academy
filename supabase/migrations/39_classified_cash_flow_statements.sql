create table public.finance_cash_classifications(id uuid primary key default gen_random_uuid(),journal_id uuid not null references public.general_ledger_journals(id),category text not null check(category in('OPERATING','INVESTING','FINANCING','UNCLASSIFIED')),event_order bigint generated always as identity unique,actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create index cash_classification_latest on public.finance_cash_classifications(journal_id,event_order desc);
alter table public.finance_cash_classifications enable row level security;
revoke all on public.finance_cash_classifications from public,anon,authenticated;
create trigger cash_classification_immutable before update or delete on public.finance_cash_classifications for each row execute function public.prevent_permanent_record_delete();
create function public.finance_cash_default_class(p_source text,p_type text) returns text language sql immutable set search_path='' as $$
 select case when p_source='OWNER_CAPITAL' then 'FINANCING' when p_source in('ASSET_ACQUISITION','ASSET_DISPOSAL') then 'INVESTING' when p_type in('PAYMENT','REFUND','EXPENSE','COMPENSATION_SETTLEMENT') or p_source in('STAFF_PAYROLL_SETTLEMENT','SUPPLIER_REFUND') then 'OPERATING' else 'UNCLASSIFIED' end
$$;
revoke all on function public.finance_cash_default_class(text,text) from public,anon,authenticated;
create function public.cash_classification_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');key public.admission_command_keys;j public.general_ledger_journals;last_order bigint;rid uuid;res jsonb;mon date;
begin
 if actor is null or not public.has_permission('accounting.period.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Accounting management permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 or p_input->>'category' is null or p_input->>'category' not in('OPERATING','INVESTING','FINANCING','UNCLASSIFIED') then raise exception 'Select a category and record evidence.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select jj.* into j from public.general_ledger_journals jj join public.organizations o on o.id=jj.organization_id where jj.id=(p_input->>'id')::uuid and jj.status='POSTED' and o.code='SOHOJ' and o.is_active;
 if j.id is null then raise exception 'Posted journal unavailable.';end if;mon:=date_trunc('month',j.journal_date)::date;
 perform pg_advisory_xact_lock_shared(hashtextextended('finance-period:'||mon::text,37));
 if (select action from public.finance_period_events where month=mon order by event_order desc limit 1)='CLOSE' then raise exception 'Classification month is closed. Reopen before changing reporting evidence.';end if;
 perform 1 from public.general_ledger_journals where id=j.id for update;
 if coalesce((select sum(l.debit-l.credit) from public.general_ledger_lines l join public.finance_accounts a on a.id=l.account_id where l.journal_id=j.id and a.account_subtype in('CASH','BANK','MOBILE_BANK')),0)=0 then raise exception 'Noncash journals and internal cash transfers have no net cash flow to classify.';end if;
 select event_order into last_order from public.finance_cash_classifications where journal_id=j.id order by event_order desc limit 1;
 if coalesce(last_order,0) is distinct from (p_input->>'expected_order')::bigint then raise exception 'Classification changed. Review latest evidence.';end if;
 insert into public.finance_cash_classifications(journal_id,category,actor_id,reason) values(j.id,p_input->>'category',actor,why) returning id into rid;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'CASH_FLOW',j.id::text,'CLASSIFY',why,jsonb_build_object('category',p_input->>'category','evidenceId',rid),req);
 res:=jsonb_build_object('id',rid,'message','Cash-flow category saved. Ledger balances remain unchanged.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.cash_classification_command(jsonb) from public,anon;
grant execute on function public.cash_classification_command(jsonb) to authenticated;
create function public.classified_cash_flow(p_month date default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare mon date:=coalesce(p_month,date_trunc('month',now() at time zone 'Asia/Dhaka')::date);org uuid;opening numeric;closing numeric;summary jsonb;rows jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Accounting access required.';end if;
 if mon is null or extract(day from mon)<>1 or mon>date_trunc('month',now() at time zone 'Asia/Dhaka')::date or p_page is null or p_page not between 1 and 10000 then raise exception 'Choose current/past month and valid page.';end if;select id into org from public.organizations where code='SOHOJ' and is_active;
 select coalesce(sum(l.debit-l.credit) filter(where j.journal_date<mon),0),coalesce(sum(l.debit-l.credit),0) into opening,closing from public.general_ledger_lines l join public.finance_accounts a on a.id=l.account_id join public.general_ledger_journals j on j.id=l.journal_id where j.organization_id=org and j.status='POSTED' and j.journal_date<mon+interval '1 month' and a.account_subtype in('CASH','BANK','MOBILE_BANK');
 with flow as(select j.id,j.journal_no,j.journal_date,j.description,j.source_type,j.journal_type,sum(l.debit-l.credit) amount from public.general_ledger_journals j join public.general_ledger_lines l on l.journal_id=j.id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_subtype in('CASH','BANK','MOBILE_BANK') group by j.id having sum(l.debit-l.credit)<>0),
 categorized as(select f.*,coalesce(c.category,public.finance_cash_default_class(f.source_type,f.journal_type)) category from flow f left join lateral(select category from public.finance_cash_classifications where journal_id=f.id order by event_order desc limit 1)c on true)
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into summary from(select category,sum(greatest(amount,0)) inflow,sum(greatest(-amount,0)) outflow,sum(amount) net from categorized group by category)x;
 with flow as(select j.id,j.journal_no,j.journal_date,j.description,j.source_type,j.journal_type,sum(l.debit-l.credit) amount from public.general_ledger_journals j join public.general_ledger_lines l on l.journal_id=j.id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_subtype in('CASH','BANK','MOBILE_BANK') group by j.id having sum(l.debit-l.credit)<>0)
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select f.*,coalesce(c.category,public.finance_cash_default_class(f.source_type,f.journal_type)) category,coalesce(c.event_order,0) expected_order,c.reason from flow f left join lateral(select category,event_order,reason from public.finance_cash_classifications where journal_id=f.id order by event_order desc limit 1)c on true order by f.journal_date desc,f.id limit 25 offset (p_page-1)*25)x;
 select count(*) into total from(select j.id from public.general_ledger_journals j join public.general_ledger_lines l on l.journal_id=j.id join public.finance_accounts a on a.id=l.account_id where j.organization_id=org and j.status='POSTED' and j.journal_date>=mon and j.journal_date<mon+interval '1 month' and a.account_subtype in('CASH','BANK','MOBILE_BANK') group by j.id having sum(l.debit-l.credit)<>0)x;
 return jsonb_build_object('month',mon,'generatedAt',now(),'opening',opening,'closing',closing,'movement',closing-opening,'difference',closing-opening-coalesce((select sum((v->>'net')::numeric) from jsonb_array_elements(summary)v),0),'summary',summary,'rows',rows,'total',total,'canManage',public.has_permission('accounting.period.manage'));
end $$;
revoke all on function public.classified_cash_flow(date,integer) from public,anon;
grant execute on function public.classified_cash_flow(date,integer) to authenticated;
