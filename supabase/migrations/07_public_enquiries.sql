-- Generated from supabase/schema/crm/07_public_enquiries.sql; edit the source, then run pnpm db:baseline.
-- Public submissions are unverified JSON claims, never student/placement identities.
create table public.enquiries (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 enquiry_no bigint generated always as identity unique, request_id uuid not null unique,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=16000),
 status text not null default 'NEW' check(status in ('NEW','CONTACTED','CLOSED')),
 created_at timestamptz not null default now()
);
alter table public.enquiries enable row level security;
revoke all on public.enquiries from anon,authenticated;
create trigger preserve_record before delete on public.enquiries for each row execute function public.reject_record_delete();
create function public.public_application_choices() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object(
 'classes',coalesce((select jsonb_agg(jsonb_build_object('id',code,'name',name) order by sort_order) from public.class_levels where is_active),'[]'),
 'programmes',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) order by p.name) from public.programmes p where p.is_active and exists(select 1 from public.programme_runs r where r.programme_id=p.id and r.is_active and r.website_visible)),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by sort_order,name) from public.directory_entries where kind='SUBJECT' and is_active),'[]'),
 'schools',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',name) order by name) from public.directory_entries where kind='INSTITUTION' and is_active),'[]'),
 'sources',coalesce((select jsonb_agg(jsonb_build_object('code',code,'name',name) order by sort_order,name) from public.directory_entries where kind='LEAD_SOURCE' and is_active),'[]'),
 'relationships',coalesce((select jsonb_agg(jsonb_build_object('code',code,'name',name) order by sort_order,name) from public.directory_entries where kind='RELATIONSHIP' and is_active),'[]'));
$$;
create function public.receive_public_enquiry(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare saved public.enquiries; academy uuid; phone text:=btrim(p_payload->>'mobile');
begin
 if p_request_id is null or jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text)>16000 then raise exception 'Invalid application.'; end if;
 if coalesce(length(btrim(p_payload->>'studentName')),0) not between 2 and 120 or coalesce(length(btrim(p_payload->>'guardianName')),0) not between 2 and 120 or phone is null or phone !~ '^01[3-9][0-9]{8}$' or p_payload->>'consentToContact' is distinct from 'true' then raise exception 'Check the student, guardian, mobile and contact permission.'; end if;
 select id into academy from public.academies limit 1;
 if academy is null then raise exception 'Academy is not configured.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(phone,0));
 select * into saved from public.enquiries where request_id=p_request_id;
 if found then
  if saved.payload is distinct from p_payload then raise exception 'Retry the unchanged application.'; end if;
  return jsonb_build_object('reference','ENQ-'||lpad(saved.enquiry_no::text,6,'0'));
 end if;
 if exists(select 1 from public.enquiries where payload->>'mobile'=phone and created_at>now()-interval '1 minute') then raise exception 'Please wait a minute before another application.'; end if;
 insert into public.enquiries(academy_id,request_id,payload) values(academy,p_request_id,p_payload) returning * into saved;
 return jsonb_build_object('reference','ENQ-'||lpad(saved.enquiry_no::text,6,'0'));
end $$;
create function public.search_enquiries(p_query text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb;
begin
 if p_page is null or p_page not between 1 and 100000 or length(p_query)>160 then raise exception 'Invalid search.'; end if;
 with matched as(select id,enquiry_no,payload,status,created_at from public.enquiries where academy_id=academy and (p_query='' or payload->>'studentName' ilike '%'||p_query||'%' or payload->>'mobile' ilike '%'||p_query||'%')),
 paged as(select * from matched order by created_at desc,id limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by created_at desc,id) from paged),'[]')) into result;
 return result;
end $$;
revoke all on function public.public_application_choices(),public.receive_public_enquiry(uuid,jsonb),public.search_enquiries(text,integer) from public,anon,authenticated;
grant execute on function public.public_application_choices(),public.receive_public_enquiry(uuid,jsonb) to anon,authenticated;
grant execute on function public.search_enquiries(text,integer) to authenticated;
