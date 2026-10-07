-- Isolated staff identity regression; no records survive rollback.
begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000051','staff-id@example.test',now());
select public.initialize_academy('staff-id@example.test','Staff ID Administrator');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000051',true);
do $$ declare academy uuid; person uuid; number bigint; result jsonb; begin
 result:=public.academy_account_context();
 if result->>'staffId' is null or result->>'staffId' !~ '^SA-STF-[0-9]{5,}$' then raise exception 'Bootstrap staff ID missing'; end if;
 select id into academy from public.academies;
 insert into public.people(academy_id,full_name) values(academy,'Identity fixture teacher') returning id into person;
 insert into public.person_responsibilities values(person,academy,'TEACHER',true);
 select staff_no into number from public.people where id=person;
 if number is null then raise exception 'Teacher staff ID missing'; end if;
 insert into public.person_responsibilities values(person,academy,'STAFF',true);
 insert into public.person_responsibilities values(person,academy,'REFERRER',true);
 if (select referrer_no from public.people where id=person) is null then raise exception 'Referrer ID missing'; end if;
 result:=public.search_people_by_role('SA-STF-'||lpad(number::text,5,'0'),1,'TEACHER');
 if (result->>'total')::int<>1 or result->'rows'->0->>'staff_no' is null or result->'rows'->0->>'referrer_no' is null then raise exception 'Role identity search failed'; end if;
 begin
  update public.people set referrer_no=referrer_no+100 where id=person;
  raise exception 'Referrer ID rewrite unexpectedly accepted';
 exception when others then if sqlerrm<>'Referrer identity cannot be changed.' then raise; end if; end;
 if has_sequence_privilege('authenticated','public.referrer_identity_number','USAGE') then raise exception 'Client can issue referrer IDs'; end if;
 update public.person_responsibilities set is_active=false where person_id=person;
 update public.people set full_name='Renamed teacher',is_active=false where id=person;
 if (select staff_no from public.people where id=person) is distinct from number then raise exception 'Staff ID changed'; end if;
 begin
  update public.people set staff_no=number+100 where id=person;
  raise exception 'Staff ID rewrite unexpectedly accepted';
 exception when others then
  if sqlerrm<>'Staff identity cannot be changed.' then raise; end if;
 end;
 if has_sequence_privilege('authenticated','public.staff_identity_number','USAGE') then raise exception 'Client can issue staff IDs'; end if;
end $$;
rollback;
