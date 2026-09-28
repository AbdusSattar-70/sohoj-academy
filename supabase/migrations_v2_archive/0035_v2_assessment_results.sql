-- Assessments are dated batch/subject events. Result submissions preserve
-- revisions; only a different authorized reviewer makes one official.
create table public.academic_assessments (
 id uuid primary key default gen_random_uuid(),
 batch_id uuid not null references public.batches(id),
 subject_id uuid not null references public.subjects(id),
 title text not null check(length(btrim(title)) between 3 and 180),
 assessment_date date not null,
 max_marks numeric(8,2) not null check(max_marks>0 and max_marks<=1000),
 status text not null default 'DRAFT' check(status in ('DRAFT','PUBLISHED','CANCELLED')),
 author_id uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 published_at timestamptz,
 check ((status='DRAFT')=(published_at is null) or status='CANCELLED')
);
create index academic_assessments_scope on public.academic_assessments(batch_id,subject_id,assessment_date desc);
create table public.assessment_result_submissions (
 id uuid primary key default gen_random_uuid(),
 assessment_id uuid not null references public.academic_assessments(id),
 revision integer not null check(revision>0),
 entries jsonb not null,
 status text not null default 'DRAFT' check(status in ('DRAFT','SUBMITTED','APPROVED','REJECTED')),
 author_id uuid not null references public.profiles(id),
 reviewer_id uuid references public.profiles(id),
 review_note text,
 created_at timestamptz not null default now(),
 submitted_at timestamptz,
 reviewed_at timestamptz,
 unique(assessment_id,revision),
 check ((status in ('APPROVED','REJECTED'))=(reviewer_id is not null))
);
create unique index assessment_one_draft on public.assessment_result_submissions(assessment_id) where status='DRAFT';
create unique index assessment_one_pending on public.assessment_result_submissions(assessment_id) where status='SUBMITTED';
alter table public.academic_assessments enable row level security;
alter table public.assessment_result_submissions enable row level security;
revoke all on public.academic_assessments,public.assessment_result_submissions from anon,authenticated;

create or replace function public.can_access_assessment(p_batch uuid,p_subject uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and public.has_permission('academics.view') and (
  public.has_permission('academics.assessments.approve') or public.has_permission('academics.sessions.manage')
  or exists(select 1 from public.class_sessions cs join public.staff st on st.id=cs.teacher_id
    where cs.batch_id=p_batch and cs.subject_id=p_subject and st.profile_id=auth.uid())
 );
$$;
revoke all on function public.can_access_assessment(uuid,uuid) from public,anon;
grant execute on function public.can_access_assessment(uuid,uuid) to authenticated;

create or replace function public.assessment_workspace()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 return jsonb_build_object(
  'scopes',coalesce((select jsonb_agg(jsonb_build_object('batchId',cs.batch_id,'subjectId',cs.subject_id,'batch',b.name,'subject',s.name) order by b.name,s.name)
    from (select distinct batch_id,subject_id from public.class_sessions) cs
    join public.batches b on b.id=cs.batch_id join public.subjects s on s.id=cs.subject_id
    where public.can_access_assessment(cs.batch_id,cs.subject_id)),'[]'::jsonb),
  'assessments',coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'batchId',a.batch_id,'subjectId',a.subject_id,'batch',b.name,'subject',s.name,
    'title',a.title,'date',a.assessment_date,'maxMarks',a.max_marks,'status',a.status,
    'authorId',a.author_id,'roster',coalesce((select jsonb_agg(jsonb_build_object('enrollmentId',e.id,'studentNo',st.student_no,'name',st.full_name) order by st.student_no)
      from public.enrollments e join public.students st on st.id=e.student_id
      where e.batch_id=a.batch_id and e.admission_date<=a.assessment_date
        and (e.ended_on is null or e.ended_on>a.assessment_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')),'[]'::jsonb),
    'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'revision',r.revision,'status',r.status,'entries',r.entries,'authorId',r.author_id,'reviewNote',r.review_note,'createdAt',r.created_at) order by r.revision desc)
      from public.assessment_result_submissions r where r.assessment_id=a.id),'[]'::jsonb)
    ) order by a.assessment_date desc)
    from public.academic_assessments a join public.batches b on b.id=a.batch_id join public.subjects s on s.id=a.subject_id
    where public.can_access_assessment(a.batch_id,a.subject_id)),'[]'::jsonb)
 );
end $$;

