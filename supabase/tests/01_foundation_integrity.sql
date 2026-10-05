-- Disposable fresh database only; all fixtures roll back.
begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000001','admin@example.test',now());
select public.initialize_academy('admin@example.test','Test Administrator');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
do $$
declare result jsonb; repeated jsonb; input jsonb; identity uuid; request uuid:=gen_random_uuid();
begin
 if (select count(*) from public.operating_divisions)<>3 then raise exception 'Expected three divisions'; end if;
 if (select count(*) from public.class_levels)<>15 then raise exception 'Expected Play/Nursery/KG and classes 1–12'; end if;
 if has_function_privilege('anon','public.initialize_academy(text,text)','execute') or has_function_privilege('authenticated','public.initialize_academy(text,text)','execute') then raise exception 'Bootstrap must be server-only'; end if;
 if has_table_privilege('authenticated','public.people','insert') then raise exception 'People direct writes must be revoked'; end if;
 input:=jsonb_build_object('request_id',request,'full_name','A Shared Person','mobile','01790000001','reason','Verified identity at the desk');
 result:=public.save_person(input); identity:=(result->>'id')::uuid;
 repeated:=public.save_person(input);
 if repeated<>result or (select count(*) from public.people)<>1 then raise exception 'Retry duplicated person'; end if;
 begin
  perform public.save_person(input||jsonb_build_object('full_name','Changed request'));
  raise exception 'Payload mismatch accepted';
 exception when others then if sqlerrm='Payload mismatch accepted' then raise; end if; end;
 perform public.save_person(input||jsonb_build_object('request_id',gen_random_uuid(),'full_name','A Different Family Member'));
 if (select count(*) from public.people where mobile='01790000001')<>2 then raise exception 'Shared family phone rejected'; end if;
 perform public.set_person_responsibility(jsonb_build_object('request_id',gen_random_uuid(),'person_id',identity,'revision',1,'responsibility','TEACHER','reason','Verified teaching responsibility'));
 perform public.set_person_responsibility(jsonb_build_object('request_id',gen_random_uuid(),'person_id',identity,'revision',2,'responsibility','REFERRER','reason','Verified referral responsibility'));
 if (select count(*) from public.person_responsibilities where person_id=identity)<>3 then raise exception 'Teacher/staff/referrer identity duplicated or omitted'; end if;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'kind','INSTITUTION','name','Test School','locality','Test Area','institution_type','SCHOOL','reason','Registered institution for inline choice');
 result:=public.save_directory_entry(input);
 if public.save_directory_entry(input)<>result then raise exception 'Directory retry mismatch'; end if;
 begin
  perform public.save_directory_entry(input||jsonb_build_object('request_id',gen_random_uuid(),'name','  TEST   school  '));
  raise exception 'Normalized school duplicate accepted';
 exception when unique_violation then null; end;
 result:=public.save_directory_entry(input||jsonb_build_object('request_id',gen_random_uuid(),'id',result->>'id','revision',1,'is_active',false));
 if (public.search_directory('INSTITUTION','Test School')->>'total')::integer<>0 then raise exception 'Inactive school available for new use'; end if;
 if (public.search_directory('INSTITUTION','Test School',1,true)->>'total')::integer<>1 then raise exception 'Inactive school history missing'; end if;
 begin
  perform public.save_person(jsonb_build_object('request_id',gen_random_uuid(),'id',identity,'revision',1,'full_name','Stale name','reason','Stale edit attempted'));
  raise exception 'Stale person edit accepted';
 exception when others then if sqlerrm='Stale person edit accepted' then raise; end if; end;
 if exists(select 1 from public.activity_events where action<>'BOOTSTRAP' and (actor_name is distinct from 'Test Administrator' or not actor_roles @> array['ADMIN'])) then raise exception 'Audit actor absent'; end if;
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) then raise exception 'RLS missing'; end if;
end $$;
-- Beyond the usual page boundary, totals must remain whole-register counts.
insert into public.people(academy_id,full_name) select id,'Page Person '||n from public.academies cross join generate_series(1,30)n;
do $$ declare result jsonb; begin
 result:=public.search_people('Page Person',2);
 if (result->>'total')::integer<>30 or jsonb_array_length(result->'rows')<>5 then raise exception 'Pagination total is not whole-register count'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000099',true);
do $$ begin
 begin
  perform public.search_people('');
  raise exception 'Unassigned user read contacts';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
