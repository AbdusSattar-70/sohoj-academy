-- Dated enrollment periods retain the roster used by historical sessions.
create table public.academic_batch_enrollments (
 id uuid primary key default gen_random_uuid(),academy_id uuid not null references public.academies,
 person_id uuid not null,run_id uuid not null,batch_id uuid not null,
 starts_on date not null,ends_before date,revision integer not null default 1,
 check(ends_before is null or ends_before>=starts_on),
 foreign key(person_id,academy_id) references public.people(id,academy_id),
 foreign key(run_id,academy_id) references public.programme_runs(id,academy_id),
 foreign key(batch_id,academy_id) references public.teaching_batches(id,academy_id)
);
create unique index one_open_batch_per_offering on public.academic_batch_enrollments(person_id,run_id) where ends_before is null;
create index academic_enrollment_roster on public.academic_batch_enrollments(batch_id,starts_on,ends_before);
insert into public.academic_batch_enrollments(academy_id,person_id,run_id,batch_id,starts_on,ends_before)
 select s.academy_id,s.person_id,b.run_id,s.batch_id,r.starts_on,case when s.is_active then null else r.starts_on end from public.batch_seats s join public.teaching_batches b on b.id=s.batch_id join public.programme_runs r on r.id=b.run_id;

create table public.academic_session_attendance (
 session_id uuid not null,person_id uuid not null,academy_id uuid not null,
 status text not null check(status in('PRESENT','ABSENT','LATE','EXCUSED')),note text check(length(note)<=500),
 recorded_by uuid not null references public.account_profiles,recorded_at timestamptz not null default now(),
 primary key(session_id,person_id),foreign key(session_id,academy_id) references public.academic_sessions(id,academy_id),
 foreign key(person_id,academy_id) references public.people(id,academy_id)
);
alter table public.academic_sessions add column homework text not null default '' check(length(homework)<=3000);
alter table public.academic_sessions add column homework_due_on date;
alter table public.academic_sessions add column assessment_kind text not null default 'NONE' check(assessment_kind in('NONE','CLASS_TEST','QUIZ','PRACTICE','MODEL_TEST'));
alter table public.academic_sessions add column assessment_note text not null default '' check(length(assessment_note)<=3000);

