create or replace function public.prospect_assignment_options()
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('crm.prospects.view') then raise exception 'CRM access required.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no) order by full_name) from public.staff where status in('ACTIVE','ON_LEAVE')),'[]'::jsonb);
end $$;
create or replace function public.assign_prospect_staff(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.prospects; chosen uuid:=nullif(p_input->>'staff_id','')::uuid;
begin
 if auth.uid() is null or not public.has_permission('crm.prospects.manage') then raise exception 'CRM management permission required.'; end if;
 if length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Assignment reason required.'; end if;
 if chosen is not null and not exists(select 1 from public.staff where id=chosen and status in('ACTIVE','ON_LEAVE')) then raise exception 'Choose an active staff member.'; end if;
 select * into p from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
 if p.id is null then raise exception 'Prospect not found.'; end if;
 if chosen is not distinct from p.assigned_to_staff_id then return jsonb_build_object('id',p.id); end if;
 update public.prospects set assigned_to_staff_id=chosen where id=p.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'PROSPECT',p.id::text,'ASSIGN_FOLLOWUP_STAFF',p_input->>'reason',jsonb_build_object('staff_id',p.assigned_to_staff_id),jsonb_build_object('staff_id',chosen));
 return jsonb_build_object('id',p.id);
end $$;
revoke all on function public.prospect_assignment_options() from public,anon;
revoke all on function public.assign_prospect_staff(jsonb) from public,anon;
grant execute on function public.prospect_assignment_options(),public.assign_prospect_staff(jsonb) to authenticated;

-- The staff member handling conversion takes responsibility when none was assigned.
alter function public.create_prospect_admission(jsonb) rename to create_prospect_admission_without_assignment;
revoke all on function public.create_prospect_admission_without_assignment(jsonb) from public,anon,authenticated;
create or replace function public.create_prospect_admission(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; chosen uuid; changed uuid;
begin
 result:=public.create_prospect_admission_without_assignment(p_input);
 select id into chosen from public.staff where profile_id=auth.uid() and status in('ACTIVE','ON_LEAVE');
 if chosen is not null then
 update public.prospects set assigned_to_staff_id=chosen where id=(p_input->>'prospect_id')::uuid and assigned_to_staff_id is null returning id into changed;
 if changed is not null then
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values((p_input->>'request_id')::uuid,auth.uid(),'PROSPECT',changed::text,'ASSIGN_FOLLOWUP_STAFF','Staff handled verified admission conversion',jsonb_build_object('staff_id',chosen));
 end if; end if;
 return result;
end $$;
revoke all on function public.create_prospect_admission(jsonb) from public,anon;
grant execute on function public.create_prospect_admission(jsonb) to authenticated;
