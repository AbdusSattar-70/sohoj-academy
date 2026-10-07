-- Generated from supabase/schema/people/18_role_identity_display.sql; edit the source, then run pnpm db:baseline.
alter table public.people add column referrer_no bigint unique;
create sequence public.referrer_identity_number;
create function public.assign_referrer_identity() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.responsibility='REFERRER' then
  update public.people set referrer_no=nextval('public.referrer_identity_number') where id=new.person_id and academy_id=new.academy_id and referrer_no is null;
 end if;
 return new;
end $$;
revoke all on function public.assign_referrer_identity() from public,anon,authenticated;
revoke all on sequence public.referrer_identity_number from public,anon,authenticated;
create trigger assign_referrer_identity after insert or update on public.person_responsibilities for each row execute function public.assign_referrer_identity();
update public.people p set referrer_no=nextval('public.referrer_identity_number') where referrer_no is null and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility='REFERRER');
create or replace function public.protect_staff_identity() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if old.staff_no is not null and new.staff_no is distinct from old.staff_no then raise exception 'Staff identity cannot be changed.'; end if;
 if old.referrer_no is not null and new.referrer_no is distinct from old.referrer_no then raise exception 'Referrer identity cannot be changed.'; end if;
 return new;
end $$;
create or replace function public.find_person_matches(p_input jsonb) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view');
 name_value text:=lower(btrim(coalesce(p_input->>'full_name','')));
 mobile_value text:=btrim(coalesce(p_input->>'mobile',''));
 email_value text:=lower(btrim(coalesce(p_input->>'email','')));
 excluded uuid:=nullif(p_input->>'exclude_id','')::uuid;
begin
 if length(name_value)>160 or length(mobile_value)>11 or length(email_value)>200 then raise exception 'Invalid matching input.'; end if;
 return coalesce((select jsonb_agg(to_jsonb(m)) from (
  select id,person_no,staff_no,referrer_no,full_name,mobile,email,is_active,revision from public.people
  where academy_id=academy and (excluded is null or id<>excluded) and (
   (length(name_value)>=2 and lower(full_name)=name_value) or
   (mobile_value<>'' and mobile=mobile_value) or
   (email_value<>'' and lower(email)=email_value))
  order by is_active desc,full_name,id limit 10
 )m),'[]'::jsonb);
end $$;
revoke all on function public.find_person_matches(jsonb) from public,anon;
grant execute on function public.find_person_matches(jsonb) to authenticated;
create or replace function public.search_people_by_role(p_query text default '',p_page integer default 1,p_responsibility text default '') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb; needle text:=lower(btrim(p_query));
begin
 if p_page is null or p_page not between 1 and 100000 or needle is null or length(needle)>160 or p_responsibility is null or p_responsibility not in('','STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER') then raise exception 'Invalid person search.';end if;
 with matched as(select id,person_no,staff_no,referrer_no,full_name,mobile,email,is_active,revision from public.people p where academy_id=academy and
 (needle='' or position(needle in lower(full_name))>0 or position(needle in coalesce(mobile,''))>0 or position(needle in lower(coalesce(email,'')))>0 or person_no::text=needle or lower('SA-STF-'||lpad(staff_no::text,greatest(5,length(staff_no::text)),'0'))=needle or lower('SA-RFR-'||lpad(referrer_no::text,greatest(5,length(referrer_no::text)),'0'))=needle) and
 (p_responsibility='' or exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility=p_responsibility and r.is_active))),
 paged as(select * from matched order by full_name,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by full_name,id) from paged),'[]')) into result;return result;
end $$;
revoke all on function public.search_people_by_role(text,integer,text) from public,anon;
grant execute on function public.search_people_by_role(text,integer,text) to authenticated;
