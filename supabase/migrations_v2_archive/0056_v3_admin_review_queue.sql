-- V3 unified Admin Review Queue.
-- Teacher submissions are visible here by type and can be opened at their
-- owning academic workspace. The underlying command remains the source of
-- authorization and finalization.

create or replace function public.admin_review_queue()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  with queue as (
    select
      a.id,
      'ATTENDANCE'::text as review_type,
      a.id::text as entity_id,
      ('Attendance · ' || b.name || ' · ' || s.name) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(ar.requested_at, a.created_at) as submitted_at,
      a.revision,
      '/dashboard/academics/sessions/' || cs.id::text as href
    from public.attendance_submissions a
    left join public.approval_requests ar
      on ar.id = a.approval_id
    join public.class_sessions cs on cs.id = a.session_id
    join public.batches b on b.id = cs.batch_id
    join public.subjects s on s.id = cs.subject_id
    join public.profiles p on p.id = a.recorded_by
    left join public.staff st on st.profile_id = a.recorded_by
    where a.status = 'SUBMITTED'
      and public.has_permission('academics.attendance.approve')

    union all

    select
      l.id,
      'CLASS_LOG'::text as review_type,
      l.id::text as entity_id,
      ('Class log · ' || b.name || ' · ' || s.name) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      l.submitted_at as submitted_at,
      l.revision,
      '/dashboard/academics/sessions/' || cs.id::text as href
    from public.class_logs l
    join public.class_sessions cs on cs.id = l.session_id
    join public.batches b on b.id = cs.batch_id
    join public.subjects s on s.id = cs.subject_id
    join public.profiles p on p.id = l.authored_by
    left join public.staff st on st.profile_id = l.authored_by
    where l.status = 'SUBMITTED'
      and public.has_permission('academics.attendance.approve')

    union all

    select
      r.id,
      'ASSESSMENT_RESULTS'::text as review_type,
      r.id::text as entity_id,
      ('Assessment results · ' || a.title) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(r.submitted_at, r.created_at) as submitted_at,
      r.revision,
      '/dashboard/academics/assessments?assessment=' || a.id::text as href
    from public.assessment_result_submissions r
    join public.academic_assessments a on a.id = r.assessment_id
    join public.batches b on b.id = a.batch_id
    join public.subjects s on s.id = a.subject_id
    join public.profiles p on p.id = r.author_id
    left join public.staff st on st.profile_id = r.author_id
    where r.status = 'SUBMITTED'
      and public.has_permission('academics.assessments.approve')

    union all

    select
      q.id,
      'QUESTION'::text as review_type,
      q.id::text as entity_id,
      ('Question · ' || q.topic) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(q.submitted_at, q.created_at) as submitted_at,
      q.revision,
      '/dashboard/academics/questions?item=' || q.id::text as href
    from public.question_bank_items q
    join public.batches b on b.id = q.batch_id
    join public.subjects s on s.id = q.subject_id
    join public.profiles p on p.id = q.author_id
    left join public.staff st on st.profile_id = q.author_id
    where q.status = 'SUBMITTED'
      and public.has_permission('academics.assessments.approve')
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'reviewType', review_type,
        'entityId', entity_id,
        'title', title,
        'teacherName', teacher_name,
        'teacherStaffNo', teacher_staff_no,
        'batchName', batch_name,
        'subjectName', subject_name,
        'submittedAt', submitted_at,
        'revision', revision,
        'href', href
      )
      order by submitted_at asc, review_type, entity_id
    ),
    '[]'::jsonb
  )
  from queue;
$$;

revoke all on function public.admin_review_queue()
from public, anon;

grant execute on function public.admin_review_queue()
to authenticated;
