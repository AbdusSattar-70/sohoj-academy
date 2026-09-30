-- Save current operating settings; retain prior snapshots for historical cases.
create or replace function public.publish_business_rule_version(p_domain text,p_rule_key text,p_payload jsonb,p_reason text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare previous public.business_rule_versions; saved public.business_rule_versions; next_version integer; trace uuid:=gen_random_uuid();
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Settings management permission required.'; end if;
 if (p_domain,p_rule_key) not in (('academics','batch_capacity_policy'),('admissions','activation_policy'),('teacher_compensation','default_policy')) then raise exception 'Choose a supported operating rule.'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 5 and 500 or not public.validate_business_rule_payload(p_domain,p_rule_key,p_payload) then raise exception 'Check the operating values and change reason.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_domain||'.'||p_rule_key,0));
 select * into previous from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key and status='ACTIVE' for update;
 if previous.id is not null and previous.payload=p_payload then return jsonb_build_object('id',previous.id,'version',previous.version); end if;
 select coalesce(max(version),0)+1 into next_version from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key;
 update public.business_rule_versions set status='RETIRED',effective_to=current_date where id=previous.id;
 insert into public.business_rule_versions(domain,rule_key,version,status,effective_from,payload,change_reason,created_by)
 values(p_domain,p_rule_key,next_version,'ACTIVE',current_date,p_payload,btrim(p_reason),auth.uid()) returning * into saved;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(trace,auth.uid(),'BUSINESS_RULE',p_domain||'.'||p_rule_key,case when previous.id is null then 'CREATE_SETTINGS' else 'SAVE_SETTINGS' end,p_reason,to_jsonb(previous),to_jsonb(saved));
 return jsonb_build_object('id',saved.id,'version',saved.version,'correlation_id',trace);
end $$;
revoke all on function public.publish_business_rule_version(text,text,jsonb,text) from public,anon;
grant execute on function public.publish_business_rule_version(text,text,jsonb,text) to authenticated;
