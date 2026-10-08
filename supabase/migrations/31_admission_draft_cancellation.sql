-- Generated from supabase/schema/admissions/31_admission_draft_cancellation.sql; edit the source, then run pnpm db:baseline.
create function public.cancel_admission_draft(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.manage');a public.student_admissions;prior jsonb;
begin
 perform public.check_change_reason(p_input->>'reason');
 select * into a from public.student_admissions where id=(p_input->>'id')::uuid and academy_id=aid and division_id=public.current_workspace_id() for update;
 if not found then raise exception 'Draft not found in this workspace.';end if;
 prior:=public.lookup_operation(p_request_id,'CANCEL_ADMISSION_DRAFT',p_input);if prior is not null then return prior;end if;
 if a.status<>'DRAFT' or a.revision is distinct from(p_input->>'revision')::int then raise exception 'Only the current unconfirmed draft can be cancelled.';end if;
 update public.student_admissions set status='CANCELLED',revision=revision+1 where id=a.id;
 return public.finish_operation(p_request_id,'CANCEL_ADMISSION_DRAFT',p_input,jsonb_build_object('id',a.id),'ADMISSION',a.id,to_jsonb(a));
end $$;
revoke all on function public.cancel_admission_draft(uuid,jsonb) from public,anon;
grant execute on function public.cancel_admission_draft(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
