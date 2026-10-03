create table public.finance_collection_promises(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.admission_invoices(id),amount numeric(12,2) not null check(amount>0 and amount<>'NaN'::numeric),due_on date not null,baseline_net_paid numeric(12,2) not null,status text not null default 'OPEN' check(status in('OPEN','COMPLETED','CANCELLED')),revision integer not null default 1,reason text not null,actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
create unique index one_open_collection_promise on public.finance_collection_promises(invoice_id) where status='OPEN';
create table public.finance_collection_events(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.admission_invoices(id),promise_id uuid references public.finance_collection_promises(id),action text not null,reason text not null,actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
alter table public.finance_collection_promises enable row level security;
alter table public.finance_collection_events enable row level security;
revoke all on public.finance_collection_promises,public.finance_collection_events from public,anon,authenticated;
create trigger collection_promise_no_delete before delete on public.finance_collection_promises for each row execute function public.prevent_permanent_record_delete();
create trigger collection_event_immutable before update or delete on public.finance_collection_events for each row execute function public.prevent_permanent_record_delete();
create function public.collection_followup_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;why text:=btrim(p_input->>'reason');key public.admission_command_keys;i public.admission_invoices;b record;p public.finance_collection_promises;amt numeric;res jsonb;action text:=p_input->>'action';day date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 if actor is null or not public.has_permission('finance.payments.post') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Collection management access required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 select * into i from public.admission_invoices where id=(p_input->>'invoice_id')::uuid for update;if not found then raise exception 'Invoice unavailable.';end if;
 if not exists(select 1 from public.students s join public.organizations o on o.id=s.organization_id where s.id=i.student_id and o.code='SOHOJ' and o.is_active) then raise exception 'Invoice outside academy scope.';end if;
 select * into b from public.invoice_balance(i.id);
 if action='PROMISE' then
  amt:=(p_input->>'amount')::numeric;
  if amt is null or amt<=0 or amt='NaN'::numeric or amt<>round(amt,2) or amt>b.due or (p_input->>'due_on')::date is null or (p_input->>'due_on')::date<day then raise exception 'Promise must fit current due and have a current/future due date.';end if;
  insert into public.finance_collection_promises(invoice_id,amount,due_on,baseline_net_paid,reason,actor_id) values(i.id,amt,(p_input->>'due_on')::date,b.paid-b.refunded,why,actor) returning * into p;
 elsif action in('COMPLETE','CANCEL') then
  select * into p from public.finance_collection_promises where id=(p_input->>'id')::uuid and invoice_id=i.id for update;
  if p.id is null or p.status<>'OPEN' or p.revision is distinct from (p_input->>'revision')::int then raise exception 'Refresh the current open promise.';end if;
  if action='COMPLETE' and b.paid-b.refunded-p.baseline_net_paid<p.amount then raise exception 'Actual net collection does not fulfil this promise. A waiver is not money received.';end if;
  update public.finance_collection_promises set status=case when action='COMPLETE' then 'COMPLETED' else 'CANCELLED' end,revision=revision+1 where id=p.id;
 elsif action<>'CONTACT' or action is null then raise exception 'Unknown collection action.';end if;
 insert into public.finance_collection_events(invoice_id,promise_id,action,reason,actor_id) values(i.id,p.id,action,why,actor);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,correlation_id,after_data) values(actor,'COLLECTION_FOLLOWUP',i.id::text,action,why,req,jsonb_build_object('promiseId',p.id,'due',b.due));
 res:=jsonb_build_object('id',coalesce(p.id,i.id),'message','Collection evidence saved. No payment or discount was invented.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.collection_followup_command(jsonb) from public,anon;
grant execute on function public.collection_followup_command(jsonb) to authenticated;
create view public.finance_receivable_rows as
 select i.id,i.invoice_no,i.student_id,i.admission_id,i.issued_on,i.due_on,s.student_no,s.full_name,
 b.gross,b.credits,b.net,b.paid,b.refunded,b.due,
 greatest((now() at time zone 'Asia/Dhaka')::date-i.due_on,0) age_days,
 case when i.due_on>=(now() at time zone 'Asia/Dhaka')::date then 'NOT_DUE' when (now() at time zone 'Asia/Dhaka')::date-i.due_on<=30 then '1_30' when (now() at time zone 'Asia/Dhaka')::date-i.due_on<=60 then '31_60' when (now() at time zone 'Asia/Dhaka')::date-i.due_on<=90 then '61_90' else '90_PLUS' end bucket,
 a.identity_snapshot->>'guardian_name' guardian,a.identity_snapshot->>'mobile' mobile,
 pr.id promise_id,pr.amount promise_amount,pr.due_on promise_due,pr.revision promise_revision,greatest(b.paid-b.refunded-pr.baseline_net_paid,0) promise_collected,
 (select max(created_at) from public.finance_collection_events e where e.invoice_id=i.id and e.action='CONTACT') last_contact
 from public.admission_invoices i join public.students s on s.id=i.student_id join public.organizations o on o.id=s.organization_id and o.code='SOHOJ' and o.is_active join public.admission_cases a on a.id=i.admission_id cross join lateral public.invoice_balance(i.id)b left join public.finance_collection_promises pr on pr.invoice_id=i.id and pr.status='OPEN';
revoke all on public.finance_receivable_rows from public,anon,authenticated;
create function public.receivable_workspace(p_page integer default 1,p_search text default '',p_bucket text default 'ALL',p_promises boolean default false,p_student_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;summary jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('finance.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Finance access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_search is null or length(p_search)>100 or p_bucket is null or p_bucket not in('ALL','NOT_DUE','1_30','31_60','61_90','90_PLUS') then raise exception 'Invalid receivable filters.';end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select * from public.finance_receivable_rows r where (r.due>0 or p_student_id is not null) and (p_student_id is null or r.student_id=p_student_id) and (p_bucket='ALL' or r.bucket=p_bucket) and (not p_promises or (r.promise_due<=(now() at time zone 'Asia/Dhaka')::date)) and (p_search='' or r.full_name ilike '%'||p_search||'%' or r.student_no ilike '%'||p_search||'%' or r.invoice_no ilike '%'||p_search||'%' or r.mobile ilike '%'||p_search||'%') order by r.due_on,r.id limit 25 offset (p_page-1)*25)x;
 select count(*) into total from public.finance_receivable_rows r where (r.due>0 or p_student_id is not null) and (p_student_id is null or r.student_id=p_student_id) and (p_bucket='ALL' or r.bucket=p_bucket) and (not p_promises or r.promise_due<=(now() at time zone 'Asia/Dhaka')::date) and (p_search='' or r.full_name ilike '%'||p_search||'%' or r.student_no ilike '%'||p_search||'%' or r.invoice_no ilike '%'||p_search||'%' or r.mobile ilike '%'||p_search||'%');
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into summary from(select bucket,sum(due) amount from public.finance_receivable_rows r where r.due>0 and (p_student_id is null or r.student_id=p_student_id) group by bucket)x;
 return jsonb_build_object('today',(now() at time zone 'Asia/Dhaka')::date,'rows',rows,'total',total,'summary',summary,'canManage',public.has_permission('finance.payments.post'));
end $$;
revoke all on function public.receivable_workspace(integer,text,text,boolean,uuid) from public,anon;
grant execute on function public.receivable_workspace(integer,text,text,boolean,uuid) to authenticated;
