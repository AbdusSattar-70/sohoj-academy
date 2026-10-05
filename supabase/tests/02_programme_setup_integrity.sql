begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000002','catalogue@example.test',now());
select public.initialize_academy('catalogue@example.test','Catalogue Administrator');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$
declare academy uuid; school uuid; coaching uuid; training uuid; campus uuid; type_id uuid; subject_id uuid; yr uuid;
 programme uuid; run uuid; batch uuid; person uuid; input jsonb; result jsonb; req uuid;
begin
 select id into academy from public.academies;
 select id into school from public.operating_divisions where code='SCHOOL';
 select id into coaching from public.operating_divisions where code='COACHING';
 select id into training from public.operating_divisions where code='TRAINING';
 select id into campus from public.campuses;
 select id into type_id from public.directory_entries where kind='PROGRAMME_TYPE' and code='TRAINING';
 select id into subject_id from public.directory_entries where kind='SUBJECT' and code='ENGLISH';
 result:=public.save_programme(jsonb_build_object('request_id',gen_random_uuid(),'name','Teacher Job Preparation','programme_type_id',type_id,'reason','Prepare a new training programme'));
 programme:=(result->>'id')::uuid;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'programme_id',programme,'division_id',training,'campus_id',campus,'starts_on','2026-01-01','ends_on','2026-12-31','subject_ids',jsonb_build_array(subject_id),'reason','Prepare current adult training course');
 result:=public.save_programme_run(input); run:=(result->>'id')::uuid;
 if result->>'title'<>'Teacher Job Preparation' or result->>'class_code' is not null then raise exception 'Adult training incorrectly requires school class/title'; end if;
 if public.save_programme_run(input)<>result then raise exception 'Programme retry changed result'; end if;
 begin
  perform public.save_programme_run(input||jsonb_build_object('request_id',gen_random_uuid(),'class_code','CLASS_10'));
  raise exception 'Training accepted school context';
 exception when others then if sqlerrm='Training accepted school context' then raise; end if; end;
 begin
  perform public.save_programme_run(input||jsonb_build_object('request_id',gen_random_uuid(),'id',run,'revision',1,'website_visible',true));
  raise exception 'Published without fees';
 exception when others then if sqlerrm='Published without fees' then raise; end if; end;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'run_id',run,'revision',0,'cycle','COURSE','due_day',10,'allowed_discounts',jsonb_build_array(5,10),
 'components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Course fee','amount',3000,'charge_type','TUITION','recurrence','PER_CYCLE')),'reason','Save current course standard fees');
 result:=public.save_run_fees(input);
 if public.save_run_fees(input)<>result then raise exception 'Fee retry changed result'; end if;
 begin
  perform public.save_run_fees(input||jsonb_build_object('request_id',gen_random_uuid(),'revision',1,'allowed_discounts',jsonb_build_array(90)));
  raise exception 'Unsupported discount accepted';
 exception when check_violation then null; end;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'run_id',run,'name','Evening A','capacity',1,'reason','Create a teaching batch');
 result:=public.save_teaching_batch(input); batch:=(result->>'id')::uuid;
 result:=public.save_person(jsonb_build_object('request_id',gen_random_uuid(),'full_name','Adult Training Participant','reason','Verify participant identity')); person:=(result->>'id')::uuid;
 insert into public.batch_seats values(batch,person,academy,true);
 result:=public.save_person(jsonb_build_object('request_id',gen_random_uuid(),'full_name','Another Participant','reason','Verify participant identity'));
 begin
  insert into public.batch_seats values(batch,(result->>'id')::uuid,academy,true);
  raise exception 'Full batch accepted another student';
 exception when others then if sqlerrm='Full batch accepted another student' then raise; end if; end;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'id',run,'revision',1,'programme_id',programme,'division_id',training,'campus_id',campus,
 'starts_on','2026-01-01','ends_on','2026-12-31','subject_ids',jsonb_build_array(subject_id),'website_visible',true,'applications_open',true,'reason','Publish reviewed course information');
 result:=public.save_programme_run(input);
 if (public.programme_run_setup(run)->>'batchTotal')::integer<>1 then raise exception 'Setup batch count incorrect'; end if;
 if jsonb_array_length(public.public_current_programmes())<>1 then raise exception 'Published course absent from public contract'; end if;
 if (public.list_current_programmes(training)->>'total')::integer<>1 then raise exception 'Division filter incorrect'; end if;
 result:=public.save_programme_run(input||jsonb_build_object('request_id',gen_random_uuid(),'revision',2,'is_active',false));
 if jsonb_array_length(public.public_current_programmes())<>0 then raise exception 'Inactive course still public'; end if;
 result:=public.save_academic_year(jsonb_build_object('request_id',gen_random_uuid(),'name','2026','starts_on','2026-01-01','ends_on','2026-12-31','reason','Create the school academic year')); yr:=(result->>'id')::uuid;
 perform public.save_academic_year(jsonb_build_object('request_id',gen_random_uuid(),'name','2027','starts_on','2027-01-01','ends_on','2027-12-31','reason','Open next academic year too'));
 if (select count(*) from public.academic_years where is_active)<>2 then raise exception 'Multiple active years blocked'; end if;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'programme_id',programme,'division_id',school,'campus_id',campus,'academic_year_id',yr,'class_code','CLASS_8',
 'starts_on','2026-01-01','ends_on','2026-12-31','reason','Prepare a school context');
 perform public.save_programme_run(input);
 begin
  perform public.save_programme_run(input||jsonb_build_object('request_id',gen_random_uuid(),'class_code','CLASS_9'));
  raise exception 'School accepted class outside current scope';
 exception when others then if sqlerrm='School accepted class outside current scope' then raise; end if; end;
 begin
  perform public.save_programme_run(input||jsonb_build_object('request_id',gen_random_uuid(),'division_id',coaching));
  raise exception 'Coaching accepted Class 8';
 exception when others then if sqlerrm='Coaching accepted Class 8' then raise; end if; end;
 if has_function_privilege('anon','public.save_programme(jsonb)','execute') then raise exception 'Public can mutate programmes'; end if;
 if has_function_privilege('authenticated','public.lookup_operation(uuid,text,jsonb)','execute') then raise exception 'Internal request helper is exposed'; end if;
 if exists(select 1 from public.activity_events where actor_name is distinct from 'Catalogue Administrator') then raise exception 'Audit actor absent'; end if;
end $$;
rollback;
