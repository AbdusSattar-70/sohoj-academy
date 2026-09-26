-- Permanent identities survive enrollment changes and controlled duplicate resolution.
alter table public.admission_cases drop constraint admission_cases_student_id_key;
alter table public.admission_cases alter column prospect_id drop not null;
alter table public.admission_cases add column existing_student boolean not null default false;
alter table public.admission_cases add constraint admission_identity_source check(prospect_id is not null or (existing_student and student_id is not null));
alter table public.students add column merged_into_id uuid references public.students(id);
alter table public.students add constraint no_self_merge check(merged_into_id is null or merged_into_id<>id);
create index students_merged_into on public.students(merged_into_id) where merged_into_id is not null;
create index admission_student_history on public.admission_cases(student_id,created_at);
create table public.student_merges (
 id uuid primary key default gen_random_uuid(), source_id uuid not null unique references public.students(id),
 target_id uuid not null references public.students(id), approval_id uuid not null unique references public.approval_requests(id),
 source_snapshot jsonb not null,target_snapshot jsonb not null,created_at timestamptz not null default now(),check(source_id<>target_id)
);
create table public.enrollment_transfers (
 id uuid primary key default gen_random_uuid(),student_id uuid not null references public.students(id),admission_id uuid not null references public.admission_cases(id),
 from_enrollment_id uuid not null unique references public.enrollments(id),to_enrollment_id uuid not null unique references public.enrollments(id),
 from_batch_id uuid not null references public.batches(id),to_batch_id uuid not null references public.batches(id),
 approval_id uuid not null unique references public.approval_requests(id),capacity_policy_version_id uuid not null references public.business_rule_versions(id),
 transferred_on date not null,created_at timestamptz not null default now()
);
insert into public.permissions(code,name,description) values('students.merge.approve','Approve student identity merges','Independently approve linking a duplicate identity to its canonical student.');
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code='ADMIN' and p.code='students.merge.approve';
revoke insert,update,delete on public.students,public.guardians,public.student_guardians from authenticated,anon;
do $$ declare t text; begin
 foreach t in array array['student_merges','enrollment_transfers'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
 execute format('create policy lifecycle_read on public.%I for select to authenticated using(public.has_permission(''students.view''))',t);
 execute format('create trigger lifecycle_immutable before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 end loop;
end; $$;

create or replace function public.student_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys;s public.students;target public.students;a public.admission_cases;b public.batches;dest public.batches;
 fee public.fee_plan_versions;guardian record;policy public.business_rule_versions;approval public.approval_requests;e public.enrollments;
 sid uuid:=(p_input->>'student_id')::uuid;tid uuid:=(p_input->>'target_id')::uuid;eid uuid;aid uuid;today date;result jsonb;snapshot jsonb;
begin
 if actor is null or not public.has_permission('students.view') then raise exception 'Student access required.';end if;
 if req is null or length(reason)<5 or length(reason)>500 then raise exception 'Request identity and a reason of 5–500 characters are required.';end if;
 if action='CREATE_EXISTING' then
  if not public.has_permission('admissions.create') then raise exception 'Admission creation permission required.';end if;
 elsif action in ('REQUEST_TRANSFER','REQUEST_MERGE') then
  if not public.has_permission('students.manage') then raise exception 'Student management permission required.';end if;
 elsif action is distinct from 'DECIDE' then raise exception 'Unsupported student action.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;
  return key.result;
 end if;
 if action='DECIDE' then
  select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid;
  if approval.id is null or approval.workflow_type not in ('STUDENT_TRANSFER','STUDENT_MERGE') then raise exception 'Student approval request not found.';end if;
  if not public.has_permission(case approval.workflow_type when 'STUDENT_MERGE' then 'students.merge.approve' else 'admissions.approve' end) then raise exception 'Independent approval permission required.';end if;
  sid:=(approval.payload_snapshot->>'student_id')::uuid;tid:=(approval.payload_snapshot->>'target_id')::uuid;
 end if;
 -- Case before student before batch: same ordering as admission transitions.
 if action='REQUEST_TRANSFER' or (action='DECIDE' and approval.workflow_type='STUDENT_TRANSFER') then
  aid:=case when action='DECIDE' then (approval.payload_snapshot->>'admission_id')::uuid else (p_input->>'admission_id')::uuid end;
  select * into a from public.admission_cases where id=aid for update;
  if a.id is null or a.student_id is distinct from sid then raise exception 'Admission does not belong to this student.';end if;
 end if;
 perform 1 from public.students where id in(sid,tid) order by id for update;
 select * into s from public.students where id=sid;
 if s.id is null then raise exception 'Student not found.';end if;
 select (now() at time zone timezone)::date into today from public.organizations where id=s.organization_id;
 if action='DECIDE' then
  select * into approval from public.approval_requests where id=approval.id for update;
  if approval.status<>'PENDING' then raise exception 'Request already decided.';end if;
  if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide this request.';end if;
  if p_input->>'decision' not in ('APPROVED','REJECTED') or p_input->>'decision' is null then raise exception 'Choose Approve or Reject.';end if;
 end if;
 if action='DECIDE' and p_input->>'decision'='REJECTED' then
  null; -- Reject even if the underlying record has changed since submission.
 else
  if s.merged_into_id is not null or s.status='ARCHIVED' then raise exception 'Use the canonical, non-archived Student identity.';end if;
  if action='CREATE_EXISTING' then
   select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
   if b.id is null or b.organization_id<>s.organization_id or not exists(select 1 from public.programme_offerings where id=b.offering_id and status='ACTIVE') then raise exception 'Select an active offering-linked batch in this organization.';end if;
   if exists(select 1 from public.enrollments where student_id=s.id and academic_year_id=b.academic_year_id and status='ACTIVE')
    or exists(select 1 from public.admission_cases ac join public.batches ba on ba.id=ac.batch_id where ac.student_id=s.id and ba.academic_year_id=b.academic_year_id and ac.status<>'CANCELLED') then
    raise exception 'An open admission or active enrollment already exists for this academic year. Use transfer or finish cancellation first.';end if;
   select * into policy from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if policy.id is null then raise exception 'Capacity policy missing.';end if;
   if (select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE')>=least(b.capacity,(policy.payload->>'max_students')::integer) then raise exception 'Selected batch is full.';end if;
   select * into fee from public.fee_plan_versions where offering_id=b.offering_id and status='ACTIVE' and effective_from<=today;
   if fee.id is null then raise exception 'An effective Fee Plan is required.';end if;
   select g.full_name,g.mobile,sg.relationship_snapshot into guardian from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=s.id and sg.is_primary;
   if guardian.full_name is null then raise exception 'A primary guardian is required.';end if;
   insert into public.admission_cases(batch_id,fee_plan_version_id,student_id,existing_student,identity_snapshot,created_by)
   values(b.id,fee.id,s.id,true,jsonb_build_object('student_name',s.full_name,'guardian_name',guardian.full_name,'mobile',guardian.mobile,'guardian_relationship',coalesce(guardian.relationship_snapshot,'Guardian'),'school_id',s.school_id,'school_name',s.school_name_snapshot),actor) returning id into aid;
   result:=jsonb_build_object('id',aid,'message','Enrollment draft created using the existing Student ID. Review and accept it in Admissions.');
  elsif action='REQUEST_TRANSFER' or (action='DECIDE' and approval.workflow_type='STUDENT_TRANSFER') then
   if a.status<>'ACTIVE_ENROLLMENT' then raise exception 'Only an active enrollment can transfer.';end if;
   select * into e from public.enrollments where id=a.enrollment_id and status='ACTIVE';
   if e.id is null then raise exception 'Active enrollment not found.';end if;
   if action='DECIDE' and (approval.payload_snapshot->>'enrollment_id')::uuid<>e.id then raise exception 'Enrollment changed. Submit a fresh transfer request.';end if;
   eid:=case when action='DECIDE' then (approval.payload_snapshot->>'batch_id')::uuid else (p_input->>'batch_id')::uuid end;
   perform 1 from public.batches where id in(a.batch_id,eid) order by id for update;
   select * into b from public.batches where id=a.batch_id;
   select * into dest from public.batches where id=eid and is_active;
   if dest.id is null or dest.id=b.id or dest.offering_id is distinct from b.offering_id or dest.organization_id<>b.organization_id then raise exception 'Transfer requires a different active batch in the same offering. Fee terms remain unchanged.';end if;
   select * into policy from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if policy.id is null then raise exception 'Capacity policy missing.';end if;
   if (select count(*) from public.enrollments where batch_id=dest.id and status='ACTIVE')>=least(dest.capacity,(policy.payload->>'max_students')::integer) then raise exception 'Destination batch is full under the current capacity policy.';end if;
   if action='REQUEST_TRANSFER' then
    snapshot:=p_input||jsonb_build_object('enrollment_id',e.id,'from_batch_id',b.id,'from_batch_name',b.name,'to_batch_name',dest.name,'student_name',s.full_name,'student_no',s.student_no);
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
    values('STUDENT_TRANSFER','STUDENT',s.id::text,action,snapshot,reason,actor,req) returning id into aid;
    result:=jsonb_build_object('id',aid,'message','Transfer submitted for independent approval. No seat is reserved yet.');
   else
    update public.enrollments set status='WITHDRAWN',ended_on=today where id=e.id;
    insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,admission_date,status,created_by)
    values(s.id,dest.organization_id,dest.branch_id,dest.academic_year_id,dest.class_id,dest.program_id,dest.id,today,'ACTIVE',actor) returning id into eid;
    insert into public.enrollment_transfers(student_id,admission_id,from_enrollment_id,to_enrollment_id,from_batch_id,to_batch_id,approval_id,capacity_policy_version_id,transferred_on)
    values(s.id,a.id,e.id,eid,b.id,dest.id,approval.id,policy.id,today);
    update public.admission_cases set batch_id=dest.id,enrollment_id=eid,capacity_policy_version_id=policy.id where id=a.id;
   end if;
  elsif action='REQUEST_MERGE' or (action='DECIDE' and approval.workflow_type='STUDENT_MERGE') then
   select * into target from public.students where id=tid;
   if target.id is null or target.id=s.id or target.organization_id<>s.organization_id or target.merged_into_id is not null or target.status='ARCHIVED' then raise exception 'Select a different canonical student in this organization.';end if;
   if exists(select 1 from public.students where merged_into_id=s.id) then raise exception 'A canonical identity with linked duplicates cannot be merged again.';end if;
   if exists(select 1 from public.enrollments where student_id=s.id and status='ACTIVE') or exists(select 1 from public.admission_cases where student_id=s.id and status<>'CANCELLED') then raise exception 'Resolve the duplicate identity’s open admissions and enrollments before merging.';end if;
   if lower(btrim(s.full_name))<>lower(btrim(target.full_name)) and not exists(
    select 1 from public.student_guardians x join public.guardians gx on gx.id=x.guardian_id cross join public.student_guardians y join public.guardians gy on gy.id=y.guardian_id
    where x.student_id=s.id and y.student_id=target.id and gx.mobile=gy.mobile) then raise exception 'No matching name or guardian mobile. Verify the identities before requesting a merge.';end if;
   if action='REQUEST_MERGE' then
    if (p_input->>'confirmed_same_person') is distinct from 'true' then raise exception 'Explicitly verify these records belong to the same student.';end if;
    snapshot:=p_input||jsonb_build_object('source_snapshot',to_jsonb(s),'target_snapshot',to_jsonb(target));
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
    values('STUDENT_MERGE','STUDENT',s.id::text,action,snapshot,reason,actor,req) returning id into aid;
    result:=jsonb_build_object('id',aid,'message','Duplicate resolution submitted. An independent reviewer must verify both identities.');
   else
    if to_jsonb(s)<>approval.payload_snapshot->'source_snapshot' or to_jsonb(target)<>approval.payload_snapshot->'target_snapshot' then raise exception 'Student records changed. Submit a fresh duplicate review.';end if;
    insert into public.student_merges(source_id,target_id,approval_id,source_snapshot,target_snapshot) values(s.id,target.id,approval.id,to_jsonb(s),to_jsonb(target));
    update public.students set merged_into_id=target.id,status='ARCHIVED' where id=s.id;
    -- History and guardian links retain their original IDs and appear in the canonical profile.
   end if;
  end if;
 end if;
 if action='DECIDE' then
  update public.approval_requests set status=(p_input->>'decision')::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
  result:=jsonb_build_object('id',approval.id,'message','Request '||lower(p_input->>'decision')||'.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,'STUDENT',s.id::text,action,reason,to_jsonb(s),result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end; $$;
revoke all on function public.student_command(jsonb) from public,anon;
grant execute on function public.student_command(jsonb) to authenticated;
