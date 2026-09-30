-- Public choices are applicant statements, never verified ERP placement.
alter table public.prospects add column application_snapshot jsonb,
  add column application_verified_at timestamptz,
  add column application_verified_by uuid references public.profiles(id);

create or replace function public.submit_public_interest(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 org public.organizations; branch public.branches; applicant public.prospects;
 mobile_value text; snapshot jsonb; item jsonb; correlation uuid:=gen_random_uuid();
begin
 if jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text)>16000 then
  raise exception 'Enter a valid application.';
 end if;
 if length(btrim(coalesce(p_payload->>'student_name',''))) not between 2 and 160
 or length(btrim(coalesce(p_payload->>'guardian_name',''))) not between 2 and 160 then
  raise exception 'Student and guardian names are required.';
 end if;
 mobile_value:=regexp_replace(coalesce(p_payload->>'mobile',''),'\D','','g');
 if mobile_value !~ '^01[3-9][0-9]{8}$' then raise exception 'A valid mobile number is required.'; end if;
 if coalesce((p_payload->>'consent_to_contact')::boolean,false) is not true then
  raise exception 'Consent to contact is required.';
 end if;
 select * into org from public.organizations where code='SOHOJ' and is_active limit 1;
 if org.id is null then raise exception 'The academy is not accepting applications yet.'; end if;
 select * into branch from public.branches where organization_id=org.id and is_active order by created_at limit 1;
 perform pg_advisory_xact_lock(hashtextextended(mobile_value,3));
 if exists(select 1 from public.prospects p where p.mobile=mobile_value
   and lower(p.student_name)=lower(btrim(p_payload->>'student_name'))
   and p.created_at>now()-interval '2 minutes') then
  raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
 end if;
 -- Preserve submitted IDs and text. Labels are captured for review, never FK links.
 snapshot:=p_payload||jsonb_build_object('verification','UNVERIFIED',
   'class_label',(select name from public.classes where id::text=p_payload->>'class_id' and organization_id=org.id),
   'offering_label',(select name from public.programme_offerings where id::text=p_payload->>'offering_id' and organization_id=org.id),
   'program_labels',coalesce((select jsonb_agg(name) from public.programs where organization_id=org.id
     and coalesce(p_payload->'program_ids','[]'::jsonb) ? id::text),'[]'::jsonb),
   'subject_labels',coalesce((select jsonb_agg(name) from public.subjects where organization_id=org.id
     and coalesce(p_payload->'subject_ids','[]'::jsonb) ? id::text),'[]'::jsonb));
 insert into public.prospects(organization_id,branch_id,student_name,student_name_bn,
  guardian_name,guardian_relationship_snapshot,mobile,alternate_mobile,
  school_name_snapshot,area_snapshot,guardian_address,referral_note,notes,
  consent_to_contact,submitted_via,submission_intent,application_snapshot)
 values(org.id,branch.id,btrim(p_payload->>'student_name'),nullif(btrim(p_payload->>'student_name_bn'),''),
  btrim(p_payload->>'guardian_name'),nullif(btrim(p_payload->>'guardian_relationship'),''),
  mobile_value,nullif(btrim(p_payload->>'alternate_mobile'),''),
  coalesce(nullif(btrim(p_payload->>'school_name_snapshot'),''),
   (select name from public.schools where id::text=p_payload->>'school_id' and organization_id=org.id)),
  nullif(btrim(p_payload->>'area'),''),nullif(btrim(p_payload->>'guardian_address'),''),
  nullif(btrim(p_payload->>'referral_note'),''),nullif(btrim(p_payload->>'notes'),''),
  true,'PUBLIC_WEB',case when p_payload->>'intent'='admission' then 'admission' else 'interest' end,snapshot) returning * into applicant;
 insert into public.audit_events(correlation_id,entity_type,entity_id,action,metadata)
 values(correlation,'PROSPECT',applicant.id::text,'RECEIVE_UNVERIFIED_APPLICATION',
  jsonb_build_object('intent',p_payload->>'intent','verification','UNVERIFIED'));
 return jsonb_build_object('prospect_no',applicant.prospect_no,'prospect_id',applicant.id);
end $$;
revoke all on function public.submit_public_interest(jsonb) from public;
grant execute on function public.submit_public_interest(jsonb) to anon,authenticated;

-- Conversion assigns verified placement, including enquiries with no verified class.
create or replace function public.create_prospect_admission(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.prospects; o public.programme_offerings; k public.admission_command_keys;
 req uuid:=nullif(p_input->>'request_id','')::uuid; result jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or p_input->>'action' is distinct from 'CREATE' or length(btrim(coalesce(p_input->>'reason','')))<5 then
  raise exception 'A valid request and verification note are required.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if;
  return k.result;
 end if;
 select * into p from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
 select * into o from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status='ACTIVE';
 if p.id is null or p.status in('CONVERTED','LOST') or o.id is null or p.organization_id<>o.organization_id
 or not exists(select 1 from public.batches where id=(p_input->>'batch_id')::uuid and offering_id=o.id and is_active) then
  raise exception 'Choose an open enquiry, active offering and its batch.';
 end if;
 if (p.current_class_id is not null and p.current_class_id<>o.class_id)
   or (p.interested_offering_id is not null and p.interested_offering_id<>o.id) then
  if coalesce((p_input->>'confirm_placement_correction')::boolean,false) is not true then
   raise exception 'Confirm the corrected placement.';
  end if;
 end if;
 update public.prospects set current_class_id=o.class_id,interested_offering_id=o.id,
  application_verified_at=now(),application_verified_by=auth.uid() where id=p.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'PROSPECT',p.id::text,'VERIFY_ADMISSION_PLACEMENT',p_input->>'reason',to_jsonb(p),
   jsonb_build_object('class_id',o.class_id,'offering_id',o.id));
 result:=public.admission_command(p_input);
 return result;
end $$;
revoke all on function public.create_prospect_admission(jsonb) from public,anon;
grant execute on function public.create_prospect_admission(jsonb) to authenticated;
