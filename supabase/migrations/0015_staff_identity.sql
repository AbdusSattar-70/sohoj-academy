-- Central Staff identity foundation.
--
-- Staff is the canonical person/employment identity. "Teacher" is a role
-- assignment, not a parallel person model. The legacy teachers table remains
-- temporarily as a read-only compatibility bridge for existing class_sessions.

create type public.staff_status as enum ('ACTIVE','INACTIVE');
create type public.staff_employment_type as enum (
  'FULL_TIME',
  'PART_TIME',
  'CONTRACT',
  'VISITING',
  'OTHER'
);
create type public.staff_employment_status as enum (
  'ACTIVE',
  'ON_LEAVE',
  'ENDED'
);

create sequence if not exists public.staff_number_seq start 1;

create or replace function public.generate_staff_no()
returns text
language sql
as $$
  select 'STF-' || lpad(nextval('public.staff_number_seq')::text, 6, '0');
$$;

create table public.staff (
  id uuid primary key default gen_random_uuid(),
  staff_no text not null unique default public.generate_staff_no(),
  profile_id uuid unique references public.profiles(id),
  full_name text not null,
  name_bn text,
  mobile text,
  alternate_mobile text,
  email text,
  address text,
  status public.staff_status not null default 'ACTIVE',
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index staff_name_idx on public.staff (lower(full_name));
create index staff_mobile_idx on public.staff (
  regexp_replace(coalesce(mobile,''), '\D', '', 'g')
);

create table public.staff_role_catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  name_bn text,
  is_teaching_role boolean not null default false,
  is_active boolean not null default true,
  system_managed boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.staff_role_catalog (
  code,
  name,
  name_bn,
  is_teaching_role
)
values
  ('ADMINISTRATOR','Administrator','প্রশাসক',false),
  ('OPERATOR','Operator','অপারেটর',false),
  ('TEACHER','Teacher','শিক্ষক',true),
  ('COUNSELLOR','Counsellor','কাউন্সেলর',false),
  ('ACCOUNTANT','Accountant','হিসাবরক্ষক',false),
  ('SUPPORT','Support Staff','সহায়ক কর্মী',false)
on conflict (code) do update
set
  name = excluded.name,
  name_bn = excluded.name_bn,
  is_teaching_role = excluded.is_teaching_role;

create table public.staff_employments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  employment_type public.staff_employment_type not null default 'PART_TIME',
  starts_on date not null default current_date,
  ends_on date,
  status public.staff_employment_status not null default 'ACTIVE',
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create unique index one_open_employment_per_staff
on public.staff_employments(staff_id)
where status in ('ACTIVE','ON_LEAVE') and ends_on is null;

create table public.staff_role_assignments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  role_id uuid not null references public.staff_role_catalog(id),
  effective_from date not null default current_date,
  effective_to date,
  is_primary boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique (staff_id, role_id, effective_from)
);

create unique index one_open_primary_role_per_staff
on public.staff_role_assignments(staff_id)
where is_primary and effective_to is null;

create table public.staff_subject_assignments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  subject_id uuid not null references public.subjects(id),
  effective_from date not null default current_date,
  effective_to date,
  is_primary boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique (staff_id, subject_id, effective_from)
);

-- ---------------------------------------------------------------------------
-- Migrate existing teachers without changing historical teacher UUIDs.
-- Using the same UUID for staff and teacher makes the compatibility bridge
-- deterministic and lets class_sessions migrate safely.
-- ---------------------------------------------------------------------------

insert into public.staff (
  id,
  profile_id,
  full_name,
  mobile,
  status,
  created_at
)
select
  t.id,
  t.profile_id,
  t.name,
  t.mobile,
  case when t.is_active then 'ACTIVE'::public.staff_status
       else 'INACTIVE'::public.staff_status end,
  t.created_at
from public.teachers t
on conflict (id) do nothing;

