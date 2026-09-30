-- A second display name is optional. Programme definitions supply the default.
alter function public.create_programme_offering(jsonb) rename to create_programme_offering_named;
alter function public.update_programme_offering(jsonb) rename to update_programme_offering_named;
revoke all on function public.create_programme_offering_named(jsonb),public.update_programme_offering_named(jsonb) from public,anon,authenticated;
create or replace function public.create_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare name text;
begin
 if auth.uid() is null or not public.has_permission('academics.manage') then raise exception 'Academic management permission required.'; end if;
 select coalesce(nullif(btrim(p_input->>'name'),''),p.name) into name from public.programs p where p.id=(p_input->>'program_id')::uuid;
 if name is null then raise exception 'Choose a programme definition.'; end if;
 return public.create_programme_offering_named(p_input||jsonb_build_object('name',name));
end $$;
create or replace function public.update_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare name text;
begin
 if auth.uid() is null or not public.has_permission('academics.manage') then raise exception 'Academic management permission required.'; end if;
 select coalesce(nullif(btrim(p_input->>'name'),''),p.name) into name from public.programs p where p.id=(p_input->>'program_id')::uuid;
 if name is null then raise exception 'Choose a programme definition.'; end if;
 return public.update_programme_offering_named(p_input||jsonb_build_object('name',name));
end $$;
revoke all on function public.create_programme_offering(jsonb),public.update_programme_offering(jsonb) from public,anon;
grant execute on function public.create_programme_offering(jsonb),public.update_programme_offering(jsonb) to authenticated;
