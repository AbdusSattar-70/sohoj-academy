begin;
do $$ declare aid uuid; teacher uuid:=gen_random_uuid(); begin
 select id into aid from public.academies limit 1;
 insert into public.academic_resource_windows(academy_id,resource_kind,resource_id,weekday,starts,ends)
 values(aid,'TEACHER',teacher,0,'07:00','08:00'),(aid,'TEACHER',teacher,0,'08:00','09:00');
 if not public.resource_window_covers(aid,'TEACHER',teacher,'2026-10-11T07:00:00+06:00','2026-10-11T09:00:00+06:00') then raise exception 'Adjacent windows do not cover the class'; end if;
 if public.resource_window_covers(aid,'TEACHER',teacher,'2026-10-12T07:00:00+06:00','2026-10-12T09:00:00+06:00') then raise exception 'Wrong weekday accepted'; end if;
 if public.resource_window_covers(aid,'ROOM',teacher,'2026-10-11T07:00:00+06:00','2026-10-11T09:00:00+06:00') then raise exception 'Wrong resource kind accepted'; end if;
 update public.academic_resource_windows set is_active=false where resource_id=teacher and starts='08:00';
 if public.resource_window_covers(aid,'TEACHER',teacher,'2026-10-11T07:00:00+06:00','2026-10-11T09:00:00+06:00') then raise exception 'Inactive window accepted'; end if;
 update public.academic_resource_windows set is_active=true,starts='08:01' where resource_id=teacher and starts='08:00';
 if public.resource_window_covers(aid,'TEACHER',teacher,'2026-10-11T07:00:00+06:00','2026-10-11T09:00:00+06:00') then raise exception 'Gap accepted'; end if;
 if has_function_privilege('anon','public.preview_academic_schedule(jsonb)','EXECUTE') then raise exception 'Anonymous schedule preview exposed'; end if;
end $$;
rollback;
