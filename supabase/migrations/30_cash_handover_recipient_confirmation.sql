-- Receipt is independent evidence; it never changes the recorded close or ledger.
create table public.finance_handover_receipts (
 close_id uuid primary key references public.finance_daily_closes(id),
 recipient_id uuid not null references public.staff(id),
 actor_id uuid not null references public.profiles(id),
 outcome text not null check(outcome in ('RECEIVED','DISPUTED')),
 counted_amount numeric(14,2) not null check(counted_amount>=0 and counted_amount<>'NaN'::numeric),
 reason text not null check(length(btrim(reason)) between 5 and 1000),
 created_at timestamptz not null default now()
);
alter table public.finance_handover_receipts enable row level security;
create policy handover_receipt_read on public.finance_handover_receipts for select to authenticated using (
 exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') and
 (public.has_permission('accounting.reconcile') or (public.has_permission('workforce.self.view') and exists(select 1 from public.staff s where s.id=recipient_id and s.profile_id=auth.uid() and s.status='ACTIVE')))
);
grant select on public.finance_handover_receipts to authenticated;
revoke insert,update,delete on public.finance_handover_receipts from authenticated,anon;
create trigger handover_receipt_immutable before update or delete on public.finance_handover_receipts for each row execute function public.prevent_permanent_record_delete();

create function public.cash_handover_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); req uuid:=(p_input->>'request_id')::uuid; prior public.admission_command_keys; c public.finance_daily_closes; amount numeric:=(p_input->>'counted_amount')::numeric; outcome text:=p_input->>'outcome'; note text:=btrim(p_input->>'reason'); result jsonb;
begin
 if actor is null or not public.has_permission('workforce.self.view') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Active staff access required.';end if;
 if req is null or coalesce(length(note),0) not between 5 and 1000 then raise exception 'Request identity and receipt note required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into prior from public.admission_command_keys where request_id=req;
 if found then if prior.actor_id<>actor or prior.payload<>p_input then raise exception 'Request identity conflict.';end if;return prior.result;end if;
 select * into c from public.finance_daily_closes where id=(p_input->>'close_id')::uuid for update;
 if c.id is null or not exists(select 1 from public.staff s where s.id=c.handed_to and s.profile_id=actor and s.status='ACTIVE') then raise exception 'Only the designated active recipient can confirm this handover.';end if;
 if not exists(select 1 from public.finance_accounts a where a.id=c.account_id and a.account_subtype='CASH') then raise exception 'Physical cash handovers only.';end if;
 if c.recorded_by=actor then raise exception 'The sender cannot confirm their own handover.';end if;
 if exists(select 1 from public.finance_handover_receipts where close_id=c.id) then raise exception 'Receipt already recorded. Preserve this evidence; record a new handover for a correction.';end if;
 if amount is null or amount='NaN'::numeric or amount<0 or amount<>round(amount,2) or amount>999999999999.99 then raise exception 'Enter a nonnegative cash count with at most two decimal places.';end if;
 if outcome is null or outcome not in('RECEIVED','DISPUTED') then raise exception 'Select receipt or dispute.';end if;
 if outcome='RECEIVED' and amount<>c.actual then raise exception 'A different amount must be recorded as a dispute.';end if;
 insert into public.finance_handover_receipts(close_id,recipient_id,actor_id,outcome,counted_amount,reason) values(c.id,c.handed_to,actor,outcome,amount,note);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'CASH_HANDOVER',c.id::text,outcome,note,jsonb_build_object('recipientId',c.handed_to,'senderAmount',c.actual,'countedAmount',amount),req);
 result:=jsonb_build_object('ok',true,'id',c.id);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.cash_handover_command(jsonb) from public,anon;
grant execute on function public.cash_handover_command(jsonb) to authenticated;

create function public.cash_handover_workspace(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.reconcile'); sid uuid; rows jsonb; total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Handover access required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Invalid page.';end if;
 select id into sid from public.staff where profile_id=auth.uid() and status='ACTIVE';
 select count(*) into total from public.finance_daily_closes c join public.finance_accounts a on a.id=c.account_id where a.account_subtype='CASH' and c.handed_to is not null and (manager or c.handed_to=sid);
 select coalesce(jsonb_agg(to_jsonb(r) order by r.recorded_at desc,r.id),'[]'::jsonb) into rows from (
 select c.id,c.close_no,c.close_date,c.recorded_at,a.name account,c.actual amount,p.display_name sender,s.full_name recipient,h.outcome,h.counted_amount,h.reason,h.created_at received_at,
 (h.close_id is null and c.handed_to=sid and c.recorded_by<>auth.uid()) can_confirm
 from public.finance_daily_closes c join public.finance_accounts a on a.id=c.account_id join public.staff s on s.id=c.handed_to join public.profiles p on p.id=c.recorded_by left join public.finance_handover_receipts h on h.close_id=c.id
 where a.account_subtype='CASH' and (manager or c.handed_to=sid) order by c.recorded_at desc,c.id limit 25 offset (p_page-1)*25) r;
 return jsonb_build_object('total',total,'records',rows);
end $$;
revoke all on function public.cash_handover_workspace(integer) from public,anon;
grant execute on function public.cash_handover_workspace(integer) to authenticated;

-- Offer only recipients who can actually acknowledge; no self-confirmation.
create function public.cash_handover_recipients() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.has_permission('accounting.reconcile') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Reconciliation permission required.';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name||' · '||s.staff_no) order by s.full_name,s.id),'[]'::jsonb) from public.staff s join public.profiles p on p.id=s.profile_id where s.status='ACTIVE' and p.status='ACTIVE' and p.id<>auth.uid() and exists(select 1 from public.user_role_assignments ra join public.system_roles sr on sr.id=ra.role_id join public.role_permissions rp on rp.role_id=ra.role_id join public.permissions pe on pe.id=rp.permission_id where ra.profile_id=p.id and ra.is_active and sr.is_active and ra.effective_from<=current_date and (ra.effective_to is null or ra.effective_to>=current_date) and pe.code='workforce.self.view'));
end $$;
revoke all on function public.cash_handover_recipients() from public,anon;
grant execute on function public.cash_handover_recipients() to authenticated;
