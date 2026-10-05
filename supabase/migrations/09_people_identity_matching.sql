-- Generated from supabase/schema/people/09_people_identity_matching.sql; edit the source, then run pnpm db:baseline.
-- Contacts belong to people records, not login credentials. Shared contacts are allowed.
create function public.find_person_matches(p_input jsonb) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view');
 name_value text:=lower(btrim(coalesce(p_input->>'full_name','')));
 mobile_value text:=btrim(coalesce(p_input->>'mobile',''));
 email_value text:=lower(btrim(coalesce(p_input->>'email','')));
 excluded uuid:=nullif(p_input->>'exclude_id','')::uuid;
begin
 if length(name_value)>160 or length(mobile_value)>11 or length(email_value)>200 then raise exception 'Invalid matching input.'; end if;
 return coalesce((select jsonb_agg(to_jsonb(m)) from (
  select id,person_no,full_name,mobile,email,is_active,revision from public.people
  where academy_id=academy and (excluded is null or id<>excluded) and (
   (length(name_value)>=2 and lower(full_name)=name_value) or
   (mobile_value<>'' and mobile=mobile_value) or
   (email_value<>'' and lower(email)=email_value))
  order by is_active desc,full_name,id limit 10
 )m),'[]'::jsonb);
end $$;
revoke all on function public.find_person_matches(jsonb) from public,anon;
grant execute on function public.find_person_matches(jsonb) to authenticated;
