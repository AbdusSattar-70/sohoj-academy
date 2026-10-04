create table public.finance_documents(
 id uuid primary key,entity_type text not null check(entity_type in('PURCHASE','EXPENSE','REIMBURSEMENT','ASSET')),entity_id uuid not null,
 actor_id uuid not null references public.profiles(id),object_path text not null unique,original_name text not null,mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),
 byte_size integer not null check(byte_size between 1 and 5242880),sha256 text not null check(sha256~'^[0-9a-f]{64}$'),note text not null,request_payload jsonb not null,
 status text not null default 'PENDING' check(status in('PENDING','READY')),created_at timestamptz not null default now(),ready_at timestamptz
);
create index finance_documents_entity on public.finance_documents(entity_type,entity_id,created_at desc);
alter table public.finance_documents enable row level security;
create function public.finance_document_entity_allowed(p_type text,p_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then return false;end if;
 if p_type='PURCHASE' then return exists(select 1 from public.finance_purchases p join public.organizations o on o.id=p.organization_id where p.id=p_id and o.code='SOHOJ' and o.is_active);
 elsif p_type='EXPENSE' then return exists(select 1 from public.finance_expenses e join public.organizations o on o.id=e.organization_id where e.id=p_id and o.code='SOHOJ' and o.is_active);
 end if;return false;
end $$;
revoke all on function public.finance_document_entity_allowed(text,uuid) from public,anon;
grant execute on function public.finance_document_entity_allowed(text,uuid) to authenticated;
create policy finance_documents_read on public.finance_documents for select to authenticated using(public.finance_document_entity_allowed(entity_type,entity_id));
grant select on public.finance_documents to authenticated;
revoke insert,update,delete on public.finance_documents from anon,authenticated;
create function public.guard_finance_document() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='DELETE' or old.status='READY' then raise exception 'Financial document evidence cannot be overwritten or deleted.';end if;
 if (to_jsonb(new)-'status'-'ready_at') is distinct from (to_jsonb(old)-'status'-'ready_at') or new.status<>'READY' then raise exception 'Only document completion may change.';end if;return new;end $$;
create trigger finance_document_history before update or delete on public.finance_documents for each row execute function public.guard_finance_document();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('finance-evidence','finance-evidence',false,5242880,array['application/pdf','image/jpeg','image/png']);
create function public.finance_document_storage_allowed(p_path text,p_write boolean) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.finance_documents d where d.object_path=p_path and public.finance_document_entity_allowed(d.entity_type,d.entity_id) and (not p_write or (d.status='PENDING' and d.actor_id=auth.uid())))
$$;
revoke all on function public.finance_document_storage_allowed(text,boolean) from public,anon;
grant execute on function public.finance_document_storage_allowed(text,boolean) to authenticated;
create policy finance_evidence_insert on storage.objects for insert to authenticated with check(bucket_id='finance-evidence' and public.finance_document_storage_allowed(name,true));
create policy finance_evidence_read on storage.objects for select to authenticated using(bucket_id='finance-evidence' and public.finance_document_storage_allowed(name,false));
-- No UPDATE/DELETE policy: uploads use upsert=false and linked evidence stays immutable.

