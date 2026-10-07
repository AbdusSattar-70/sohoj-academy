-- Isolated database test: no live accounts, emails or changes survive rollback.
begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000041','academic-reads@example.test',now());
select public.initialize_academy('academic-reads@example.test','Academic Read Administrator');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000041',true);
do $$
declare aid uuid; teacher uuid; other_teacher uuid; subject uuid; batch uuid; room uuid; result jsonb;
begin
 select id into aid from public.academies;
 insert into public.academic_rooms(academy_id,name,capacity) select aid,'Read fixture room '||n,24 from generate_series(1,31)n;
 result:=public.academic_settings_register('ROOMS',1);
 if jsonb_array_length(result->'rows')<>25 or (result->>'total')::int<>31 then raise exception 'Room settings pagination failed'; end if;
 result:=public.academic_settings_register('ROOMS',2);
 if jsonb_array_length(result->'rows')<>6 then raise exception 'Room settings second page failed'; end if;
 if exists(select 1 from jsonb_array_elements(result->'rows')r where r ? 'email' or r ? 'teacher_id') then raise exception 'Room register leaked unrelated fields'; end if;
 result:=public.academic_session_register(1);
 if result-'manage'-'sessions'-'total'<>'{}'::jsonb then raise exception 'Class register included settings payload'; end if;
 select id into subject from public.directory_entries where kind='SUBJECT' and code='ENGLISH' limit 1;
 select id into batch from public.teaching_batches where academy_id=aid limit 1;
 select id into room from public.academic_rooms where academy_id=aid limit 1;
 insert into public.people(academy_id,full_name) values(aid,'Read Teacher') returning id into teacher;
 insert into public.people(academy_id,full_name) values(aid,'Other Read Teacher') returning id into other_teacher;
 insert into public.person_responsibilities(person_id,academy_id,responsibility) values(teacher,aid,'TEACHER'),(other_teacher,aid,'TEACHER');
 insert into public.teacher_subject_qualifications(academy_id,teacher_id,subject_id) values(aid,teacher,subject),(aid,other_teacher,subject);
 insert into public.academic_sessions(academy_id,batch_id,subject_id,teacher_id,room_id,starts_at,ends_at)
 values(aid,batch,subject,teacher,room,now()+interval '1 hour',now()+interval '2 hours'),(aid,batch,subject,other_teacher,room,now()+interval '3 hours',now()+interval '4 hours');
 result:=public.academic_operation_choices('QUALIFICATIONS');
 if jsonb_array_length(result->'batches')<>0 then raise exception 'Qualification setup fetched unrelated batches'; end if;
 insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000042','academic-teacher@example.test',now());
 insert into public.account_profiles(id,academy_id,display_name) values('10000000-0000-4000-8000-000000000042',aid,'Read Teacher');
 insert into public.person_accounts(profile_id,person_id,academy_id) values('10000000-0000-4000-8000-000000000042',teacher,aid);
 insert into public.account_roles(profile_id,role_code) values('10000000-0000-4000-8000-000000000042','TEACHER');
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000042',true);
 result:=public.academic_session_register(1);
 if (result->>'manage')::boolean or (result->>'total')::int<>1 or result->'sessions'->0->>'teacher_id'<>teacher::text then raise exception 'Teacher own-session scope failed'; end if;
 begin
  perform public.academic_settings_register('CONTACTS',1);
  raise exception 'Teacher contact settings access accepted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.academic_operation_choices('SESSION');
  raise exception 'Teacher setup choices access accepted';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub','',true);
 begin
  perform public.academic_session_register(1);
  raise exception 'Anonymous class register access accepted';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