insert into public.staff_employments (
  staff_id,
  employment_type,
  starts_on,
  status,
  created_at
)
select
  t.id,
  'PART_TIME'::public.staff_employment_type,
  t.created_at::date,
  case when t.is_active
    then 'ACTIVE'::public.staff_employment_status
    else 'ENDED'::public.staff_employment_status
  end,
  t.created_at
from public.teachers t
where not exists (
  select 1
  from public.staff_employments e
  where e.staff_id = t.id
);

insert into public.staff_role_assignments (
  staff_id,
  role_id,
  effective_from,
  is_primary,
  created_at
)
select
  t.id,
  rc.id,
  t.created_at::date,
  true,
  t.created_at
from public.teachers t
join public.staff_role_catalog rc on rc.code = 'TEACHER'
where not exists (
  select 1
  from public.staff_role_assignments ra
  where ra.staff_id = t.id
    and ra.role_id = rc.id
    and ra.effective_to is null
);

insert into public.staff_subject_assignments (
  staff_id,
  subject_id,
  effective_from,
  is_primary
)
select
  ts.teacher_id,
  ts.subject_id,
  coalesce(t.created_at::date, current_date),
  false
from public.teacher_subjects ts
join public.teachers t on t.id = ts.teacher_id
where not exists (
  select 1
  from public.staff_subject_assignments sa
  where sa.staff_id = ts.teacher_id
    and sa.subject_id = ts.subject_id
    and sa.effective_to is null
);

alter table public.teachers
  add column if not exists staff_id uuid unique references public.staff(id);

update public.teachers
set staff_id = id
where staff_id is null;

alter table public.teachers
  alter column staff_id set not null;

alter table public.class_sessions
  add column if not exists staff_id uuid references public.staff(id);

update public.class_sessions
set staff_id = teacher_id
where teacher_id is not null
  and staff_id is null;

alter table public.class_sessions
  add constraint class_sessions_staff_teacher_identity_check
  check (
    teacher_id is null
    or staff_id is null
    or teacher_id = staff_id
  ) not valid;

alter table public.class_sessions
  validate constraint class_sessions_staff_teacher_identity_check;

create index class_sessions_staff_idx on public.class_sessions(staff_id);

-- Keep legacy teacher_id and canonical staff_id synchronized while older
-- scheduling code is migrated.
create or replace function public.sync_class_session_staff_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.staff_id is not null and new.teacher_id is null then
    if not exists (
      select 1 from public.teachers t
      where t.id = new.staff_id
        and t.staff_id = new.staff_id
    ) then
      raise exception 'Selected staff member is not assigned the Teacher role.';
    end if;
    new.teacher_id := new.staff_id;
  elsif new.teacher_id is not null and new.staff_id is null then
    new.staff_id := new.teacher_id;
  elsif new.teacher_id is distinct from new.staff_id then
    raise exception 'Class session teacher identity is inconsistent.';
  end if;

  return new;
end;
$$;

drop trigger if exists sync_class_session_staff_identity_trigger
on public.class_sessions;

create trigger sync_class_session_staff_identity_trigger
before insert or update of teacher_id, staff_id
on public.class_sessions
for each row
execute function public.sync_class_session_staff_identity();

-- A teaching-subject assignment is valid only while the staff member has an
-- open Teacher role assignment.
create or replace function public.enforce_staff_subject_teacher_role()
returns trigger
language plpgsql
set search_path = public
as $
begin
  if not exists (
    select 1
    from public.staff_role_assignments ra
    join public.staff_role_catalog rc on rc.id = ra.role_id
    where ra.staff_id = new.staff_id
      and rc.code = 'TEACHER'
      and ra.effective_to is null
  ) then
    raise exception 'Teaching subjects can only be assigned to staff with an active Teacher role.';
  end if;

  return new;
end;
$;

drop trigger if exists enforce_staff_subject_teacher_role_trigger
on public.staff_subject_assignments;

create trigger enforce_staff_subject_teacher_role_trigger
before insert or update of staff_id, subject_id, effective_to
on public.staff_subject_assignments
for each row
execute function public.enforce_staff_subject_teacher_role();

