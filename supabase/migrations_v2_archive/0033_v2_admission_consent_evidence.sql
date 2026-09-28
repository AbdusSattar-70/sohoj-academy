-- Signed forms stay in a private, append-only bucket. A metadata receipt binds the
-- stored bytes to the case, file hash, guardian signing date and receiving staff.
create table public.admission_consent_documents (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admission_cases(id),
  version integer not null check(version>0),
  storage_path text not null unique,
  sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png')),
  file_size integer not null check(file_size between 1 and 5242880),
  guardian_signed_on date not null,
  student_signed boolean not null default false,
  received_by uuid not null references public.profiles(id),
  received_at timestamptz not null default now(),
  unique(admission_id,version),
  check(storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$')
);
create index admission_consent_case_idx on public.admission_consent_documents(admission_id,version desc);
alter table public.admission_consent_documents enable row level security;
grant select on public.admission_consent_documents to authenticated;
revoke insert,update,delete on public.admission_consent_documents from anon,authenticated;
create policy admission_consent_staff_read on public.admission_consent_documents
  for select to authenticated using(public.has_permission('admissions.view'));

create or replace function public.record_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid := auth.uid(); c public.admission_cases; d public.admission_consent_documents;
  path text := p_input->>'storage_path'; present boolean; signed_on date;
begin
  if actor is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
  if path is null or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' then raise exception 'Invalid signed document path.'; end if;
  select * into c from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  if c.id is null or c.status not in ('DRAFT','READY') then raise exception 'Consent can be received only before acceptance.'; end if;
  if split_part(path,'/',1)<>c.id::text then raise exception 'Document path must match the admission case.'; end if;
  signed_on := (p_input->>'guardian_signed_on')::date;
  if signed_on is null or signed_on>current_date then raise exception 'Enter a valid guardian signing date.'; end if;
  if (p_input->>'sha256') !~ '^[0-9a-f]{64}$' or (p_input->>'file_size')::integer not between 1 and 5242880
    or p_input->>'mime_type' not in ('application/pdf','image/jpeg','image/png') then raise exception 'Invalid signed document metadata.'; end if;
  if to_regclass('storage.objects') is null then raise exception 'Private document storage is unavailable.'; end if;
  execute 'select exists(select 1 from storage.objects where bucket_id=$1 and name=$2 and owner_id=$3)'
    into present using 'admission-consent',path,actor::text;
  if not present then raise exception 'Upload the signed form before recording its receipt.'; end if;
  insert into public.admission_consent_documents(admission_id,version,storage_path,sha256,mime_type,file_size,guardian_signed_on,student_signed,received_by)
  values(c.id,(select coalesce(max(version),0)+1 from public.admission_consent_documents where admission_id=c.id),
    path,p_input->>'sha256',p_input->>'mime_type',(p_input->>'file_size')::integer,signed_on,
    coalesce((p_input->>'student_signed')::boolean,false),actor) returning * into d;
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',d.id::text,'RECEIVE_SIGNED_FORM',to_jsonb(d));
  return jsonb_build_object('id',d.id,'version',d.version);
end $$;
revoke all on function public.record_admission_consent(jsonb) from public,anon;
grant execute on function public.record_admission_consent(jsonb) to authenticated;

-- Storage is an installed Supabase schema. The guard lets isolated PostgreSQL
-- schema tests apply the migration while live Supabase configures the bucket.
do $$ begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('admission-consent','admission-consent',false,5242880,array['application/pdf','image/jpeg','image/png'])
    on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
    execute $policy$create policy admission_consent_upload on storage.objects
      for insert to authenticated with check (
        bucket_id='admission-consent' and public.has_permission('admissions.create')
        and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$'
        and exists(select 1 from public.admission_cases c where c.id::text=split_part(name,'/',1) and c.status in ('DRAFT','READY'))
      )$policy$;
    execute $policy$create policy admission_consent_download on storage.objects
      for select to authenticated using (bucket_id='admission-consent' and public.has_permission('admissions.view'))$policy$;
  end if;
end $$;
