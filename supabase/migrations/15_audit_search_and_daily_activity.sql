-- Bounded audit search. Correlation and change payloads remain immutable internally.
create function public.audit_event_page(p_filters jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare page_no integer:=greatest(1,least(coalesce((p_filters->>'page')::integer,1),100000)); page_size integer:=25;
 q text:=left(btrim(coalesce(p_filters->>'q','')),160); entity text:=left(coalesce(p_filters->>'entity',''),80); action_value text:=left(coalesce(p_filters->>'action',''),80);
 from_day date:=nullif(p_filters->>'from','')::date; to_day date:=nullif(p_filters->>'to','')::date;
 day_start timestamptz:=(now() at time zone 'Asia/Dhaka')::date::timestamp at time zone 'Asia/Dhaka'; total_rows bigint; rows jsonb; activity jsonb;
begin
 if auth.uid() is null or not public.has_permission('audit.view') then raise exception 'Audit permission required.';end if;
 if from_day is not null and to_day is not null and from_day>to_day then raise exception 'Start date must be on or before end date.';end if;
 with matched as (
 select e.id,e.occurred_at,e.action,e.entity_type,e.entity_id,e.reason,e.actor_profile_id,
 coalesce(e.metadata->>'actor_name',s.full_name,p.display_name) actor_name,
 coalesce(e.metadata->>'actor_staff_no',s.staff_no) actor_staff_no,
 coalesce(e.actor_role_code,(select string_agg(distinct r.code,', ' order by r.code) from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id=e.actor_profile_id and a.effective_from<=e.occurred_at::date and (a.effective_to is null or a.effective_to>=e.occurred_at::date))) actor_role_code
 from public.audit_events e left join public.profiles p on p.id=e.actor_profile_id
 left join public.staff s on s.id=e.actor_staff_id or (e.actor_staff_id is null and s.profile_id=e.actor_profile_id)
 where (entity='' or e.entity_type=entity) and (action_value='' or e.action=action_value)
 and (from_day is null or e.occurred_at>=from_day::timestamp at time zone 'Asia/Dhaka')
 and (to_day is null or e.occurred_at<(to_day+1)::timestamp at time zone 'Asia/Dhaka')
 and (coalesce(p_filters->>'preset','')<>'invoices' or (e.entity_type='ADMISSION' and e.action='BILL') or (e.entity_type='FINANCE_WORKFLOW' and e.action='RUN_BILLING'))
 and (q='' or position(lower(q) in lower(concat_ws(' ',coalesce(e.metadata->>'actor_name',s.full_name,p.display_name),coalesce(e.metadata->>'actor_staff_no',s.staff_no),e.actor_profile_id::text,e.actor_role_code,replace(e.action,'_',' '),e.action,e.entity_type,e.entity_id,e.reason)))>0)
 ), paged as (select * from matched order by occurred_at desc,id desc limit page_size offset (page_no-1)*page_size)
 select (select count(*) from matched),coalesce((select jsonb_agg(to_jsonb(paged) order by occurred_at desc,id desc) from paged),'[]'::jsonb) into total_rows,rows;
 activity:=jsonb_build_object('date',(now() at time zone 'Asia/Dhaka')::date,
 'admissions',case when public.has_permission('admissions.view') then (select count(distinct entity_id) from public.audit_events where entity_type='ADMISSION' and action='FINALIZE' and occurred_at>=day_start and occurred_at<day_start+interval '1 day') else null end,
 'invoices',case when public.has_permission('finance.view') then (select count(*) from public.admission_invoices where posted_at>=day_start and posted_at<day_start+interval '1 day') else null end,
 'grossIssued',case when public.has_permission('finance.view') then (select coalesce(sum(total),0) from public.admission_invoices where posted_at>=day_start and posted_at<day_start+interval '1 day') else null end,
 'collected',case when public.has_permission('finance.view') then (select coalesce(sum(amount),0) from public.admission_payments where posted_at>=day_start and posted_at<day_start+interval '1 day') else null end,
 'refunds',case when public.has_permission('finance.view') then (select coalesce(sum(a.amount),0) from public.refund_payouts r join public.refund_authorizations a on a.id=r.authorization_id where r.posted_at>=day_start and r.posted_at<day_start+interval '1 day') else null end);
 return jsonb_build_object('rows',rows,'total',total_rows,'page',page_no,'pageSize',page_size,'activity',activity);
end $$;
revoke all on function public.audit_event_page(jsonb) from public,anon;
grant execute on function public.audit_event_page(jsonb) to authenticated;
create index if not exists audit_events_entity_action_time on public.audit_events(entity_type,action,occurred_at desc,id desc);
create index if not exists audit_events_time_id on public.audit_events(occurred_at desc,id desc);

create index if not exists admission_invoices_posted_time on public.admission_invoices(posted_at);
create index if not exists admission_payments_posted_time on public.admission_payments(posted_at);
