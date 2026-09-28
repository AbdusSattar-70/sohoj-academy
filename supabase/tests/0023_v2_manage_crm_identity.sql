begin;
do $$
declare u uuid:=gen_random_uuid(); y uuid; x jsonb;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,'edit-'||u||'@example.invalid','{"full_name":"Edit Test"}');
 perform public.bootstrap_admin('edit-'||u||'@example.invalid','Edit Test');
 perform set_config('request.jwt.claim.sub',u::text,true);
 x:=public.manage_crm_master_record(jsonb_build_object('entity','academic_year','name','2037 Test Year',
   'starts_on','2037-01-01','ends_on','2037-12-31','is_active',false,'reason','Create identity regression year'));
 y:=(x->>'id')::uuid;
 if y is null or x->>'action'<>'CREATE' then raise exception 'Create did not return identity'; end if;
 x:=public.manage_crm_master_record(jsonb_build_object('entity','academic_year','id',y,'name','2037 Updated Year','starts_on','2037-01-01','ends_on','2037-12-31','is_active',false,'reason','Verify editing year'));
 if x->>'action'<>'UPDATE' then raise exception 'Update action missing'; end if;
 if x->>'id' is distinct from y::text then raise exception 'No identity in result'; end if;
end $$;
rollback;
