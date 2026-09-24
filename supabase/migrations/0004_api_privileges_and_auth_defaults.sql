-- Restore API privileges required by Supabase RLS.
-- RLS controls which rows authenticated users may access; table grants allow
-- PostgREST to attempt those operations in the first place.

grant usage on schema public to authenticated;

grant select on public.profiles to authenticated;
grant select, insert, update on public.students to authenticated;
grant select, insert, update on public.guardians to authenticated;
grant select, insert, update on public.student_guardians to authenticated;
grant select, insert, update on public.enrollments to authenticated;

grant select on public.academic_years to authenticated;
grant select on public.programs to authenticated;
grant select on public.classes to authenticated;
grant select on public.subjects to authenticated;
grant select on public.batches to authenticated;
grant select on public.teachers to authenticated;
grant select on public.teacher_subjects to authenticated;

grant usage, select on sequence public.student_number_seq to authenticated;

-- New auth users should start with the least-privileged application role.
-- Staff roles are assigned explicitly by an administrator.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1), 'User'),
    'STUDENT'::public.app_role
  )
  on conflict (id) do nothing;

  return new;
end;
$$;
