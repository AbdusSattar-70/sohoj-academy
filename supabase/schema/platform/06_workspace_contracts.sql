create function public.academy_account_context() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('profileId',p.id,'academyId',p.academy_id,'name',p.display_name,
 'academyName',a.name,'roles',coalesce((select jsonb_agg(role_code order by role_code) from public.account_roles where profile_id=p.id),'[]'),
 'permissions',coalesce((select jsonb_agg(permission order by permission) from (select distinct unnest(r.permissions) permission from public.account_roles ar join public.access_roles r on r.code=ar.role_code where ar.profile_id=p.id)s),'[]'))
 from public.account_profiles p join public.academies a on a.id=p.academy_id where p.id=auth.uid() and p.is_active
$$;
create function public.academy_setup_choices() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.view'); begin
 return jsonb_build_object(
 'divisions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'nameBn',name_bn,'code',code) order by code) from public.operating_divisions where academy_id=academy and is_active),'[]'),
 'campuses',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.campuses where academy_id=academy and is_active),'[]'),
 'years',coalesce((select jsonb_agg(to_jsonb(y) order by y.starts_on desc) from (select id,name,starts_on,ends_on,is_active,revision from public.academic_years where academy_id=academy order by starts_on desc,id limit 100)y),'[]'),
 'classes',coalesce((select jsonb_agg(jsonb_build_object('code',code,'name',name,'nameBn',name_bn) order by sort_order) from public.class_levels where is_active),'[]'));
end $$;
create function public.person_profile(p_person_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); person public.people; begin
 select * into person from public.people where id=p_person_id and academy_id=academy;
 if not found then raise exception 'Person not found.'; end if;
 return to_jsonb(person)||jsonb_build_object('responsibilities',coalesce((select jsonb_agg(responsibility order by responsibility) from public.person_responsibilities where person_id=person.id and is_active),'[]'));
end $$;
create function public.save_person_profile(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; saved jsonb; identity uuid; responsibility_value text; roles text[];
begin
 prior:=public.lookup_operation(req,'SAVE_PERSON_PROFILE',p_input); if prior is not null then return prior; end if;
 if jsonb_typeof(p_input->'responsibilities') is distinct from 'array' or jsonb_array_length(p_input->'responsibilities')>5 then raise exception 'Choose valid responsibilities.'; end if;
 select coalesce(array_agg(distinct value),'{}') into roles from jsonb_array_elements_text(p_input->'responsibilities');
 if not roles<@array['STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER'] then raise exception 'Choose valid responsibilities.'; end if;
 if 'TEACHER'=any(roles) and not 'STAFF'=any(roles) then roles:=roles||'STAFF'; end if;
 saved:=public.save_person(p_input||jsonb_build_object('request_id',gen_random_uuid())); identity:=(saved->>'id')::uuid;
 if not 'STUDENT'=any(roles) and exists(select 1 from public.batch_seats where person_id=identity and is_active) then raise exception 'Keep Student responsibility while an active placement exists.'; end if;
 if not 'GUARDIAN'=any(roles) and exists(select 1 from public.person_relationships where related_person_id=identity and is_active) then raise exception 'Keep Guardian responsibility while a guardian relationship exists.'; end if;
 update public.person_responsibilities set is_active=false where person_id=identity;
 foreach responsibility_value in array roles loop
  insert into public.person_responsibilities values(identity,academy,responsibility_value,true)
  on conflict(person_id,responsibility) do update set is_active=true;
 end loop;
 saved:=public.person_profile(identity);
 return public.finish_operation(req,'SAVE_PERSON_PROFILE',p_input,saved,'PERSON',identity,null);
end $$;
create function public.set_person_active(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.people; saved public.people; begin
 prior:=public.lookup_operation(req,'SET_PERSON_ACTIVE',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 if jsonb_typeof(p_input->'is_active') is distinct from 'boolean' then raise exception 'Choose active or inactive.'; end if;
 select * into original from public.people where id=(p_input->>'id')::uuid and academy_id=academy for update;
 if not found then raise exception 'Person not found.'; end if;
 if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Person changed. Reload before editing.'; end if;
 if not (p_input->>'is_active')::boolean and (exists(select 1 from public.batch_seats where person_id=original.id and is_active) or exists(select 1 from public.person_relationships where related_person_id=original.id and is_active)) then raise exception 'Close active placement or update guardian relationships before marking this person inactive.'; end if;
 update public.people set is_active=(p_input->>'is_active')::boolean,revision=revision+1 where id=original.id returning * into saved;
 return public.finish_operation(req,'SET_PERSON_ACTIVE',p_input,to_jsonb(saved),'PERSON',saved.id,to_jsonb(original));
end $$;
create function public.search_programme_definitions(p_query text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.view'); result jsonb; begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 100000 then raise exception 'Choose a valid search/page.'; end if;
 with matched as(select id,name,name_bn,programme_type_id,is_active,revision from public.programmes where academy_id=academy and (p_query='' or position(lower(btrim(p_query)) in normalized_name)>0)),
 paged as(select * from matched order by name,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by name,id) from paged),'[]')) into result;
 return result;
end $$;
revoke all on function public.academy_account_context(),public.academy_setup_choices(),public.person_profile(uuid),public.save_person_profile(jsonb),public.set_person_active(jsonb),public.search_programme_definitions(text,integer) from public,anon;
grant execute on function public.academy_account_context(),public.academy_setup_choices(),public.person_profile(uuid),public.save_person_profile(jsonb),public.set_person_active(jsonb),public.search_programme_definitions(text,integer) to authenticated;