create function public.academic_batch_roster(p_batch uuid,p_on text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view');own_id uuid; day_value date:=p_on::date;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 if not public.can_operate('academics.manage') and not exists(select 1 from public.academic_sessions s where s.academy_id=aid and s.batch_id=p_batch and s.teacher_id=own_id and(s.starts_at at time zone 'Asia/Dhaka')::date=day_value) then raise exception 'This class is not assigned to you.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'personNo',p.person_no) order by p.full_name,p.id) from public.people p where p.academy_id=aid and exists(select 1 from public.academic_batch_enrollments e where e.academy_id=aid and e.batch_id=p_batch and e.person_id=p.id and e.starts_on<=day_value and(e.ends_before is null or day_value<e.ends_before))),'[]');
end $$;
create function public.academic_session_work(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare detail jsonb:=public.academic_session_detail(p_id); item jsonb:=detail->'sessions'->0; own_id uuid; roster jsonb; attendance jsonb; edit_allowed boolean;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 roster:=public.academic_batch_roster((item->>'batch_id')::uuid,((item->>'starts_at')::timestamptz at time zone 'Asia/Dhaka')::date::text);
 select coalesce(jsonb_agg(jsonb_build_object('personId',a.person_id,'status',a.status,'note',a.note)),'[]') into attendance from public.academic_session_attendance a where a.session_id=p_id;
 edit_allowed:=(item->>'teacher_id')::uuid=own_id and item->>'status' in('SCHEDULED','RETURNED');
 return jsonb_build_object('session',item,'roster',roster,'attendance',attendance,'canEdit',edit_allowed,'manage',detail->'manage');
end $$;
create function public.save_academic_session_work(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; s public.academic_sessions; roster jsonb; mark jsonb; prior jsonb; result jsonb; cmd text:=p_payload->>'action'; day_value date; actual_start_value timestamptz; actual_end_value timestamptz; ids uuid[]:='{}';
begin
 perform public.check_change_reason(p_payload->>'reason');
 if cmd not in('DRAFT','SUBMIT') then raise exception 'Choose save draft or submit report.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'SESSION_WORK_'||cmd,p_payload);if prior is not null then return prior; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 select * into s from public.academic_sessions where id=(p_payload->>'id')::uuid and academy_id=aid for update;
 if not found or s.teacher_id is distinct from own_id or s.status not in('SCHEDULED','RETURNED') then raise exception 'Only the assigned teacher can edit this open class.'; end if;
 if s.revision is distinct from (p_payload->>'revision')::int then raise exception 'Class changed. Reload before saving.'; end if;
 day_value:=(s.starts_at at time zone 'Asia/Dhaka')::date;
 roster:=public.academic_batch_roster(s.batch_id,day_value::text);
 if jsonb_typeof(p_payload->'attendance') is distinct from 'array' or jsonb_array_length(p_payload->'attendance')>200 then raise exception 'Choose attendance for the displayed roster.'; end if;
 for mark in select value from jsonb_array_elements(p_payload->'attendance') loop
  if not exists(select 1 from jsonb_array_elements(roster) x where x->>'id'=mark->>'personId') or (mark->>'personId')::uuid=any(ids) then raise exception 'Attendance must match this dated roster, without duplicates.'; end if;
  if day_value>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Attendance cannot be taken for a future class.'; end if;
  ids:=array_append(ids,(mark->>'personId')::uuid);
  insert into public.academic_session_attendance(session_id,person_id,academy_id,status,note,recorded_by) values(s.id,(mark->>'personId')::uuid,aid,mark->>'status',nullif(mark->>'note',''),auth.uid()) on conflict(session_id,person_id) do update set status=excluded.status,note=excluded.note,recorded_by=excluded.recorded_by,recorded_at=now();
 end loop;
 if cmd='SUBMIT' and cardinality(ids)<>jsonb_array_length(roster) then raise exception 'Record attendance for every enrolled student before submitting.'; end if;
 actual_start_value:=nullif(p_payload->>'actualStart','')::timestamptz;actual_end_value:=nullif(p_payload->>'actualEnd','')::timestamptz;
 if actual_start_value is not null or actual_end_value is not null then
  if actual_start_value is null or actual_end_value is null or actual_end_value<=actual_start_value or actual_end_value>now() or (actual_start_value at time zone 'Asia/Dhaka')::date<>day_value or (actual_end_value at time zone 'Asia/Dhaka')::date<>day_value then raise exception 'Actual times must describe the completed class on its scheduled day.'; end if;
 end if;
 update public.academic_sessions set actual_start=actual_start_value,actual_end=actual_end_value,report=nullif(p_payload->>'report',''),homework=coalesce(p_payload->>'homework',''),homework_due_on=nullif(p_payload->>'homeworkDueOn','')::date,assessment_kind=coalesce(p_payload->>'assessmentKind','NONE'),assessment_note=coalesce(p_payload->>'assessmentNote',''),revision=revision+1 where id=s.id returning * into s;
 if s.homework_due_on is not null and s.homework_due_on<day_value then raise exception 'Homework due date cannot be before the class date.'; end if;
 if cmd='SUBMIT' then
  result:=public.academic_command(gen_random_uuid(),jsonb_build_object('action','SUBMIT','id',s.id,'revision',s.revision,'actualStart',p_payload->>'actualStart','actualEnd',p_payload->>'actualEnd','report',p_payload->>'report','reason',p_payload->>'reason'));
 else result:=jsonb_build_object('id',s.id,'revision',s.revision,'status',s.status); end if;
 return public.finish_operation(p_request_id,'SESSION_WORK_'||cmd,p_payload,result,'ACADEMIC_SESSION',s.id,null);
end $$;
create function public.academic_teaching_summary(p_from text,p_through text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_from::date is null or p_through::date is null or p_through::date-p_from::date not between 0 and 366 then raise exception 'Choose a valid date range up to 367 days.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return coalesce((select jsonb_agg(to_jsonb(x)) from(select p.id,p.full_name name,count(*) classes,round(sum(extract(epoch from(s.actual_end-s.actual_start)))/3600,2) approved_hours from public.academic_sessions s join public.people p on p.id=s.teacher_id where s.academy_id=aid and s.status='APPROVED' and(manager or s.teacher_id=own_id) and(s.starts_at at time zone 'Asia/Dhaka')::date between p_from::date and p_through::date group by p.id,p.full_name order by p.full_name)x),'[]');
end $$;

create function public.change_student_batch(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); person uuid:=(p_payload->>'personId')::uuid; bid uuid:=(p_payload->>'batchId')::uuid; b public.teaching_batches; existing public.academic_batch_enrollments; day_value date:=(p_payload->>'fromDate')::date; cmd text:=p_payload->>'action'; prior jsonb; result jsonb; identity uuid;
begin
 perform public.check_change_reason(p_payload->>'reason');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'PLACEMENT_'||cmd,p_payload);if prior is not null then return prior; end if;
 if cmd not in('ENROLL','TRANSFER','CLOSE') or day_value is null then raise exception 'Choose a placement action and effective date.'; end if;
 if cmd in('TRANSFER','CLOSE') and day_value>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Transfer or close on the effective day; future changes must not release seats early.'; end if;
 select * into b from public.teaching_batches where id=bid and academy_id=aid for update;
 if not found or (cmd<>'CLOSE' and not b.is_active) then raise exception 'Choose an active academy batch.'; end if;
 if not exists(select 1 from public.people p join public.person_responsibilities r on r.person_id=p.id and r.responsibility='STUDENT' and r.is_active where p.id=person and p.academy_id=aid and p.is_active) then raise exception 'Choose an existing active student; use admission to create a new student.'; end if;
 if not exists(select 1 from public.programme_runs r where r.id=b.run_id and r.is_active and day_value between r.starts_on and r.ends_on) then raise exception 'Effective date must be inside the active offering dates.'; end if;
 select * into existing from public.academic_batch_enrollments where person_id=person and run_id=b.run_id and ends_before is null for update;
 if cmd='ENROLL' and existing.id is not null then raise exception 'Student already enrolled. Use transfer or close.'; end if;
 if cmd in('TRANSFER','CLOSE') and existing.id is null then raise exception 'No open enrollment exists in this offering.'; end if;
 if cmd='TRANSFER' and existing.batch_id=bid then raise exception 'Select a different batch in the same offering.'; end if;
 if cmd='CLOSE' and existing.batch_id<>bid then raise exception 'Select the student current batch.'; end if;
 if existing.id is not null then
  if existing.revision is distinct from (p_payload->>'revision')::int then raise exception 'Enrollment changed. Reload before continuing.'; end if;
  if day_value<existing.starts_on or exists(select 1 from public.academic_session_attendance a join public.academic_sessions s on s.id=a.session_id where a.person_id=person and s.batch_id=existing.batch_id and(s.starts_at at time zone 'Asia/Dhaka')::date>=day_value) then raise exception 'Choose a date after recorded attendance; history cannot be rewritten.'; end if;
  update public.academic_batch_enrollments set ends_before=day_value,revision=revision+1 where id=existing.id;
  update public.batch_seats set is_active=false where person_id=person and batch_id=existing.batch_id;
 end if;
 if cmd<>'CLOSE' then
  if (select count(*) from public.batch_seats where batch_id=bid and is_active)>=b.capacity then raise exception 'Batch is full.'; end if;
  insert into public.academic_batch_enrollments(academy_id,person_id,run_id,batch_id,starts_on) values(aid,person,b.run_id,bid,day_value) returning id into identity;
  insert into public.batch_seats(batch_id,person_id,academy_id) values(bid,person,aid) on conflict(batch_id,person_id) do update set is_active=true;
 else identity:=existing.id; end if;
 result:=jsonb_build_object('id',identity);
 return public.finish_operation(p_request_id,'PLACEMENT_'||cmd,p_payload,result,'BATCH_ENROLLMENT',identity,to_jsonb(existing));
end $$;
create function public.academic_placement_register(p_batch uuid,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); run uuid;
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select run_id into run from public.teaching_batches where id=p_batch and academy_id=aid;
 if run is null then raise exception 'Batch not found.'; end if;
 return jsonb_build_object('page',p_page,'total',(select count(*) from public.academic_batch_enrollments where academy_id=aid and batch_id=p_batch),
 'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select e.*,p.full_name name from public.academic_batch_enrollments e join public.people p on p.id=e.person_id where e.academy_id=aid and e.batch_id=p_batch order by e.ends_before nulls first,p.full_name,e.id limit 25 offset(p_page-1)*25)x),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name)) from public.teaching_batches b where b.run_id=run and b.is_active),'[]'));
end $$;
do $$ declare relation text; begin
 foreach relation in array array['academic_batch_enrollments','academic_session_attendance'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
  execute format('create trigger no_delete before delete on public.%I for each row execute function public.reject_record_delete()',relation);
 end loop;
end $$;
revoke all on function public.academic_batch_roster(uuid,text),public.academic_session_work(uuid),public.save_academic_session_work(uuid,jsonb),public.academic_teaching_summary(text,text),public.change_student_batch(uuid,jsonb),public.academic_placement_register(uuid,integer) from public,anon;
grant execute on function public.academic_batch_roster(uuid,text),public.academic_session_work(uuid),public.save_academic_session_work(uuid,jsonb),public.academic_teaching_summary(text,text),public.change_student_batch(uuid,jsonb),public.academic_placement_register(uuid,integer) to authenticated;

create or replace function public.academic_session_command(p_request_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid; cmd text:=p_payload->>'action'; prior jsonb; sid uuid; old public.academic_sessions; s public.academic_sessions; rid uuid; tid uuid; bid uuid; sub uuid; st timestamptz; en timestamptz; own_id uuid; result jsonb; eid uuid:=gen_random_uuid(); message text; room public.academic_rooms;
begin
 aid:=public.require_operation('academics.view'); perform public.check_change_reason(p_payload->>'reason');
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_'||cmd,p_payload); if prior is not null then return prior; end if;
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 if cmd not in('SUBMIT') then perform public.require_operation('academics.manage'); end if;
 sid:=nullif(p_payload->>'id','')::uuid;
 if cmd='ROOM' then
  if length(btrim(coalesce(p_payload->>'name','')))<2 then raise exception 'Enter a classroom name.'; end if;
  rid:=coalesce(sid,gen_random_uuid());
  if sid is not null then
   select * into room from public.academic_rooms where id=sid and academy_id=aid for update;
   if not found or room.revision is distinct from (p_payload->>'revision')::int then raise exception 'Room changed. Reload before editing.'; end if;
   if exists(select 1 from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id where s.room_id=sid and s.status<>'CANCELLED' and s.ends_at>now() and (not coalesce((p_payload->>'active')::boolean,true) or b.capacity>(p_payload->>'capacity')::int)) then raise exception 'Move future classes before closing or reducing this room.'; end if;
  end if;
  insert into public.academic_rooms(id,academy_id,name,capacity,is_active) values(rid,aid,btrim(p_payload->>'name'),(p_payload->>'capacity')::int,coalesce((p_payload->>'active')::boolean,true)) on conflict(id) do update set name=excluded.name,capacity=excluded.capacity,is_active=excluded.is_active,revision=academic_rooms.revision+1;
  result:=jsonb_build_object('id',rid);
 elsif cmd='CONTACT' then
  bid:=(p_payload->>'batchId')::uuid;
  if not exists(select 1 from public.teaching_batches where id=bid and academy_id=aid) then raise exception 'Select an academy batch.'; end if;
  if coalesce((p_payload->>'consent')::boolean,false)=false then raise exception 'Notification consent must be recorded.'; end if;
  insert into public.academic_notification_contacts(academy_id,batch_id,name,email) values(aid,bid,btrim(p_payload->>'name'),lower(btrim(p_payload->>'email'))) on conflict(batch_id,email) do update set name=excluded.name,is_active=true,consent_recorded_at=now() returning id into rid;
  result:=jsonb_build_object('id',rid);
 else
  if sid is not null then
   select * into old from public.academic_sessions where id=sid and academy_id=aid for update;
   if not found or old.revision is distinct from (p_payload->>'revision')::int then raise exception 'Session changed. Reload before continuing.'; end if;
  end if;
  if cmd in('SUBMIT','APPROVE') and old.id is not null then
   if exists(select 1 from jsonb_array_elements(public.academic_batch_roster(old.batch_id,((old.starts_at at time zone 'Asia/Dhaka')::date)::text)) member where not exists(select 1 from public.academic_session_attendance a where a.session_id=old.id and a.person_id=(member->>'id')::uuid)) then raise exception 'Record every student attendance under Class work before submission or approval.'; end if;
  end if;
  if cmd='APPROVE' and exists(select 1 from public.academic_sessions other where other.academy_id=aid and other.teacher_id=old.teacher_id and other.id<>old.id and other.status='APPROVED' and other.actual_start<old.actual_end and other.actual_end>old.actual_start) then raise exception 'Actual teaching time overlaps another approved class. Return the report for correction.'; end if;
  if cmd='SUBMIT' then
   if old.id is null or old.teacher_id is distinct from own_id or old.status not in('SCHEDULED','RETURNED') then raise exception 'Only the assigned teacher can submit an open session.'; end if;
   if length(btrim(coalesce(p_payload->>'report','')))<3 then raise exception 'Record what was taught.'; end if;
   st:=(p_payload->>'actualStart')::timestamptz; en:=(p_payload->>'actualEnd')::timestamptz;
   if st is null or en is null or en>now() or (st at time zone 'Asia/Dhaka')::date<>(old.starts_at at time zone 'Asia/Dhaka')::date or (en at time zone 'Asia/Dhaka')::date<>(old.starts_at at time zone 'Asia/Dhaka')::date then raise exception 'Actual times must describe the completed class day.'; end if;
   update public.academic_sessions set actual_start=st,actual_end=en,report=p_payload->>'report',status='SUBMITTED',revision=revision+1 where id=sid returning * into s;
  elsif cmd in('APPROVE','RETURN') then
   if old.id is null or old.status<>'SUBMITTED' then raise exception 'Review a submitted report first.'; end if;
   if old.teacher_id=own_id and cmd='APPROVE' then raise exception 'Another administrator must review your own teaching report.'; end if;
   update public.academic_sessions set status=case cmd when 'APPROVE' then 'APPROVED' else 'RETURNED' end,review_note=p_payload->>'reason',revision=revision+1 where id=sid returning * into s;
  elsif cmd='CANCEL' then
   if old.id is null or old.status not in('SCHEDULED','RETURNED') then raise exception 'Only an open session can be cancelled.'; end if;
   update public.academic_sessions set status='CANCELLED',revision=revision+1 where id=sid returning * into s;
  elsif cmd in('CREATE','CHANGE','MAKEUP') then
   if cmd='CREATE' and sid is not null then raise exception 'New sessions cannot overwrite existing records.'; end if;
   if cmd='CHANGE' and(old.id is null or old.status not in('SCHEDULED','RETURNED')) then raise exception 'Only an open session can be changed.'; end if;
   if cmd='MAKEUP' and(old.id is null or old.status<>'CANCELLED') then raise exception 'Makeup must link to a cancelled class.'; end if;
   bid:=(p_payload->>'batchId')::uuid; sub:=(p_payload->>'subjectId')::uuid; tid:=(p_payload->>'teacherId')::uuid; rid:=(p_payload->>'roomId')::uuid; st:=(p_payload->>'start')::timestamptz; en:=(p_payload->>'end')::timestamptz;
   if cmd='CHANGE' and (bid is distinct from old.batch_id or sub is distinct from old.subject_id) then raise exception 'Class changes retain the original batch and subject.'; end if;
   if cmd='MAKEUP' and (bid is distinct from old.batch_id or sub is distinct from old.subject_id) then raise exception 'Makeup retains the original batch and subject.'; end if;
   if not exists(select 1 from public.teaching_batches b join public.programme_runs pr on pr.id=b.run_id join public.run_subjects rs on rs.run_id=pr.id and rs.subject_id=sub and rs.is_active join public.academic_rooms r on r.id=rid and r.academy_id=b.academy_id and r.is_active and r.capacity>=b.capacity where b.id=bid and b.academy_id=aid and b.is_active and pr.is_active and (st at time zone 'Asia/Dhaka')::date between pr.starts_on and pr.ends_on and (en at time zone 'Asia/Dhaka')::date between pr.starts_on and pr.ends_on) then raise exception 'Check programme dates, its subject, active batch and room capacity.'; end if;
   if not exists(select 1 from public.people p join public.person_responsibilities x on x.person_id=p.id and x.is_active and x.responsibility='TEACHER' where p.id=tid and p.academy_id=aid and p.is_active) then raise exception 'Select an active teacher.'; end if;
   if exists(select 1 from public.academic_sessions x where x.academy_id=aid and x.status<>'CANCELLED' and (cmd<>'CHANGE' or x.id<>sid) and x.starts_at<en and x.ends_at>st and(x.batch_id=bid or x.teacher_id=tid or x.room_id=rid)) then raise exception 'Batch, teacher or room is already booked at this time.'; end if;
   if cmd='CHANGE' then update public.academic_sessions set batch_id=bid,subject_id=sub,teacher_id=tid,room_id=rid,starts_at=st,ends_at=en,revision=revision+1 where id=sid returning * into s;
   else insert into public.academic_sessions(academy_id,batch_id,subject_id,teacher_id,room_id,starts_at,ends_at,original_session_id) values(aid,bid,sub,tid,rid,st,en,case when cmd='MAKEUP' then sid end) returning * into s; end if;
  else raise exception 'Unknown academic action.'; end if;
  if cmd in('CREATE','CHANGE','CANCEL','MAKEUP') then
   message:='Class update: '||cmd||E'\nBangladesh time: '||to_char(s.starts_at at time zone 'Asia/Dhaka','DD Mon YYYY HH24:MI')||'–'||to_char(s.ends_at at time zone 'Asia/Dhaka','HH24:MI')||E'\nBatch: '||(select name from public.teaching_batches where id=s.batch_id)||E'\nRoom: '||(select name from public.academic_rooms where id=s.room_id)||E'\nReason: '||(p_payload->>'reason');
   if old.id is not null then message:=message||E'\nPrevious time: '||to_char(old.starts_at at time zone 'Asia/Dhaka','DD Mon YYYY HH24:MI'); end if;
   insert into public.academic_email_queue(academy_id,session_id,event_id,recipient,subject,body)
   select aid,s.id,eid,lower(email),'Class update · '||cmd,message from(
    select email from public.academic_notification_contacts where batch_id=s.batch_id and is_active
    union select email from public.people where id in(s.teacher_id,old.teacher_id) and academy_id=aid and is_active
   ) recipients where email is not null and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' on conflict do nothing;
  end if;
  result:=to_jsonb(s); rid:=s.id;
 end if;
 return public.finish_operation(p_request_id,'ACADEMIC_'||cmd,p_payload,result,'ACADEMIC_OPERATION',rid,to_jsonb(old));
end $$;
