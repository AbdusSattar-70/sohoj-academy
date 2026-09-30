alter table public.admission_cases drop constraint admission_cases_status_check;
alter table public.admission_cases add constraint admission_cases_status_check check(status in('DRAFT','READY','ACCEPTED','BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT','CANCELLED','CLOSED_ENROLLMENT'));
create or replace function public.close_student_enrollment(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare e public.enrollments; today date; mode text:=p_input->>'mode'; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('students.manage') then raise exception 'Student management permission required.'; end if;
 if mode not in('WITHDRAWN','COMPLETED') or mode is null or length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Choose withdrawal or completion and record the reason.'; end if;
 -- Match admission command lock order to keep financial and enrollment mutations consistent.
 perform 1 from public.admission_cases where enrollment_id=(p_input->>'enrollment_id')::uuid for update;
 select * into e from public.enrollments where id=(p_input->>'enrollment_id')::uuid and student_id=(p_input->>'student_id')::uuid for update;
 if e.id is null then raise exception 'Enrollment not found for this student.'; end if;
 if e.status<>'ACTIVE' then return jsonb_build_object('id',e.id,'message','Enrollment is already closed.'); end if;
 select timezone(timezone,now())::date into today from public.organizations where id=e.organization_id;
 if today<e.admission_date then raise exception 'Enrollment start is in the future. Cancel the admission instead.'; end if;
 before_data:=to_jsonb(e);
 update public.enrollments set status=mode::public.enrollment_status,ended_on=today where id=e.id;
 update public.admission_cases set status='CLOSED_ENROLLMENT' where enrollment_id=e.id and status='ACTIVE_ENROLLMENT';
 if not exists(select 1 from public.enrollments where student_id=e.student_id and status='ACTIVE') then update public.students set status='INACTIVE' where id=e.student_id; end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ENROLLMENT',e.id::text,mode,p_input->>'reason',before_data,jsonb_build_object('status',mode,'ended_on',today,'student_id',e.student_id));
 return jsonb_build_object('id',e.id,'message','Enrollment closed. Future recurring billing stops; existing invoices, payments and due balances remain.');
end $$;
revoke all on function public.close_student_enrollment(jsonb) from public,anon;
grant execute on function public.close_student_enrollment(jsonb) to authenticated;
