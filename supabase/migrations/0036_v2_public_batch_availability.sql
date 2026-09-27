-- Display only a current, non-reserving availability snapshot. Admission and
-- activation continue to recheck capacity under their own database locks.
do $migration$
declare
 definition text;
 old_fields text := $old$      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,$old$;
 new_fields text := $new$      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (select count(*)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as active_batch_count,
      (select coalesce(sum(bb.capacity),0)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_total_seats,
      (select coalesce(sum(greatest(bb.capacity-(select count(*) from public.enrollments e where e.batch_id=bb.id and e.status='ACTIVE'),0)),0)::integer
       from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_open_seats,$new$;
begin
 select pg_get_functiondef('public.list_public_programme_offerings()'::regprocedure) into definition;
 if position(old_fields in definition)=0 then raise exception 'Could not extend public catalogue availability; inspect RPC definition.'; end if;
 execute replace(definition,old_fields,new_fields);
end;
$migration$;
