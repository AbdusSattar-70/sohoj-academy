-- Programme offering public controls: showcase copy, website visibility,
-- accepting applications (independent of operational ACTIVE status).

alter table public.programme_offerings
  add column if not exists showcase_title text,
  add column if not exists showcase_title_bn text,
  add column if not exists showcase_description text,
  add column if not exists showcase_description_bn text,
  add column if not exists showcase_eyebrow text,
  add column if not exists showcase_eyebrow_bn text,
  add column if not exists showcase_icon text,
  add column if not exists showcase_sort_order integer not null default 100,
  add column if not exists is_website_visible boolean not null default false,
  add column if not exists is_accepting_applications boolean not null default false,
  add column if not exists applications_open_on date,
  add column if not exists applications_close_on date;

comment on column public.programme_offerings.is_website_visible is
  'When true and status=ACTIVE, offering may appear on the public homepage.';
comment on column public.programme_offerings.is_accepting_applications is
  'When true, public interest/admission forms may select this offering. Independent of operational status.';
comment on column public.programme_offerings.showcase_sort_order is
  'Lower numbers appear first on the public homepage.';

create index if not exists programme_offerings_website_visible_idx
  on public.programme_offerings (showcase_sort_order, created_at)
  where is_website_visible = true and status = 'ACTIVE';

create table if not exists public.programme_offering_subjects (
  offering_id uuid not null references public.programme_offerings(id) on delete cascade,
  subject_id uuid not null references public.subjects(id),
  sort_order integer not null default 0,
  primary key (offering_id, subject_id)
);

alter table public.programme_offering_subjects enable row level security;

grant select on public.programme_offering_subjects to authenticated, anon;
revoke insert, update, delete on public.programme_offering_subjects from authenticated, anon;

drop policy if exists offering_subjects_read on public.programme_offering_subjects;
create policy offering_subjects_read on public.programme_offering_subjects
for select to authenticated, anon
using (
  exists (
    select 1 from public.programme_offerings o
    where o.id = offering_id
      and (
        o.is_website_visible
        or public.has_permission('academics.view')
        or public.has_permission('admissions.view')
      )
  )
);