create function public.finance_document_prepare(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare req uuid:=(p_input->>'request_id')::uuid;actor uuid:=auth.uid();r public.finance_documents;path text;extension text;
begin
 if not public.finance_document_entity_allowed(p_input->>'entity_type',(p_input->>'entity_id')::uuid) then raise exception 'Document access denied.';end if;
 if req is null or coalesce(length(btrim(p_input->>'note')),0) not between 5 and 1000 or coalesce(length(p_input->>'original_name'),0) not between 1 and 200 or p_input->>'sha256' is null or p_input->>'sha256' !~ '^[0-9a-f]{64}$' or (p_input->>'byte_size')::integer is null or (p_input->>'byte_size')::integer not between 1 and 5242880 then raise exception 'Invalid document details.';end if;
 extension:=case p_input->>'mime_type' when 'application/pdf' then 'pdf' when 'image/jpeg' then 'jpg' when 'image/png' then 'png' end;if extension is null then raise exception 'Only PDF, JPEG and PNG are supported.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,24));select * into r from public.finance_documents where id=req;
 if found then if r.actor_id<>actor or r.request_payload<>p_input then raise exception 'Upload identity reused with different input.';end if;return jsonb_build_object('id',r.id,'path',r.object_path,'status',r.status);end if;
 perform pg_advisory_xact_lock(hashtextextended((p_input->>'entity_type')||(p_input->>'entity_id'),24));
 if (select count(*) from public.finance_documents where entity_type=p_input->>'entity_type' and entity_id=(p_input->>'entity_id')::uuid)>=50 then raise exception 'Document limit reached for this record.';end if;
 path:=lower(p_input->>'entity_type')||'/'||(p_input->>'entity_id')||'/'||actor::text||'/'||req::text||'.'||extension;
 insert into public.finance_documents(id,entity_type,entity_id,actor_id,object_path,original_name,mime_type,byte_size,sha256,note,request_payload) values(req,p_input->>'entity_type',(p_input->>'entity_id')::uuid,actor,path,p_input->>'original_name',p_input->>'mime_type',(p_input->>'byte_size')::integer,p_input->>'sha256',btrim(p_input->>'note'),p_input) returning * into r;
 return jsonb_build_object('id',r.id,'path',r.object_path,'status',r.status);
end $$;
revoke all on function public.finance_document_prepare(jsonb) from public,anon;
grant execute on function public.finance_document_prepare(jsonb) to authenticated;

create function public.finance_document_complete(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.finance_documents;metadata_value jsonb;
begin
 select * into r from public.finance_documents where id=p_id for update;
 if r.id is null or r.actor_id is distinct from auth.uid() or not public.finance_document_entity_allowed(r.entity_type,r.entity_id) then raise exception 'Document access denied.';end if;
 if r.status='READY' then return jsonb_build_object('id',r.id,'message','Document already recorded.');end if;
 select metadata into metadata_value from storage.objects where bucket_id='finance-evidence' and name=r.object_path;
 if not found or (metadata_value->>'size')::bigint is distinct from r.byte_size::bigint or metadata_value->>'mimetype' is distinct from r.mime_type then raise exception 'Uploaded object is missing or its size/type differs. Retry the unchanged upload.';end if;
 update public.finance_documents set status='READY',ready_at=now() where id=r.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(r.id,auth.uid(),r.entity_type,r.entity_id::text,'ATTACH_DOCUMENT',r.note,jsonb_build_object('document_id',r.id,'file',r.original_name,'size',r.byte_size,'sha256',r.sha256));
 return jsonb_build_object('id',r.id,'message','Private document evidence recorded.');
end $$;
revoke all on function public.finance_document_complete(uuid) from public,anon;
grant execute on function public.finance_document_complete(uuid) to authenticated;
create function public.finance_document_workspace(p_type text,p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin if not public.finance_document_entity_allowed(p_type,p_id) then raise exception 'Document access denied.';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.original_name,'mime',d.mime_type,'size',d.byte_size,'note',d.note,'date',d.ready_at,'actor',p.display_name,'path',d.object_path) order by d.created_at desc) from public.finance_documents d join public.profiles p on p.id=d.actor_id where d.entity_type=p_type and d.entity_id=p_id and d.status='READY'),'[]'::jsonb);end $$;
revoke all on function public.finance_document_workspace(text,uuid) from public,anon;
grant execute on function public.finance_document_workspace(text,uuid) to authenticated;
create function public.finance_document_batch(p_type text,p_ids uuid[]) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare id_value uuid;result jsonb:='[]'::jsonb;
begin if p_ids is null or cardinality(p_ids)>25 then raise exception 'Request at most 25 evidence records.';end if;foreach id_value in array p_ids loop result:=result||jsonb_build_array(jsonb_build_object('entityId',id_value,'documents',public.finance_document_workspace(p_type,id_value)));end loop;return result;end $$;
revoke all on function public.finance_document_batch(text,uuid[]) from public,anon;
grant execute on function public.finance_document_batch(text,uuid[]) to authenticated;