create or replace function public.assessment_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid:=auth.uid(); act text:=p_input->>'action'; rid uuid:=(p_input->>'request_id')::uuid;
  a public.academic_assessments; r public.assessment_result_submissions; key public.admission_command_keys;
  v_entries jsonb:=coalesce(p_input->'entries','[]'::jsonb); expected integer; result jsonb;
  v_batch uuid; v_subject uuid; v_date date; v_max numeric;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 if rid is null then raise exception 'Request identity required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
 select * into key from public.admission_command_keys where request_id=rid;
 if found then
   if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
   return key.result;
 end if;
 if act='CREATE' then
   if not public.has_permission('academics.assessments.record') then raise exception 'Assessment recording permission required.'; end if;
   v_batch:=(p_input->>'batch_id')::uuid; v_subject:=(p_input->>'subject_id')::uuid;
   if not public.can_access_assessment(v_batch,v_subject) then raise exception 'Assessment is outside your teaching scope.'; end if;
   if not exists(select 1 from public.class_sessions where batch_id=v_batch and subject_id=v_subject) then raise exception 'Schedule a class for this batch and subject first.'; end if;
   v_date:=(p_input->>'assessment_date')::date; v_max:=(p_input->>'max_marks')::numeric;
   if v_date is null or v_max is null or v_max<=0 or v_max>1000
     or length(btrim(coalesce(p_input->>'title',''))) not between 3 and 180 then raise exception 'Enter assessment title, date and valid maximum marks.'; end if;
   if not exists(select 1 from public.batches b join public.academic_years y on y.id=b.academic_year_id where b.id=v_batch and v_date between y.starts_on and y.ends_on) then raise exception 'Assessment date must be in the batch academic year.'; end if;
   insert into public.academic_assessments(batch_id,subject_id,title,assessment_date,max_marks,author_id)
   values(v_batch,v_subject,btrim(p_input->>'title'),v_date,v_max,actor) returning * into a;
 else
   select * into a from public.academic_assessments where id=(p_input->>'assessment_id')::uuid for update;
   if a.id is null or not public.can_access_assessment(a.batch_id,a.subject_id) then raise exception 'Assessment not found in your scope.'; end if;
   if act='PUBLISH' then
     if a.status<>'DRAFT' or not public.has_permission('academics.assessments.record') then raise exception 'Only a draft can be published.'; end if;
     if a.author_id<>actor and not public.has_permission('academics.sessions.manage') then raise exception 'Only the author may publish this assessment.'; end if;
     update public.academic_assessments set status='PUBLISHED',published_at=now() where id=a.id returning * into a;
   elsif act='SAVE_RESULTS' then
     if a.status<>'PUBLISHED' or not public.has_permission('academics.assessments.record') then raise exception 'Published assessment and recording permission required.'; end if;
     if jsonb_typeof(v_entries)<>'array' or jsonb_array_length(v_entries)>500 then raise exception 'Check result entries.'; end if;
     select count(*) into expected from public.enrollments e where e.batch_id=a.batch_id and e.admission_date<=a.assessment_date
       and (e.ended_on is null or e.ended_on>a.assessment_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED');
     if expected=0 or expected<>jsonb_array_length(v_entries) then raise exception 'Record exactly one result for every eligible student.'; end if;
     if exists(select 1 from jsonb_array_elements(v_entries) e where
       not (e ? 'enrollment_id' and e ? 'score') or (e->>'score') !~ '^([0-9]+)(\.[0-9]{1,2})?$'
       or (e->>'score')::numeric>a.max_marks or length(coalesce(e->>'feedback',''))>500
       or not exists(select 1 from public.enrollments x where x.id=(e->>'enrollment_id')::uuid and x.batch_id=a.batch_id
         and x.admission_date<=a.assessment_date and (x.ended_on is null or x.ended_on>a.assessment_date)
         and x.status in ('ACTIVE','WITHDRAWN','COMPLETED')))
       or (select count(distinct e->>'enrollment_id') from jsonb_array_elements(v_entries) e)<>expected
       then raise exception 'Invalid or duplicate result entries.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null then
       if exists(select 1 from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED') then raise exception 'Results are awaiting independent review.'; end if;
       insert into public.assessment_result_submissions(assessment_id,revision,entries,author_id)
       values(a.id,(select coalesce(max(revision),0)+1 from public.assessment_result_submissions where assessment_id=a.id),v_entries,actor) returning * into r;
     else
       if r.author_id<>actor then raise exception 'Only the draft author can change these results.'; end if;
       update public.assessment_result_submissions set entries=v_entries where id=r.id returning * into r;
     end if;
   elsif act='SUBMIT_RESULTS' then
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null or r.author_id<>actor then raise exception 'Save your result draft before submitting.'; end if;
     update public.assessment_result_submissions set status='SUBMITTED',submitted_at=now() where id=r.id returning * into r;
   elsif act in ('APPROVE_RESULTS','REJECT_RESULTS') then
     if not public.has_permission('academics.assessments.approve') then raise exception 'Assessment review permission required.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED' for update;
     if r.id is null then raise exception 'No submitted result revision is awaiting review.'; end if;
     if r.author_id=actor then raise exception 'Result author cannot approve or reject their own submission.'; end if;
     if length(btrim(coalesce(p_input->>'review_note','')))<5 then raise exception 'Enter a review reason.'; end if;
     update public.assessment_result_submissions set status=case when act='APPROVE_RESULTS' then 'APPROVED' else 'REJECTED' end,
       reviewer_id=actor,review_note=btrim(p_input->>'review_note'),reviewed_at=now() where id=r.id returning * into r;
   else raise exception 'Unknown assessment action.'; end if;
 end if;
 result:=jsonb_build_object('id',a.id,'status',coalesce(r.status,a.status),'revision',r.revision);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
 values(actor,'ASSESSMENT',a.id::text,act,case when r.id is null then to_jsonb(a) else to_jsonb(r) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
 return result;
end $$;
revoke all on function public.assessment_workspace(),public.assessment_command(jsonb) from public,anon;
grant execute on function public.assessment_workspace(),public.assessment_command(jsonb) to authenticated;