create or replace function public.update_programme_offering_public_controls(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_correlation uuid := gen_random_uuid();
  v_offering_id uuid;
  v_reason text;
  v_row public.programme_offerings%rowtype;
  v_before jsonb;
  v_title text;
  v_title_bn text;
  v_desc text;
  v_desc_bn text;
  v_eyebrow text;
  v_eyebrow_bn text;
  v_icon text;
  v_sort integer;
  v_visible boolean;
  v_accepting boolean;
  v_open date;
  v_close date;
  v_subjects jsonb;
  v_subject_id uuid;
  v_idx integer := 0;
begin
  if v_actor is null then
    raise exception 'Authentication required.';
  end if;
  if not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to curate programme public controls.';
  end if;

  v_offering_id := nullif(p_input->>'offering_id', '')::uuid;
  v_reason := nullif(trim(coalesce(p_input->>'reason', '')), '');
  v_title := nullif(trim(coalesce(p_input->>'showcase_title', '')), '');
  v_title_bn := nullif(trim(coalesce(p_input->>'showcase_title_bn', '')), '');
  v_desc := nullif(trim(coalesce(p_input->>'showcase_description', '')), '');
  v_desc_bn := nullif(trim(coalesce(p_input->>'showcase_description_bn', '')), '');
  v_eyebrow := nullif(trim(coalesce(p_input->>'showcase_eyebrow', '')), '');
  v_eyebrow_bn := nullif(trim(coalesce(p_input->>'showcase_eyebrow_bn', '')), '');
  v_icon := nullif(trim(coalesce(p_input->>'showcase_icon', '')), '');
  v_sort := coalesce((p_input->>'showcase_sort_order')::integer, 100);
  v_visible := coalesce((p_input->>'is_website_visible')::boolean, false);
  v_accepting := coalesce((p_input->>'is_accepting_applications')::boolean, false);
  v_open := nullif(p_input->>'applications_open_on', '')::date;
  v_close := nullif(p_input->>'applications_close_on', '')::date;
  v_subjects := coalesce(p_input->'subject_ids', '[]'::jsonb);

  if v_offering_id is null then
    raise exception 'Offering is required.';
  end if;
  if v_reason is null or length(v_reason) < 5 then
    raise exception 'A short reason (at least 5 characters) is required for the audit trail.';
  end if;
  if v_sort < 0 or v_sort > 9999 then
    raise exception 'Sort order must be between 0 and 9999.';
  end if;
  if v_icon is not null and v_icon not in (
    'clipboard-check', 'graduation-cap', 'users-round',
    'book-open-check', 'line-chart', 'shield-check'
  ) then
    raise exception 'Unsupported showcase icon.';
  end if;
  if v_open is not null and v_close is not null and v_close < v_open then
    raise exception 'Applications close date must be on or after the open date.';
  end if;

  select * into v_row from public.programme_offerings where id = v_offering_id for update;
  if not found then
    raise exception 'Programme offering not found.';
  end if;

  if v_visible and v_row.status <> 'ACTIVE' then
    raise exception 'Only ACTIVE offerings (with a published Fee Plan) can be shown on the website.';
  end if;
  if v_visible and v_title is null then
    raise exception 'Showcase title (English) is required when website visibility is enabled.';
  end if;
  if v_visible and v_desc is null then
    raise exception 'Showcase description (English) is required when website visibility is enabled.';
  end if;
  if v_accepting and v_row.status = 'RETIRED' then
    raise exception 'Retired offerings cannot accept new applications.';
  end if;

  v_before := to_jsonb(v_row);

  update public.programme_offerings set
    showcase_title = v_title,
    showcase_title_bn = v_title_bn,
    showcase_description = v_desc,
    showcase_description_bn = v_desc_bn,
    showcase_eyebrow = v_eyebrow,
    showcase_eyebrow_bn = v_eyebrow_bn,
    showcase_icon = v_icon,
    showcase_sort_order = v_sort,
    is_website_visible = v_visible,
    is_accepting_applications = v_accepting,
    applications_open_on = v_open,
    applications_close_on = v_close,
    updated_at = now()
  where id = v_offering_id
  returning * into v_row;

  delete from public.programme_offering_subjects where offering_id = v_offering_id;
  if jsonb_typeof(v_subjects) = 'array' then
    for v_idx in 0 .. greatest(jsonb_array_length(v_subjects) - 1, -1) loop
      v_subject_id := nullif(v_subjects->>v_idx, '')::uuid;
      if v_subject_id is null then
        continue;
      end if;
      if not exists (
        select 1 from public.subjects s
        where s.id = v_subject_id and s.is_active
      ) then
        raise exception 'One selected subject is not available.';
      end if;
      insert into public.programme_offering_subjects (offering_id, subject_id, sort_order)
      values (v_offering_id, v_subject_id, v_idx);
    end loop;
  end if;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_row.branch_id,
    'PROGRAMME_OFFERING',
    v_row.id::text,
    'UPDATE_PUBLIC_CONTROLS',
    v_reason,
    v_before,
    to_jsonb(v_row),
    jsonb_build_object(
      'is_website_visible', v_visible,
      'is_accepting_applications', v_accepting,
      'showcase_sort_order', v_sort,
      'subject_count', coalesce(jsonb_array_length(v_subjects), 0)
    )
  );

  return jsonb_build_object(
    'offering_id', v_row.id,
    'is_website_visible', v_row.is_website_visible,
    'is_accepting_applications', v_row.is_accepting_applications,
    'correlation_id', v_correlation
  );
end;
$$;

create or replace function public.list_public_programme_offerings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select
      o.id,
      o.code,
      o.name,
      o.showcase_title,
      o.showcase_title_bn,
      o.showcase_description,
      o.showcase_description_bn,
      o.showcase_eyebrow,
      o.showcase_eyebrow_bn,
      o.showcase_icon,
      o.showcase_sort_order,
      o.is_accepting_applications,
      o.applications_open_on,
      o.applications_close_on,
      o.created_at,
      (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', s.id,
          'code', s.code,
          'name', s.name
        ) order by pos.sort_order), '[]'::jsonb)
        from public.programme_offering_subjects pos
        join public.subjects s on s.id = pos.subject_id
        where pos.offering_id = o.id
      ) as subjects,
      (
        select jsonb_build_object(
          'billing_cycle', fp.billing_cycle,
          'currency_code', fp.currency_code,
          'components', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', c.code,
              'name', c.name,
              'amount', c.amount,
              'charge_type', c.charge_type,
              'recurrence', c.recurrence
            ) order by c.sort_order)
            from public.fee_plan_components c
            where c.fee_plan_version_id = fp.id
          ), '[]'::jsonb)
        )
        from public.fee_plan_versions fp
        where fp.offering_id = o.id and fp.status = 'ACTIVE'
        limit 1
      ) as fee_plan
    from public.programme_offerings o
    where o.is_website_visible = true
      and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at
    limit 24
  ) x;
$$;

revoke all on function public.update_programme_offering_public_controls(jsonb) from public, anon;
grant execute on function public.update_programme_offering_public_controls(jsonb) to authenticated;

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;
