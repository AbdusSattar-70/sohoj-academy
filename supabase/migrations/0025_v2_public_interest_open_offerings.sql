-- Public interest/admission constrained to open programme offerings.
-- Adds offering + intent on prospects and hard validation in submit_public_interest.

alter table public.prospects
  add column if not exists interested_offering_id uuid references public.programme_offerings(id),
  add column if not exists submission_intent text not null default 'interest'
    check (submission_intent in ('interest', 'admission'));

create index if not exists prospects_interested_offering_idx
  on public.prospects(interested_offering_id)
  where interested_offering_id is not null;

comment on column public.prospects.interested_offering_id is
  'Optional programme offering selected on the public interest/admission form.';
comment on column public.prospects.submission_intent is
  'interest = short enquiry; admission = fuller application intent.';

-- Extend public listing with academic context used by forms.
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
      o.class_id,
      o.program_id,
      o.group_id,
      o.branch_id,
      o.academic_year_id,
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

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;
