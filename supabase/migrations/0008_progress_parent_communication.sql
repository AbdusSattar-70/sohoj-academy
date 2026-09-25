-- Weekly progress monitoring and parent communication security.

alter table public.weekly_monitoring enable row level security;
alter table public.parent_communications enable row level security;

create policy "staff read weekly monitoring" on public.weekly_monitoring
for select to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff manage weekly monitoring" on public.weekly_monitoring
for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff read parent communications" on public.parent_communications
for select to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff manage parent communications" on public.parent_communications
for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
