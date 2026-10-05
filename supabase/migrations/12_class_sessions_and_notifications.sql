-- Generated from supabase/schema/academics/12_class_sessions_and_notifications.sql; edit the source, then run pnpm db:baseline.
-- Dated class operations; recurrence never rewrites completed sessions.
create table public.academic_rooms (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 name text not null, capacity int not null check(capacity between 1 and 500), is_active boolean not null default true,
 revision int not null default 1, unique(id,academy_id), unique(academy_id,name)
);
create table public.academic_sessions (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 batch_id uuid not null, subject_id uuid not null, teacher_id uuid not null, room_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, status text not null default 'SCHEDULED' check(status in('SCHEDULED','CANCELLED','SUBMITTED','RETURNED','APPROVED')),
 original_session_id uuid references public.academic_sessions, actual_start timestamptz, actual_end timestamptz,
 report text, review_note text, revision int not null default 1,
 foreign key(batch_id,academy_id) references public.teaching_batches(id,academy_id),
 foreign key(subject_id,academy_id) references public.directory_entries(id,academy_id),
 foreign key(teacher_id,academy_id) references public.people(id,academy_id),
 foreign key(room_id,academy_id) references public.academic_rooms(id,academy_id),
 check(ends_at>starts_at and ends_at-starts_at<=interval '12 hours'),
 check(actual_end is null or (actual_start is not null and actual_end>actual_start and actual_end-actual_start<=interval '12 hours'))
);
create index academic_sessions_time on public.academic_sessions(academy_id,starts_at);
create table public.academic_notification_contacts (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 batch_id uuid not null, name text not null, email text not null check(email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 is_active boolean not null default true, consent_recorded_at timestamptz not null default now(),
 foreign key(batch_id,academy_id) references public.teaching_batches(id,academy_id), unique(batch_id,email)
);
create table public.academic_email_queue (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 session_id uuid not null references public.academic_sessions, event_id uuid not null,
 recipient text not null, subject text not null, body text not null,
 status text not null default 'PENDING' check(status in('PENDING','PROCESSING','ACCEPTED','FAILED','UNCERTAIN')),
 attempts int not null default 0, created_at timestamptz not null default now(), available_at timestamptz not null default now(),
 lease_id uuid, lease_until timestamptz, provider_id text, last_error text,
 unique(event_id,recipient)
);
create function public.academic_workspace(p_page integer default 1) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid; own_id uuid; manager boolean;
begin
 aid:=public.require_operation('academics.view'); manager:=public.can_operate('academics.manage');
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'rooms',coalesce((select jsonb_agg(to_jsonb(r) order by name) from public.academic_rooms r where academy_id=aid),'[]'::jsonb),
 'batches',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||pr.title)) from public.teaching_batches b join public.programme_runs pr on pr.id=b.run_id where b.academy_id=aid and b.is_active),'[]'::jsonb) else '[]'::jsonb end,
 'teachers',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name)) from public.people p where p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities x where x.person_id=p.id and x.responsibility='TEACHER' and x.is_active)),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name)) from public.directory_entries d where d.academy_id=aid and d.kind='SUBJECT' and d.is_active),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(to_jsonb(x)) from (select s.*, b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.academy_id=aid and (manager or s.teacher_id=own_id) order by s.starts_at desc,s.id limit 25 offset (greatest(1,least(p_page,10000))-1)*25) x),'[]'::jsonb),
 'total',(select count(*) from public.academic_sessions s where s.academy_id=aid and(manager or s.teacher_id=own_id)),
 'queue',case when manager then coalesce((select jsonb_agg(to_jsonb(x)) from(select id,session_id,recipient,status,attempts,last_error,created_at from public.academic_email_queue where academy_id=aid order by created_at desc limit 25)x),'[]'::jsonb) else '[]'::jsonb end);
end $$;
create function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb
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
  if cmd='SUBMIT' then
   if old.id is null or old.teacher_id is distinct from own_id or old.status not in('SCHEDULED','RETURNED') then raise exception 'Only the assigned teacher can submit an open session.'; end if;
   if length(btrim(coalesce(p_payload->>'report','')))<3 then raise exception 'Record what was taught.'; end if;
   st:=(p_payload->>'actualStart')::timestamptz; en:=(p_payload->>'actualEnd')::timestamptz;
   if st is null or en is null or en>now() or (st at time zone 'Asia/Dhaka')::date<>(old.starts_at at time zone 'Asia/Dhaka')::date then raise exception 'Actual times must describe the completed class day.'; end if;
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
create function public.claim_academic_emails() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 update public.academic_email_queue set status='UNCERTAIN',last_error='Delivery needs manual investigation after the provider idempotency window.' where status in('PENDING','PROCESSING','FAILED') and created_at<now()-interval '23 hours';
 with selected as(select id from public.academic_email_queue where created_at>now()-interval '23 hours' and attempts<5 and available_at<=now() and(status in('PENDING','FAILED') or(status='PROCESSING' and lease_until<now())) order by created_at for update skip locked limit 10), claimed as(update public.academic_email_queue q set status='PROCESSING',attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes' from selected where q.id=selected.id returning q.*) select coalesce(jsonb_agg(to_jsonb(claimed)),'[]'::jsonb) into result from claimed;
 return result;
end $$;
create function public.finish_academic_email(p_id uuid,p_lease uuid,p_provider_id text,p_error text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.academic_email_queue set status=case when p_error is null then 'ACCEPTED' else 'FAILED' end,provider_id=p_provider_id,last_error=left(p_error,500),available_at=now()+interval '10 minutes',lease_until=null where id=p_id and lease_id=p_lease and status='PROCESSING';
end $$;
alter table public.academic_rooms enable row level security;
revoke all on public.academic_rooms from anon,authenticated;
create trigger prevent_delete before delete on public.academic_rooms for each row execute function public.reject_record_delete();
alter table public.academic_sessions enable row level security;
revoke all on public.academic_sessions from anon,authenticated;
create trigger prevent_delete before delete on public.academic_sessions for each row execute function public.reject_record_delete();
alter table public.academic_notification_contacts enable row level security;
revoke all on public.academic_notification_contacts from anon,authenticated;
create trigger prevent_delete before delete on public.academic_notification_contacts for each row execute function public.reject_record_delete();
alter table public.academic_email_queue enable row level security;
revoke all on public.academic_email_queue from anon,authenticated;
create trigger prevent_delete before delete on public.academic_email_queue for each row execute function public.reject_record_delete();
revoke all on function public.academic_workspace(integer),public.academic_command(uuid,jsonb) from public,anon;
grant execute on function public.academic_workspace(integer),public.academic_command(uuid,jsonb) to authenticated;
revoke all on function public.claim_academic_emails(),public.finish_academic_email(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.claim_academic_emails(),public.finish_academic_email(uuid,uuid,text,text) to service_role;
