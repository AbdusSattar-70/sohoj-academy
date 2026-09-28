create or replace function public.academic_workspace(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare manager boolean:=public.has_permission('academics.sessions.manage');curriculum_manager boolean:=public.has_permission('academics.curriculum.manage');begin
 if auth.uid() is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'Choose a date range of at most 367 days.';end if;
 return jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where is_active),'[]'::jsonb),
 'batches',case when manager or curriculum_manager then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||y.name,'branchId',b.branch_id,'capacity',b.capacity)) from public.batches b join public.academic_years y on y.id=b.academic_year_id where b.is_active and b.offering_id is not null),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.subjects where is_active),'[]'::jsonb),
 'teachers',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id),'[]'::jsonb))) from public.staff s where s.status='ACTIVE' and exists(select 1 from public.staff_subject_assignments where staff_id=s.id)),'[]'::jsonb) else '[]'::jsonb end,
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'branchId',branch_id,'capacity',capacity)) from public.academic_rooms),'[]'::jsonb),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'batchId',v.batch_id,'subjectId',v.subject_id,'batch',b.name,'subject',s.name,'version',v.version,'title',v.title,'units',v.units) order by v.published_at desc) from public.curriculum_versions v join public.batches b on b.id=v.batch_id join public.subjects s on s.id=v.subject_id where manager or curriculum_manager or exists(select 1 from public.class_sessions x where x.curriculum_version_id=v.id and public.can_access_class_session(x.id))),'[]'::jsonb),
 'routines',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'batchId',r.batch_id,'subjectId',r.subject_id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'weekday',r.weekday,'startTime',r.start_time,'endTime',r.end_time,'startsOn',r.starts_on,'endsOn',r.ends_on,'retired',r.retired_at is not null)) from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where manager or t.profile_id=auth.uid()),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'room',rm.name,'date',x.session_date,'startTime',to_char(x.starts_at at time zone o.timezone,'HH24:MI'),'endTime',to_char(x.ends_at at time zone o.timezone,'HH24:MI'),'timezone',o.timezone,'status',x.status,'scope',x.planned_scope,'latestStatus',(select status from public.attendance_submissions where session_id=x.id order by revision desc limit 1),'approvedRevision',(select max(revision) from public.attendance_submissions where session_id=x.id and status='APPROVED')) order by x.starts_at) from public.class_sessions x join public.batches b on b.id=x.batch_id join public.organizations o on o.id=b.organization_id join public.subjects s on s.id=x.subject_id join public.staff t on t.id=x.teacher_id join public.academic_rooms rm on rm.id=x.room_id where x.session_date between p_from and p_to and public.can_access_class_session(x.id)),'[]'::jsonb)
 );
end; $$;
create or replace function public.class_session_workspace(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare cs public.class_sessions;latest public.attendance_submissions;roster jsonb;begin
 if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.';end if;
 select * into cs from public.class_sessions where id=p_session_id;
 select * into latest from public.attendance_submissions where session_id=cs.id order by revision desc limit 1;
 if latest.id is null then
  select coalesce(jsonb_agg(jsonb_build_object('enrollment_id',e.id,'student_id',s.id,'number',s.student_no,'name',s.full_name) order by s.student_no),'[]'::jsonb) into roster from public.enrollments e join public.students s on s.id=e.student_id where e.batch_id=cs.batch_id and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date) and e.status in('ACTIVE','WITHDRAWN','COMPLETED');
 else roster:=latest.entries;end if;
 return jsonb_build_object(
 'session',(select jsonb_build_object('id',cs.id,'batch',b.name,'subject',s.name,'teacher',t.full_name,'teacherProfileId',t.profile_id,'room',r.name,'date',cs.session_date,'canRecordNow',cs.starts_at<=now(),'startsAt',cs.starts_at,'endsAt',cs.ends_at,'timezone',o.timezone,'status',cs.status,'scope',cs.planned_scope,'cancellationReason',cs.cancellation_reason,'curriculumTitle',v.title,'curriculumVersion',v.version,'units',coalesce(v.units,'[]'::jsonb)) from public.batches b join public.organizations o on o.id=b.organization_id cross join public.subjects s cross join public.staff t cross join public.academic_rooms r left join public.curriculum_versions v on v.id=cs.curriculum_version_id where b.id=cs.batch_id and s.id=cs.subject_id and t.id=cs.teacher_id and r.id=cs.room_id),
 'roster',roster,
 'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'revision',a.revision,'status',a.status,'entries',a.entries,'reason',a.reason,'recordedBy',a.recorded_by,'recorder',p.display_name,'createdAt',a.created_at,'approvalId',a.approval_id,'decisionNote',r.decision_note) order by a.revision desc) from public.attendance_submissions a join public.profiles p on p.id=a.recorded_by left join public.approval_requests r on r.id=a.approval_id where a.session_id=cs.id),'[]'::jsonb)
 );
end; $$;
revoke all on function public.academic_workspace(date,date),public.class_session_workspace(uuid) from public,anon;
grant execute on function public.academic_workspace(date,date),public.class_session_workspace(uuid) to authenticated;
