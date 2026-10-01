begin;
insert into auth.users(id,email,email_confirmed_at) values('95000000-0000-0000-0000-000000000001','audit-page-admin@example.test',now());
select public.bootstrap_admin('audit-page-admin@example.test','Audit Page Admin');
select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',true);
insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason)
select auth.uid(),'STAFF','pagination-fixture-'||n,'CORRECT_DETAILS','Pagination verification' from generate_series(1,55) n;
do $test$ declare first_page jsonb;second_page jsonb;last_page jsonb;begin
 first_page:=public.audit_event_page('{"q":"pagination-fixture"}');second_page:=public.audit_event_page('{"q":"pagination-fixture","page":2}');last_page:=public.audit_event_page('{"q":"pagination-fixture","page":3}');
 if (first_page->>'total')::integer<>55 or jsonb_array_length(first_page->'rows')<>25 or jsonb_array_length(last_page->'rows')<>5 then raise exception 'Audit pagination count or bounds failed';end if;
 if exists(select 1 from jsonb_array_elements(first_page->'rows') a join jsonb_array_elements(second_page->'rows') b on a->>'id'=b->>'id') then raise exception 'Audit pages overlap';end if;
 if exists(select 1 from jsonb_array_elements(first_page->'rows') r where r ? 'correlation_id' or r ? 'metadata' or r ? 'before_data') then raise exception 'Unrequested internal payload exposed';end if;
 if (public.audit_event_page('{"q":"pagination-fixture","entity":"ADMISSION"}')->>'total')::integer<>0 then raise exception 'Record filter failed';end if;
 if jsonb_array_length(public.audit_event_page('{"q":"Audit Page Admin"}')->'rows')=0 then raise exception 'Person search failed';end if;
 begin perform public.audit_event_page('{"from":"2026-10-02","to":"2026-10-01"}');raise exception 'Invalid range accepted';exception when others then if sqlerrm='Invalid range accepted' then raise;end if;end;
end $test$;
insert into auth.users(id,email) values('95000000-0000-0000-0000-000000000002','audit-only@example.test');
insert into public.system_roles(code,name) values('AUDIT_FIXTURE','Audit viewer');
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code='AUDIT_FIXTURE' and p.code='audit.view';
insert into public.user_role_assignments(profile_id,role_id,effective_from,assigned_by) select '95000000-0000-0000-0000-000000000002',id,current_date,auth.uid() from public.system_roles where code='AUDIT_FIXTURE';
select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $test$ declare a jsonb;begin a:=public.audit_event_page()->'activity';if a->>'invoices' is not null or a->>'collected' is not null or a->>'admissions' is not null then raise exception 'Audit-only role sees protected operational totals';end if;end $test$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $test$ begin begin perform public.audit_event_page();raise exception 'Anonymous audit read accepted';exception when others then if sqlerrm='Anonymous audit read accepted' then raise;end if;end;end $test$;
rollback;
