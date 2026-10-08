create table public.student_progress_reports(
 id uuid primary key default gen_random_uuid(),student_id uuid not null references public.students(id),batch_id uuid not null references public.batches(id),starts_on date not null,ends_on date not null,
 author_id uuid not null references public.profiles(id),status text not null default 'DRAFT' check(status in('DRAFT','SUBMITTED','RETURNED','FINAL')),
 snapshot jsonb not null,teacher_comment text not null default '',home_support text[] not null default '{}',review_note text,reviewer_id uuid references public.profiles(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),finalized_at timestamptz,check(ends_on>=starts_on and ends_on-starts_on<=92));
alter table public.student_progress_reports enable row level security;revoke all on public.student_progress_reports from public,anon,authenticated;
create trigger progress_report_no_delete before delete on public.student_progress_reports for each row execute function public.prevent_permanent_record_delete();
create function public.can_prepare_batch_report(p_batch uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') and public.has_permission('academics.view') and exists(select 1 from public.batches b where b.id=p_batch and(public.has_permission('academics.sessions.manage') or public.has_permission('academics.assessments.approve') or exists(select 1 from public.class_sessions s join public.staff t on t.id=s.teacher_id where s.batch_id=b.id and t.profile_id=auth.uid() and t.status='ACTIVE')))
$$;
create function public.student_progress_evidence(p_student uuid,p_batch uuid,p_from date,p_to date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare attendance jsonb;marks jsonb;coverage jsonb;identity jsonb;begin
 if not public.can_prepare_batch_report(p_batch) then raise exception 'Assigned batch access required.';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>92 or p_to>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Use a completed period of at most 93 days.';end if;
 if not exists(select 1 from public.enrollments e where e.student_id=p_student and e.batch_id=p_batch and e.admission_date<=p_to and(e.ended_on is null or e.ended_on>p_from)) then raise exception 'Student was not enrolled in this batch during the selected period.';end if;
 select jsonb_build_object('id',s.id,'name',s.full_name,'number',s.student_no,'batch',b.name,'programme',o.name,'startsOn',p_from,'endsOn',p_to,'generatedAt',now()) into identity from public.students s join public.batches b on b.id=p_batch left join public.programme_offerings o on o.id=b.offering_id where s.id=p_student;
 select coalesce(jsonb_agg(jsonb_build_object('sessionId',cs.id,'date',cs.session_date,'subject',su.name,'submissionId',ar.id,'revision',ar.revision,'status',entry->>'status') order by cs.session_date,cs.id),'[]') into attendance
 from public.class_sessions cs join public.subjects su on su.id=cs.subject_id join lateral(select a.id,a.revision,a.entries from public.attendance_submissions a where a.session_id=cs.id and a.status='APPROVED' order by a.revision desc limit 1)ar on true cross join lateral jsonb_array_elements(ar.entries) entry join public.enrollments e on e.id=(entry->>'enrollment_id')::uuid
 where cs.batch_id=p_batch and cs.status='SCHEDULED' and cs.session_date between p_from and p_to and e.student_id=p_student;
 select coalesce(jsonb_agg(jsonb_build_object('assessmentId',a.id,'submissionId',r.id,'revision',r.revision,'date',a.assessment_date,'title',a.title,'subject',s.name,'score',(entry->>'score')::numeric,'maxMarks',a.max_marks,'feedback',entry->>'feedback') order by a.assessment_date,a.id),'[]') into marks
 from public.academic_assessments a join public.subjects s on s.id=a.subject_id join lateral(select ar.id,ar.revision,ar.entries from public.assessment_result_submissions ar where ar.assessment_id=a.id and ar.status='APPROVED' order by ar.revision desc limit 1)r on true cross join lateral jsonb_array_elements(r.entries) entry join public.enrollments e on e.id=(entry->>'enrollment_id')::uuid where a.batch_id=p_batch and a.status='PUBLISHED' and a.assessment_date between p_from and p_to and e.student_id=p_student and entry->>'score' is not null;
 select coalesce(jsonb_agg(jsonb_build_object('sessionId',cs.id,'logId',l.id,'revision',l.revision,'date',cs.session_date,'subject',s.name,'summary',l.class_summary,'progress',coalesce((select jsonb_agg(jsonb_build_object('title',v.units->((u->>'unit_index')::int)->>'title','status',u->>'status','note',u->>'note')) from jsonb_array_elements(l.unit_progress)u join public.curriculum_versions v on v.id=cs.curriculum_version_id),'[]'),'homework',l.homework,'homeworkStatus',h.status,'homeworkFeedback',h.feedback) order by cs.session_date,cs.id),'[]') into coverage
 from public.class_sessions cs join public.subjects s on s.id=cs.subject_id join lateral(select * from public.class_logs cl where cl.session_id=cs.id and cl.status='APPROVED' order by cl.revision desc limit 1)l on true left join lateral(select hc.status,hc.feedback from public.homework_checks hc join public.enrollments he on he.id=hc.enrollment_id where hc.class_log_id=l.id and he.student_id=p_student order by hc.revision desc limit 1)h on true where cs.batch_id=p_batch and cs.status='SCHEDULED' and cs.session_date between p_from and p_to and exists(select 1 from public.enrollments e where e.student_id=p_student and e.batch_id=p_batch and e.admission_date<=cs.session_date and(e.ended_on is null or e.ended_on>cs.session_date));
 return jsonb_build_object('student',identity,'attendance',attendance,'assessments',marks,'coverage',coverage,'attendanceCount',jsonb_array_length(attendance),'assessmentCount',jsonb_array_length(marks),'scoreTotal',(select sum((m->>'score')::numeric) from jsonb_array_elements(marks)m),'maxTotal',(select sum((m->>'maxMarks')::numeric) from jsonb_array_elements(marks)m));
end $$;
create function public.student_progress_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;act text:=p_input->>'action';r public.student_progress_reports;old jsonb;key public.admission_command_keys;result jsonb;note text:=btrim(coalesce(p_input->>'review_note',''));supports text[];begin
 if actor is null or not public.has_permission('academics.view') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Active academic access required.';end if;
 if req is null then raise exception 'Request identity required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity reused with different input.';end if;return key.result;end if;
 if nullif(p_input->>'id','') is not null then select * into r from public.student_progress_reports where id=(p_input->>'id')::uuid for update;if r.id is null or not public.can_prepare_batch_report(r.batch_id) then raise exception 'Progress report not accessible.';end if;old:=to_jsonb(r);end if;
 if act<>'GENERATE' and r.id is null then raise exception 'Select an existing record first.';end if;
 if act='GENERATE' then
  if r.id is not null then raise exception 'Create a new report for a new snapshot.';end if;
  insert into public.student_progress_reports(student_id,batch_id,starts_on,ends_on,author_id,snapshot) values((p_input->>'student_id')::uuid,(p_input->>'batch_id')::uuid,(p_input->>'starts_on')::date,(p_input->>'ends_on')::date,actor,public.student_progress_evidence((p_input->>'student_id')::uuid,(p_input->>'batch_id')::uuid,(p_input->>'starts_on')::date,(p_input->>'ends_on')::date)) returning * into r;
 elsif act='SAVE' then
  if r.author_id is distinct from actor or r.status not in('DRAFT','RETURNED') then raise exception 'Edit only your Draft or Returned report.';end if;
  select coalesce(array_agg(value),'{}') into supports from jsonb_array_elements_text(coalesce(p_input->'home_support','[]'));
  if length(coalesce(p_input->>'teacher_comment',''))>2000 or not supports<@array['DAILY_READING','HOMEWORK_SUPPORT','REGULAR_ATTENDANCE','GUARDIAN_MEETING']::text[] then raise exception 'Check comment or home support selections.';end if;
  update public.student_progress_reports set teacher_comment=coalesce(p_input->>'teacher_comment',''),home_support=supports,status='DRAFT',snapshot=public.student_progress_evidence(r.student_id,r.batch_id,r.starts_on,r.ends_on),updated_at=now() where id=r.id returning * into r;
 elsif act='SUBMIT' then
  if r.author_id is distinct from actor or r.status<>'DRAFT' then raise exception 'Save your draft before submitting.';end if;
  update public.student_progress_reports set status='SUBMITTED',updated_at=now() where id=r.id returning * into r;
 elsif act in('RETURN','FINALIZE') then
  if not public.has_permission('academics.assessments.approve') or(r.author_id=actor and not public.has_permission('academics.sessions.manage')) or(r.status<>'SUBMITTED' and not(r.status='DRAFT' and r.author_id=actor and public.has_permission('academics.sessions.manage'))) then raise exception 'Administrator review required.';end if;
  if length(note) not between 5 and 1000 then raise exception 'A review note of 5–1000 characters is required.';end if;
  update public.student_progress_reports set status=case when act='FINALIZE' then 'FINAL' else 'RETURNED' end,snapshot=case when act='FINALIZE' then public.student_progress_evidence(r.student_id,r.batch_id,r.starts_on,r.ends_on) else snapshot end,review_note=note,reviewer_id=actor,finalized_at=case when act='FINALIZE' then now() end,updated_at=now() where id=r.id returning * into r;
 else raise exception 'Unsupported report action.';end if;
 result:=jsonb_build_object('id',r.id,'message','Saved successfully.');insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'STUDENT_PROGRESS_REPORT',r.id::text,act,coalesce(nullif(note,''),'Prepared student report from approved academic evidence'),old,to_jsonb(r),req);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
create function public.student_progress_workspace(p_page int default 1,p_status text default 'ALL',p_report_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_status not in('ALL','DRAFT','SUBMITTED','RETURNED','FINAL') then raise exception 'Choose valid filter/page.';end if;
 with visible as(select r.*,p.display_name author_name,rv.display_name reviewer_name from public.student_progress_reports r join public.profiles p on p.id=r.author_id left join public.profiles rv on rv.id=r.reviewer_id where public.can_prepare_batch_report(r.batch_id) and(p_status='ALL' or r.status=p_status) and(p_report_id is null or r.id=p_report_id)),paged as(select * from visible order by updated_at desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('page',p_page,'total',(select count(*) from visible),'rows',coalesce((select jsonb_agg(to_jsonb(p) order by updated_at desc,id) from paged p),'[]'),'canReview',public.has_permission('academics.assessments.approve'),'canFinalizeOwn',public.has_permission('academics.sessions.manage') and public.has_permission('academics.assessments.approve'),
 'batches',coalesce((select jsonb_agg(to_jsonb(x)) from(select b.id,b.name label from public.batches b where p_report_id is null and public.can_prepare_batch_report(b.id) order by b.name,b.id limit 100)x),'[]'),
 'students','[]'::jsonb) into result;return result;
end $$;
revoke all on function public.can_prepare_batch_report(uuid),public.student_progress_evidence(uuid,uuid,date,date),public.student_progress_command(jsonb),public.student_progress_workspace(int,text,uuid) from public,anon,authenticated;
grant execute on function public.student_progress_command(jsonb),public.student_progress_workspace(int,text,uuid) to authenticated;
create function public.student_progress_student_choices(p_batch_id uuid,p_search text default '',p_page int default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not public.can_prepare_batch_report(p_batch_id) then raise exception 'Assigned batch access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or length(coalesce(p_search,''))>100 then raise exception 'Choose a valid search/page.';end if;
 with visible as(select distinct s.id,s.student_no||' · '||s.full_name label from public.enrollments e join public.students s on s.id=e.student_id where e.batch_id=p_batch_id and(coalesce(p_search,'')='' or position(lower(p_search) in lower(s.full_name||' '||s.student_no))>0)),paged as(select * from visible order by label,id limit 50 offset(p_page-1)*50)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(x) order by label,id) from paged x),'[]'),'more',(select count(*) from visible)>p_page*50) into result;return result;
end $$;
revoke all on function public.student_progress_student_choices(uuid,text,int) from public,anon;
grant execute on function public.student_progress_student_choices(uuid,text,int) to authenticated;
notify pgrst,'reload schema';

create trigger finalized_progress_immutable before update on public.student_progress_reports for each row execute function public.protect_final_academic_document();
create index question_documents_review on public.class_question_documents(status,updated_at desc,id);
create index question_documents_session on public.class_question_documents(session_id,updated_at desc);
create index progress_reports_review on public.student_progress_reports(status,updated_at desc,id);
create index progress_reports_batch on public.student_progress_reports(batch_id,updated_at desc);
