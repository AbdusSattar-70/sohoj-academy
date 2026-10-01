begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('98000000-0000-0000-0000-000000000001','usability-admin@example.test',now(),'{"full_name":"Usability Admin"}');
select public.bootstrap_admin('usability-admin@example.test','Usability Admin');
select set_config('request.jwt.claim.sub','98000000-0000-0000-0000-000000000001',true);
do $test$
declare result jsonb; prospect uuid; responsible uuid; event uuid; old_name text; old_rule uuid; saved uuid;
begin
 select id,full_name into responsible,old_name from public.staff where profile_id=auth.uid();
 result:=public.submit_public_interest('{"student_name":"Assignment test","guardian_name":"Test guardian","mobile":"01712345999","consent_to_contact":true}');
 prospect:=(result->>'prospect_id')::uuid;
 perform public.assign_prospect_staff(jsonb_build_object('prospect_id',prospect,'staff_id',responsible,'reason','Assign counselling responsibility'));
 if (select assigned_to_staff_id from public.prospects where id=prospect) is distinct from responsible then raise exception 'CRM assignment failed.'; end if;
 select id into event from public.audit_events where entity_id=prospect::text and action='ASSIGN_FOLLOWUP_STAFF';
 if (select metadata->>'actor_name' from public.audit_events where id=event) is distinct from old_name then raise exception 'Actor name was not captured.'; end if;
 update public.staff set full_name='Changed current staff name' where id=responsible;
 if (select metadata->>'actor_name' from public.audit_events where id=event) is distinct from old_name then raise exception 'Old actor snapshot must not follow later edits.'; end if;
 if not exists(select 1 from jsonb_array_elements(public.audit_event_list()) e where e->>'id'=event::text and e->>'actor_role_code' like '%ADMIN%') then raise exception 'Audit trace must resolve administrator identity.'; end if;
 perform public.assign_prospect_staff(jsonb_build_object('prospect_id',prospect,'staff_id','','reason','Return to shared counselling queue'));
 if (select assigned_to_staff_id from public.prospects where id=prospect) is not null then raise exception 'Unassignment failed.'; end if;
 select id into old_rule from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
 update public.business_rule_versions set status='RETIRED',effective_to=current_date where id=old_rule;
 result:=public.publish_business_rule_version('academics','batch_capacity_policy','{"max_students":12}','Create missing operational settings');
 saved:=(result->>'id')::uuid;
 if saved is null or saved=old_rule then raise exception 'Missing rule creation failed.'; end if;
 perform public.publish_business_rule_version('academics','batch_capacity_policy','{"max_students":10}','Adjust capacity for a smaller group');
 if (select payload->>'max_students' from public.business_rule_versions where id=saved)<>'12' then raise exception 'Historical operating values were modified.'; end if;
 if (select count(*) from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE')<>1 then raise exception 'Only one current capacity policy is allowed.'; end if;
end $test$;
select set_config('request.jwt.claim.sub','',true);
do $test$
begin
 begin perform public.audit_event_list();raise exception 'Anonymous audit access allowed';exception when others then if sqlerrm='Anonymous audit access allowed' then raise;end if;end;
 begin perform public.assign_prospect_staff('{"prospect_id":"98000000-0000-0000-0000-000000000001","staff_id":"","reason":"Attempt anonymous assignment"}');raise exception 'Anonymous assignment allowed';exception when others then if sqlerrm='Anonymous assignment allowed' then raise;end if;end;
end $test$;
rollback;
