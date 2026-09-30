-- Capture identity at event creation. Historic audit rows remain untouched.
create or replace function public.capture_audit_actor()
returns trigger language plpgsql security definer set search_path=public as $$
declare person public.staff; name text; roles text; trace text;
begin
 if new.actor_profile_id is null and exists(select 1 from public.profiles where id=auth.uid()) then new.actor_profile_id:=auth.uid(); end if;
 if new.actor_profile_id is not null then
  select * into person from public.staff where profile_id=new.actor_profile_id;
  new.actor_staff_id:=coalesce(new.actor_staff_id,person.id);
  select display_name into name from public.profiles where id=new.actor_profile_id;
  select string_agg(distinct r.code,', ' order by r.code) into roles from public.user_role_assignments a join public.system_roles r on r.id=a.role_id
   where a.profile_id=new.actor_profile_id and a.is_active and r.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date);
  new.actor_role_code:=coalesce(new.actor_role_code,roles,'AUTHENTICATED');
  new.metadata:=new.metadata||jsonb_build_object('actor_name',coalesce(person.full_name,name),'actor_staff_no',person.staff_no,'actor_roles',new.actor_role_code);
 end if;
 trace:=nullif(current_setting('sohoj.workflow_trace',true),'');
 if trace is not null then new.correlation_id:=trace::uuid; end if;
 return new;
end $$;
create trigger capture_audit_identity before insert on public.audit_events for each row execute function public.capture_audit_actor();

alter function public.admission_command(jsonb) rename to admission_command_without_trace;
revoke all on function public.admission_command_without_trace(jsonb) from public,anon,authenticated;
create or replace function public.admission_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare previous text:=current_setting('sohoj.workflow_trace',true); result jsonb;
begin
 if nullif(previous,'') is null then perform set_config('sohoj.workflow_trace',coalesce(p_input->>'request_id',gen_random_uuid()::text),true); end if;
 result:=public.admission_command_without_trace(p_input);
 perform set_config('sohoj.workflow_trace',coalesce(previous,''),true);
 return result;
end $$;
revoke all on function public.admission_command(jsonb) from public,anon;
grant execute on function public.admission_command(jsonb) to authenticated;

create or replace function public.audit_event_list(p_correlation uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('audit.view') then raise exception 'Audit permission required.'; end if;
 return coalesce((select jsonb_agg(row_data order by occurred_at desc,id desc) from (
 select e.id,e.occurred_at,to_jsonb(e)||jsonb_build_object(
 'actor_name',coalesce(e.metadata->>'actor_name',s.full_name,p.display_name),
 'actor_staff_no',coalesce(e.metadata->>'actor_staff_no',s.staff_no),
 'actor_role_code',coalesce(e.actor_role_code,(select string_agg(distinct r.code,', ' order by r.code) from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id=e.actor_profile_id and a.effective_from<=e.occurred_at::date and (a.effective_to is null or a.effective_to>=e.occurred_at::date))),
 'identity_snapshot',e.metadata ? 'actor_name') as row_data
 from public.audit_events e left join public.profiles p on p.id=e.actor_profile_id
 left join public.staff s on s.id=e.actor_staff_id or (e.actor_staff_id is null and s.profile_id=e.actor_profile_id)
 where p_correlation is null or e.correlation_id=p_correlation order by e.occurred_at desc,e.id desc limit 250
 ) rows),'[]'::jsonb);
end $$;
revoke all on function public.audit_event_list(uuid) from public,anon;
grant execute on function public.audit_event_list(uuid) to authenticated;
