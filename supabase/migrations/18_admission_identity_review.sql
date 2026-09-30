alter table public.admission_cases add column identity_revision integer not null default 1;
alter table public.admission_physical_consent_receipts add column identity_revision integer not null default 1;
create or replace function public.edit_admission_identity(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; identity jsonb:=p_input->'identity'; guardian_id uuid; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission management permission required.'; end if;
 if jsonb_typeof(identity) is distinct from 'object' or octet_length(identity::text)>5000
 or length(btrim(coalesce(p_input->>'reason','')))<5
 or length(btrim(coalesce(identity->>'student_name',''))) not between 2 and 160
 or length(btrim(coalesce(identity->>'guardian_name',''))) not between 2 and 160
 or coalesce(identity->>'mobile','') !~ '^01[3-9][0-9]{8}$'
 or length(btrim(coalesce(identity->>'guardian_address',''))) not between 5 and 300 then raise exception 'Enter verified student, guardian, contact and address details.'; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status='CANCELLED' then raise exception 'Choose an open admission case.'; end if;
 if a.existing_student and a.student_id is null then raise exception 'Existing student identity is unavailable.'; end if;
 before_data:=a.identity_snapshot;
 identity:=jsonb_build_object('student_name',btrim(identity->>'student_name'),'student_name_bn',nullif(btrim(identity->>'student_name_bn'),''),
 'guardian_name',btrim(identity->>'guardian_name'),'mobile',identity->>'mobile','alternate_mobile',nullif(identity->>'alternate_mobile',''),
 'guardian_address',btrim(identity->>'guardian_address'),'guardian_relationship',btrim(identity->>'guardian_relationship'),
 'date_of_birth',nullif(identity->>'date_of_birth','')::date,'gender',nullif(identity->>'gender',''),
 'school_name',btrim(identity->>'school_name'),'school_roll',btrim(identity->>'school_roll'));
 if a.student_id is not null then
  if not public.has_permission('students.manage') then raise exception 'Student correction permission required.'; end if;
  update public.students set full_name=identity->>'student_name',school_name_snapshot=identity->>'school_name' where id=a.student_id;
  -- Do not change a shared guardian identity. Link to an existing matching guardian
  -- or create the corrected guardian; keep the old guardian record intact.
  select g.id into guardian_id from public.guardians g join public.students s on s.organization_id=g.organization_id
   where s.id=a.student_id and g.mobile=identity->>'mobile' and lower(g.full_name)=lower(identity->>'guardian_name') order by g.created_at limit 1;
  if guardian_id is null then
   insert into public.guardians(organization_id,full_name,mobile,created_by)
    select organization_id,identity->>'guardian_name',identity->>'mobile',auth.uid() from public.students where id=a.student_id returning id into guardian_id;
  end if;
  update public.student_guardians set is_primary=false where student_id=a.student_id and is_primary;
  insert into public.student_guardians(student_id,guardian_id,relationship_snapshot,is_primary)
  values(a.student_id,guardian_id,identity->>'guardian_relationship',true)
  on conflict(student_id,guardian_id) do update set is_primary=true,relationship_snapshot=excluded.relationship_snapshot;
 end if;
 update public.admission_cases set identity_snapshot=identity_snapshot||identity,
  identity_revision=identity_revision+1,
  status=case when status in('DRAFT','READY') then 'DRAFT' else status end where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'CORRECT_IDENTITY',p_input->>'reason',before_data,identity);
 return jsonb_build_object('id',a.id);
end $$;
revoke all on function public.edit_admission_identity(jsonb) from public,anon;
grant execute on function public.edit_admission_identity(jsonb) to authenticated;

-- Signed originals are never overwritten. A correction needs a new consent receipt.
create or replace function public.record_physical_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; r public.admission_physical_consent_receipts;
 req uuid:=(p_input->>'request_id')::uuid; signing date:=(p_input->>'guardian_signed_on')::date; today date;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or signing is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Signing date and staff note are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into r from public.admission_physical_consent_receipts where request_id=req;
 if found then
  if r.received_by<>auth.uid() or r.request_payload<>p_input then raise exception 'Request identity already used.'; end if;
  return jsonb_build_object('id',r.id);
 end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status in('DRAFT','CANCELLED') then raise exception 'Verify the application before receiving paper consent.'; end if;
 if not exists(select 1 from public.admission_referrals where admission_id=a.id) then raise exception 'Record Organic or a verified referrer first.'; end if;
 select timezone(o.timezone,now())::date into today from public.batches b join public.organizations o on o.id=b.organization_id where b.id=a.batch_id;
 if signing>today then raise exception 'Signing date cannot be in the future.'; end if;
 if exists(select 1 from public.admission_physical_consent_receipts where admission_id=a.id and identity_revision=a.identity_revision) then raise exception 'Consent for these details is already recorded.'; end if;
 insert into public.admission_physical_consent_receipts(request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,physical_copy_reference,received_by,reason,identity_revision)
 values(req,p_input,a.id,(select coalesce(max(version),0)+1 from public.admission_physical_consent_receipts where admission_id=a.id),signing,coalesce((p_input->>'student_signed')::boolean,false),nullif(btrim(p_input->>'physical_copy_reference'),''),auth.uid(),p_input->>'reason',a.identity_revision) returning * into r;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values(auth.uid(),'ADMISSION_CONSENT',r.id::text,'RECEIVE_PAPER_FORM',p_input->>'reason',to_jsonb(r));
 return jsonb_build_object('id',r.id);
end $$;

create or replace function public.admission_review_checks(p_admission_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('admissions.view') then raise exception 'Admission view permission required.'; end if;
 return (select jsonb_build_object('hasConsent',exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=a.id and r.identity_revision=a.identity_revision),'identityRevision',a.identity_revision) from public.admission_cases a where a.id=p_admission_id);
end $$;
revoke all on function public.admission_review_checks(uuid) from public,anon;
grant execute on function public.admission_review_checks(uuid) to authenticated;

-- Enforce fresh consent even if a caller bypasses the screen.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'-- Accept and invoice atomically. Failure rolls back student issuance as well.',
 $gate$if not exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=a.id and r.identity_revision=a.identity_revision) then raise exception 'Record signed paper consent for the current details before final submission.'; end if;
  -- Accept and invoice atomically. Failure rolls back student issuance as well.$gate$);
 execute definition;
end $migration$;
