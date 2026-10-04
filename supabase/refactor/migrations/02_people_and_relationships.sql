-- Generated from supabase/schema/people/02_people_and_relationships.sql; edit the source, then run pnpm db:baseline.
create table public.people (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 person_no bigint generated always as identity unique, full_name text not null check(length(btrim(full_name)) between 2 and 160),
 full_name_bn text, date_of_birth date, mobile text check(mobile is null or mobile ~ '^01[3-9][0-9]{8}$'),
 email text check(email is null or email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
 present_address jsonb not null default '{}', permanent_address jsonb not null default '{}',
 is_active boolean not null default true, revision integer not null default 1,
 created_at timestamptz not null default now(), unique(id,academy_id)
);
-- Shared family phone is allowed. Matching is assistance, not automatic identity merge.
create index people_search_name_idx on public.people(academy_id,lower(full_name));
create index people_search_mobile_idx on public.people(academy_id,mobile) where mobile is not null;
create table public.person_responsibilities (
 person_id uuid not null, academy_id uuid not null,
 responsibility text not null check(responsibility in('STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER')),
 is_active boolean not null default true, primary key(person_id,responsibility),
 foreign key(person_id,academy_id) references public.people(id,academy_id)
);
create table public.person_relationships (
 person_id uuid not null, related_person_id uuid not null, academy_id uuid not null,
 relationship text not null check(length(btrim(relationship)) between 2 and 80),
 is_primary_contact boolean not null default false, is_active boolean not null default true,
 primary key(person_id,related_person_id,relationship), check(person_id<>related_person_id),
 foreign key(person_id,academy_id) references public.people(id,academy_id),
 foreign key(related_person_id,academy_id) references public.people(id,academy_id)
);
create unique index person_primary_guardian_idx on public.person_relationships(person_id) where is_active and is_primary_contact;
create table public.person_accounts (
 profile_id uuid primary key,
 person_id uuid not null unique references public.people,
 academy_id uuid not null,
 foreign key(person_id,academy_id) references public.people(id,academy_id),
 foreign key(profile_id,academy_id) references public.account_profiles(id,academy_id)
);

create function public.save_person(p_input jsonb) returns jsonb language plpgsql security definer
set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage'); actor uuid:=auth.uid();
 request uuid:=(p_input->>'request_id')::uuid; original public.people; saved public.people;
 prior public.operation_requests; result jsonb; identity uuid:=nullif(p_input->>'id','')::uuid;
 name_value text:=btrim(p_input->>'full_name'); reason_value text:=btrim(p_input->>'reason');
begin
 if request is null then raise exception 'Request identity is required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||request::text,0));
 select * into prior from public.operation_requests where actor_id=actor and request_id=request;
 if found then
  if prior.command<>'SAVE_PERSON' or prior.payload<>p_input then raise exception 'This request identity belongs to different input.'; end if;
  return prior.result;
 end if;
 if name_value is null or length(name_value) not between 2 and 160 or reason_value is null or length(reason_value) not between 5 and 1000 then
  raise exception 'Enter the name and a short change reason.';
 end if;
 if jsonb_typeof(coalesce(p_input->'present_address','{}'))<>'object' or jsonb_typeof(coalesce(p_input->'permanent_address','{}'))<>'object' then
  raise exception 'Address must contain structured address details.';
 end if;
 if identity is not null then
  select * into original from public.people where id=identity and academy_id=academy for update;
  if not found then raise exception 'Person not found.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'This person changed. Reload before saving your correction.'; end if;
  update public.people set full_name=name_value,full_name_bn=nullif(btrim(p_input->>'full_name_bn'),''),
   mobile=nullif(btrim(p_input->>'mobile'),''),email=nullif(lower(btrim(p_input->>'email')),''),
   date_of_birth=nullif(p_input->>'date_of_birth','')::date,
   present_address=coalesce(p_input->'present_address','{}'),
   permanent_address=case when coalesce((p_input->>'same_address')::boolean,false) then coalesce(p_input->'present_address','{}') else coalesce(p_input->'permanent_address','{}') end,
   revision=revision+1 where id=identity returning * into saved;
 else
  insert into public.people(academy_id,full_name,full_name_bn,mobile,email,date_of_birth,present_address,permanent_address)
  values(academy,name_value,nullif(btrim(p_input->>'full_name_bn'),''),nullif(btrim(p_input->>'mobile'),''),nullif(lower(btrim(p_input->>'email')),''),
   nullif(p_input->>'date_of_birth','')::date,coalesce(p_input->'present_address','{}'),
   case when coalesce((p_input->>'same_address')::boolean,false) then coalesce(p_input->'present_address','{}') else coalesce(p_input->'permanent_address','{}') end)
  returning * into saved;
 end if;
 if saved.date_of_birth>timezone('Asia/Dhaka',now())::date then raise exception 'Date of birth cannot be in the future.'; end if;
 result:=jsonb_build_object('id',saved.id,'number',saved.person_no,'name',saved.full_name,'revision',saved.revision);
 perform public.record_activity(case when identity is null then 'CREATE' else 'EDIT' end,'PERSON',saved.id::text,reason_value,to_jsonb(original),to_jsonb(saved),request);
 insert into public.operation_requests values(actor,request,'SAVE_PERSON',p_input,result,now());
 return result;
end $$;
create function public.search_people(p_query text default '',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb; needle text:=btrim(p_query);
begin
 if p_page is null or p_page<1 or p_page>100000 then raise exception 'Choose a valid page.'; end if;
 if needle is null or length(needle)>160 then raise exception 'Enter a valid search.'; end if;
 with matched as (
  select id,person_no,full_name,mobile,email,is_active,revision from public.people
  where academy_id=academy and (needle='' or position(lower(needle) in lower(full_name))>0 or position(needle in coalesce(mobile,''))>0 or person_no::text=needle)
 ), paged as(select * from matched order by full_name,id limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,
 'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by full_name,id) from paged),'[]')) into result;
 return result;
end $$;
do $$ declare relation text; begin
 foreach relation in array array['people','person_responsibilities','person_relationships','person_accounts'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
  execute format('create trigger preserve_record before delete on public.%I for each row execute function public.reject_record_delete()',relation);
 end loop;
end $$;
-- Contacts are returned through scoped functions, not broad direct reads.
revoke all on function public.save_person(jsonb),public.search_people(text,integer) from public,anon;
grant execute on function public.save_person(jsonb),public.search_people(text,integer) to authenticated;

create function public.set_person_responsibility(p_input jsonb) returns jsonb language plpgsql security definer
set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage'); actor uuid:=auth.uid();
 request uuid:=(p_input->>'request_id')::uuid; identity uuid:=(p_input->>'person_id')::uuid;
 responsibility_value text:=p_input->>'responsibility'; prior public.operation_requests;
 person public.people; result jsonb; reason_value text:=btrim(p_input->>'reason');
begin
 if request is null or reason_value is null or length(reason_value) not between 5 and 1000 then raise exception 'Request identity and change reason are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||request::text,0));
 select * into prior from public.operation_requests where actor_id=actor and request_id=request;
 if found then
  if prior.command<>'SET_RESPONSIBILITY' or prior.payload<>p_input then raise exception 'This request identity belongs to different input.'; end if;
  return prior.result;
 end if;
 select * into person from public.people where id=identity and academy_id=academy and is_active for update;
 if not found then raise exception 'Choose an active person.'; end if;
 if (p_input->>'revision')::integer is distinct from person.revision then raise exception 'This person changed. Reload before changing responsibilities.'; end if;
 insert into public.person_responsibilities(person_id,academy_id,responsibility) values(identity,academy,responsibility_value)
 on conflict(person_id,responsibility) do update set is_active=true;
 if responsibility_value='TEACHER' then
  insert into public.person_responsibilities values(identity,academy,'STAFF',true)
  on conflict(person_id,responsibility) do update set is_active=true;
 end if;
 update public.people set revision=revision+1 where id=identity;
 result:=jsonb_build_object('id',identity,'responsibility',responsibility_value,'revision',person.revision+1);
 perform public.record_activity('ADD_RESPONSIBILITY','PERSON',identity::text,reason_value,null,result,request);
 insert into public.operation_requests values(actor,request,'SET_RESPONSIBILITY',p_input,result,now());
 return result;
end $$;
revoke all on function public.set_person_responsibility(jsonb) from public,anon;
grant execute on function public.set_person_responsibility(jsonb) to authenticated;