-- ---------------------------------------------------------------------------
-- Staff creation is transactional and creates the legacy Teacher bridge only
-- when the chosen business role is TEACHER.
-- ---------------------------------------------------------------------------

create or replace function public.create_staff_member(
  p_input jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role public.app_role;
  v_staff public.staff;
  v_role_catalog public.staff_role_catalog;
  v_employment public.staff_employments;
  v_role_assignment public.staff_role_assignments;
  v_role_code text;
  v_employment_type public.staff_employment_type;
  v_starts_on date;
  v_subject_id uuid;
  v_subject_ids jsonb;
  v_profile_id uuid;
  v_correlation_id uuid := gen_random_uuid();
  v_mobile text;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user;

  if v_role <> 'ADMIN' then
    raise exception 'Administrator access is required to create staff.';
  end if;

  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Staff request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_input->>'full_name','')), '') is null then
    raise exception 'Staff name is required.';
  end if;

  v_role_code := upper(btrim(coalesce(p_input->>'role_code','')));
  select *
    into v_role_catalog
  from public.staff_role_catalog
  where code = v_role_code
    and is_active;

  if v_role_catalog.id is null then
    raise exception 'Select an active staff role.';
  end if;

  begin
    v_employment_type := coalesce(
      nullif(p_input->>'employment_type','')::public.staff_employment_type,
      'PART_TIME'::public.staff_employment_type
    );
    v_starts_on := coalesce(
      nullif(p_input->>'starts_on','')::date,
      current_date
    );
    v_profile_id := nullif(p_input->>'profile_id','')::uuid;
  exception when others then
    raise exception 'Staff employment or account information is invalid.';
  end;

  v_mobile := nullif(btrim(coalesce(p_input->>'mobile','')), '');

  if v_mobile is not null and exists (
    select 1
    from public.staff s
    where regexp_replace(coalesce(s.mobile,''), '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and s.status = 'ACTIVE'
  ) then
    raise exception 'An active staff member already uses this mobile number.';
  end if;

  if v_profile_id is not null and not exists (
    select 1 from public.profiles p where p.id = v_profile_id
  ) then
    raise exception 'Linked account profile was not found.';
  end if;

  perform set_config('app.correlation_id', v_correlation_id::text, true);

  insert into public.staff (
    profile_id,
    full_name,
    name_bn,
    mobile,
    alternate_mobile,
    email,
    address,
    status,
    notes,
    created_by
  )
  values (
    v_profile_id,
    btrim(p_input->>'full_name'),
    nullif(btrim(coalesce(p_input->>'name_bn','')), ''),
    v_mobile,
    nullif(btrim(coalesce(p_input->>'alternate_mobile','')), ''),
    nullif(lower(btrim(coalesce(p_input->>'email',''))), ''),
    nullif(btrim(coalesce(p_input->>'address','')), ''),
    'ACTIVE',
    nullif(btrim(coalesce(p_input->>'notes','')), ''),
    v_user
  )
  returning * into v_staff;

  insert into public.staff_employments (
    staff_id,
    employment_type,
    starts_on,
    status,
    created_by
  )
  values (
    v_staff.id,
    v_employment_type,
    v_starts_on,
    'ACTIVE',
    v_user
  )
  returning * into v_employment;

  insert into public.staff_role_assignments (
    staff_id,
    role_id,
    effective_from,
    is_primary,
    created_by
  )
  values (
    v_staff.id,
    v_role_catalog.id,
    v_starts_on,
    true,
    v_user
  )
  returning * into v_role_assignment;

  if v_role_catalog.is_teaching_role then
    insert into public.teachers (
      id,
      staff_id,
      profile_id,
      name,
      mobile,
      is_active
    )
    values (
      v_staff.id,
      v_staff.id,
      v_profile_id,
      v_staff.full_name,
      v_staff.mobile,
      true
    );

    v_subject_ids := coalesce(p_input->'subject_ids', '[]'::jsonb);

    if jsonb_typeof(v_subject_ids) <> 'array' then
      raise exception 'Subject assignments must be an array.';
    end if;

    for v_subject_id in
      select value::text::uuid
      from jsonb_array_elements_text(v_subject_ids)
    loop
      if not exists (
        select 1 from public.subjects
        where id = v_subject_id
          and is_active
      ) then
        raise exception 'One selected subject is not active.';
      end if;

      insert into public.staff_subject_assignments (
        staff_id,
        subject_id,
        effective_from,
        created_by
      )
      values (
        v_staff.id,
        v_subject_id,
        v_starts_on,
        v_user
      );

      insert into public.teacher_subjects (
        teacher_id,
        subject_id
      )
      values (
        v_staff.id,
        v_subject_id
      )
      on conflict do nothing;
    end loop;
  end if;

  insert into public.audit_events (
    correlation_id,
    actor_id,
    actor_role,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values (
    v_correlation_id,
    v_user,
    v_role,
    'STAFF',
    v_staff.id::text,
    'CREATE',
    jsonb_build_object(
      'staff_id', v_staff.id,
      'staff_no', v_staff.staff_no,
      'employment_id', v_employment.id,
      'role_assignment_id', v_role_assignment.id,
      'role_code', v_role_catalog.code,
      'employment_type', v_employment.employment_type
    ),
    jsonb_build_object('workflow', 'CREATE_STAFF_MEMBER')
  );

  return jsonb_build_object(
    'staff_id', v_staff.id,
    'staff_no', v_staff.staff_no,
    'employment_id', v_employment.id,
    'role_assignment_id', v_role_assignment.id,
    'role_code', v_role_catalog.code,
    'correlation_id', v_correlation_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Security and audit.
-- ---------------------------------------------------------------------------

alter table public.staff enable row level security;
alter table public.staff_role_catalog enable row level security;
alter table public.staff_employments enable row level security;
alter table public.staff_role_assignments enable row level security;
alter table public.staff_subject_assignments enable row level security;

grant select on public.staff, public.staff_role_catalog, public.staff_employments,
  public.staff_role_assignments, public.staff_subject_assignments to authenticated;

create policy "staff read staff directory"
on public.staff for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin manage staff"
on public.staff for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read role catalog"
on public.staff_role_catalog for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin manage role catalog"
on public.staff_role_catalog for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read employments"
on public.staff_employments for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin manage employments"
on public.staff_employments for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read role assignments"
on public.staff_role_assignments for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin manage role assignments"
on public.staff_role_assignments for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read subject assignments"
on public.staff_subject_assignments for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin manage subject assignments"
on public.staff_subject_assignments for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

revoke insert, update, delete on public.teachers, public.teacher_subjects from authenticated;
revoke delete on public.staff, public.staff_role_catalog, public.staff_employments,
  public.staff_role_assignments, public.staff_subject_assignments from authenticated;

revoke all on function public.create_staff_member(jsonb) from public;
grant execute on function public.create_staff_member(jsonb) to authenticated;

drop trigger if exists audit_event_staff on public.staff;
drop trigger if exists audit_event_staff_employments on public.staff_employments;
drop trigger if exists audit_event_staff_role_assignments on public.staff_role_assignments;
drop trigger if exists audit_event_staff_subject_assignments on public.staff_subject_assignments;

create trigger audit_event_staff
after insert or update on public.staff
for each row execute function public.audit_critical_business_row();

create trigger audit_event_staff_employments
after insert or update on public.staff_employments
for each row execute function public.audit_critical_business_row();

create trigger audit_event_staff_role_assignments
after insert or update on public.staff_role_assignments
for each row execute function public.audit_critical_business_row();

create trigger audit_event_staff_subject_assignments
after insert or update on public.staff_subject_assignments
for each row execute function public.audit_critical_business_row();

comment on table public.teachers is
  'Legacy compatibility bridge. Canonical staff identity lives in public.staff; Teacher is a staff role assignment.';
comment on table public.teacher_subjects is
  'Legacy compatibility bridge. Canonical teaching-subject assignments live in public.staff_subject_assignments.';
