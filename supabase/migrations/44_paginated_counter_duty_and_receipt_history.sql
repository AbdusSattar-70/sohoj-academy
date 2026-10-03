create index counter_history_page on public.finance_counter_shifts(counter_id,event_order desc);
create index counter_own_history_page on public.finance_counter_shifts(counter_id,staff_id,event_order desc);
create index counter_receipt_history_page on public.finance_counter_receipts(shift_id,event_order desc);
create function public.cash_counter_history(p_counter uuid,p_page integer default 1,p_from date default null,p_through date default null,p_shift uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.reconcile');sid uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Counter access required.';end if;
 if p_counter is null or p_page is null or p_page not between 1 and 10000 or p_from>p_through then raise exception 'Choose a valid counter, page and date range.';end if;
 select id into sid from public.staff where profile_id=auth.uid() and status='ACTIVE';
 if not exists(select 1 from public.finance_cash_counters c join public.finance_accounts a on a.id=c.account_id join public.organizations o on o.id=a.organization_id where c.id=p_counter and o.code='SOHOJ' and (manager or exists(select 1 from public.finance_counter_shifts s where s.counter_id=c.id and s.staff_id=sid))) then raise exception 'Counter history unavailable.';end if;
 if p_shift is not null then
  if not exists(select 1 from public.finance_counter_shifts s where s.id=p_shift and s.counter_id=p_counter and (manager or s.staff_id=sid)) then raise exception 'Duty receipt history unavailable.';end if;
  select count(*) into total from public.finance_counter_receipts where shift_id=p_shift;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select r.id,r.event_order,r.outcome,r.counted_amount,r.reason,r.created_at,p.display_name actor from public.finance_counter_receipts r join public.profiles p on p.id=r.actor_id where r.shift_id=p_shift order by r.event_order desc limit 25 offset (p_page-1)*25)x;
  return jsonb_build_object('mode','RECEIPTS','total',total,'rows',rows);
 end if;
 select count(*) into total from public.finance_counter_shifts s where s.counter_id=p_counter and (manager or s.staff_id=sid) and (p_from is null or s.work_date>=p_from) and (p_through is null or s.work_date<=p_through);
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select s.id,s.work_date,s.opened_at,s.closed_at,s.opening_balance,s.float_amount,s.reason,st.staff_no,st.full_name cashier,p.display_name opened_by,cp.display_name closed_by,d.close_no,d.actual close_amount,d.variance,(select count(*) from public.finance_counter_receipts where shift_id=s.id) receipt_count,(select outcome from public.finance_counter_receipts where shift_id=s.id order by event_order desc limit 1) receipt_outcome from public.finance_counter_shifts s join public.staff st on st.id=s.staff_id join public.profiles p on p.id=s.opened_by left join public.profiles cp on cp.id=s.closed_by left join public.finance_daily_closes d on d.id=s.close_id where s.counter_id=p_counter and (manager or s.staff_id=sid) and (p_from is null or s.work_date>=p_from) and (p_through is null or s.work_date<=p_through) order by s.event_order desc limit 25 offset (p_page-1)*25)x;
 return jsonb_build_object('mode','DUTIES','total',total,'rows',rows);
end $$;
revoke all on function public.cash_counter_history(uuid,integer,date,date,uuid) from public,anon;
grant execute on function public.cash_counter_history(uuid,integer,date,date,uuid) to authenticated;

-- Bound nested evidence in the operational snapshot; full history uses the paginated RPC.
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
 (select coalesce(jsonb_agg(jsonb_build_object('outcome',outcome,'amount',counted_amount,'note',reason,'at',created_at) order by event_order),'[]'::jsonb) from (select * from public.finance_counter_receipts where shift_id=s.id order by event_order desc limit 25) latest_receipts) receipts,
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
