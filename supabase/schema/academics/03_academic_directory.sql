create table public.education_levels (
 code text primary key check(code in('EARLY_YEARS','SCHOOL','GRADUATION','POSTGRADUATE')),
 name text not null, name_bn text not null, sort_order integer not null, is_active boolean not null default true
);
create table public.education_tracks (
 code text primary key, level_code text not null references public.education_levels,
 name text not null, name_bn text not null, duration_years integer check(duration_years between 1 and 4),
 sort_order integer not null, is_active boolean not null default true
);
create table public.class_levels (
 code text primary key, level_code text not null references public.education_levels,
 name text not null, name_bn text not null, sort_order integer not null, is_active boolean not null default true
);
create table public.directory_entries (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 kind text not null check(kind in('INSTITUTION','AREA','RELATIONSHIP','SUBJECT','MAJOR','GROUP','PROGRAMME_TYPE','EXPENSE_CATEGORY','DISCOUNT_REASON','LEAD_SOURCE')),
 code text not null check(code ~ '^[A-Z][A-Z0-9_]{1,79}$'), name text not null check(length(btrim(name)) between 2 and 160), name_bn text,
 normalized_name text generated always as (lower(regexp_replace(btrim(name),'\s+',' ','g'))) stored,
 locality text not null default '', institution_type text check(institution_type in('SCHOOL','COLLEGE','MADRASA','UNIVERSITY','OTHER')),
 eiin text check(eiin is null or eiin ~ '^[0-9]{6}$'), source_url text, verified_on date,
 is_verified boolean not null default false, is_active boolean not null default true,
 sort_order integer not null default 0, revision integer not null default 1,
 created_at timestamptz not null default now(),
 unique(academy_id,kind,code), unique(academy_id,kind,normalized_name,locality), unique(id,academy_id),
 check(kind='INSTITUTION' or (institution_type is null and eiin is null and source_url is null and verified_on is null and not is_verified)),
 check(not is_verified or (verified_on is not null and source_url is not null and source_url ~ '^https://'))
);
create unique index institution_eiin_idx on public.directory_entries(academy_id,eiin) where eiin is not null;
create index directory_lookup_idx on public.directory_entries(academy_id,kind,is_active,sort_order,name);
create table public.academic_years (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 name text not null, starts_on date not null, ends_on date not null, is_active boolean not null default true,
 check(ends_on>=starts_on), unique(academy_id,name), unique(id,academy_id)
);
-- Multiple years may be active; no single-active-year uniqueness constraint.

create function public.save_directory_entry(p_input jsonb) returns jsonb language plpgsql security definer
set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('directory.manage'); actor uuid:=auth.uid();
 request uuid:=(p_input->>'request_id')::uuid; original public.directory_entries; saved public.directory_entries;
 prior public.operation_requests; result jsonb; identity uuid:=nullif(p_input->>'id','')::uuid;
 reason_value text:=btrim(p_input->>'reason'); kind_value text:=p_input->>'kind';
