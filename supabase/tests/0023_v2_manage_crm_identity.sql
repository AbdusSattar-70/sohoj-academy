begin;
do $$
declare u uuid:=gen_random_uuid(); y uuid; y2 uuid; x jsonb; org uuid;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,'edit-'||u||'@example.invalid','{"full_name":"Edit Test"}');
 perform public.bootstrap_admin('edit-'||u||'@example.invalid','Edit Test');
 perform set_config('request.jwt.claim.sub',u::text,true);
 select id into org from public.organizations where code='SOHOJ';
 x:=public.manage_crm_master_record(jsonb_build_object('entity','academic_year','name','2037 Test Year',
   'starts_on','2037-01-01','ends_on','2037-12-31','is_active',true,'reason','Create identity regression year'));
 y:=(x->>'id')::uuid;
 if y is null or x->>'action'<>'CREATE' then raise exception 'Create did not return identity'; end if;
 if not exists(select 1 from public.academic_years where id=y and is_active) then
   raise exception 'Requested academic year was not activated on creation'; end if;
 if not exists(select 1 from public.academic_years where organization_id=org and name='2026' and is_active) then
   raise exception 'Creating an active future year disabled the present year'; end if;
 x:=public.manage_crm_master_record(jsonb_build_object('entity','academic_year','name','2038 Test Year',
   'starts_on','2038-01-01','ends_on','2038-12-31','is_active',true,'reason','Prepare another academic year'));
 y2:=(x->>'id')::uuid;
 if (select count(*) from public.academic_years where id in(y,y2) and is_active)<>2 then
   raise exception 'Two academic years cannot be active concurrently'; end if;
 x:=public.manage_crm_master_record(jsonb_build_object('entity','academic_year','id',y,'name','2037 Updated Year','starts_on','2037-01-01','ends_on','2037-12-31','is_active',false,'reason','Verify editing year'));
 if x->>'action'<>'UPDATE' then raise exception 'Update action missing'; end if;
 if x->>'id' is distinct from y::text then raise exception 'No identity in result'; end if;
 if (select is_active from public.academic_years where id=y2) is not true then
   raise exception 'Deactivating one year disabled another'; end if;
end $$;
rollback;