begin
 if request is null or reason_value is null or length(reason_value) not between 5 and 1000 then raise exception 'Request identity and change reason are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||request::text,0));
 select * into prior from public.operation_requests where actor_id=actor and request_id=request;
 if found then
  if prior.command<>'SAVE_DIRECTORY' or prior.payload<>p_input then raise exception 'This request identity belongs to different input.'; end if;
  return prior.result;
 end if;
 if identity is not null then
  select * into original from public.directory_entries where id=identity and academy_id=academy for update;
  if not found then raise exception 'Directory entry not found.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'This entry changed. Reload before saving.'; end if;
  if kind_value is distinct from original.kind then raise exception 'An entry cannot change its directory type.'; end if;
  update public.directory_entries set name=btrim(p_input->>'name'),name_bn=nullif(btrim(p_input->>'name_bn'),''),
   locality=lower(btrim(coalesce(p_input->>'locality',''))),
   institution_type=nullif(p_input->>'institution_type',''),eiin=nullif(p_input->>'eiin',''),
   source_url=nullif(p_input->>'source_url',''),verified_on=nullif(p_input->>'verified_on','')::date,
   is_verified=coalesce((p_input->>'is_verified')::boolean,false),is_active=coalesce((p_input->>'is_active')::boolean,true),
   sort_order=coalesce((p_input->>'sort_order')::integer,0),revision=revision+1 where id=identity returning * into saved;
 else
  insert into public.directory_entries(academy_id,kind,code,name,name_bn,locality,institution_type,eiin,source_url,verified_on,is_verified,sort_order,is_active)
  values(academy,kind_value,coalesce(nullif(upper(btrim(p_input->>'code')),''),'CUSTOM_'||upper(replace(gen_random_uuid()::text,'-',''))),
   btrim(p_input->>'name'),nullif(btrim(p_input->>'name_bn'),''),lower(btrim(coalesce(p_input->>'locality',''))),
   nullif(p_input->>'institution_type',''),nullif(p_input->>'eiin',''),nullif(p_input->>'source_url',''),
   nullif(p_input->>'verified_on','')::date,coalesce((p_input->>'is_verified')::boolean,false),coalesce((p_input->>'sort_order')::integer,0),coalesce((p_input->>'is_active')::boolean,true)) returning * into saved;
 end if;
 result:=jsonb_build_object('id',saved.id,'name',saved.name,'nameBn',saved.name_bn,'kind',saved.kind,'revision',saved.revision,'isActive',saved.is_active);
 perform public.record_activity(case when identity is null then 'CREATE' else 'EDIT' end,'DIRECTORY',saved.id::text,reason_value,to_jsonb(original),to_jsonb(saved),request);
 insert into public.operation_requests values(actor,request,'SAVE_DIRECTORY',p_input,result,now());
 return result;
end $$;
create function public.search_directory(p_kind text,p_query text default '',p_page integer default 1,p_include_inactive boolean default false)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('directory.view'); needle text:=btrim(p_query); result jsonb;
begin
 if p_page is null or p_page<1 or p_page>100000 or needle is null or length(needle)>160 then raise exception 'Choose a valid search/page.'; end if;
 if p_include_inactive and not public.can_operate('directory.manage') then raise exception 'Inactive entries require management access.' using errcode='42501'; end if;
 with matched as(select id,code,name,name_bn,kind,locality,institution_type,eiin,source_url,verified_on,is_verified,is_active,revision,sort_order from public.directory_entries
  where academy_id=academy and kind=p_kind and (is_active or p_include_inactive) and (needle='' or position(lower(needle) in normalized_name)>0 or position(needle in coalesce(name_bn,''))>0)),
 paged as(select * from matched order by sort_order,name,id limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,
  'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by sort_order,name,id) from paged),'[]')) into result;
 return result;
end $$;
do $$ declare relation text; begin
 foreach relation in array array['education_levels','education_tracks','class_levels','directory_entries','academic_years'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
  execute format('create trigger preserve_record before delete on public.%I for each row execute function public.reject_record_delete()',relation);
 end loop;
end $$;
create policy level_read on public.education_levels for select to authenticated using(public.current_academy_id() is not null);
create policy track_read on public.education_tracks for select to authenticated using(public.current_academy_id() is not null);
create policy class_read on public.class_levels for select to authenticated using(public.current_academy_id() is not null);
create policy year_read on public.academic_years for select to authenticated using(academy_id=public.current_academy_id() and public.can_operate('directory.view'));
grant select on public.education_levels,public.education_tracks,public.class_levels,public.academic_years to authenticated;
revoke all on function public.save_directory_entry(jsonb),public.search_directory(text,text,integer,boolean) from public,anon;
grant execute on function public.save_directory_entry(jsonb),public.search_directory(text,text,integer,boolean) to authenticated;
