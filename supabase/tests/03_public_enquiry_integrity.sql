begin;
do $$ declare req uuid:=gen_random_uuid(); first jsonb; repeated jsonb; payload jsonb;
begin
 payload:=jsonb_build_object('studentName','Public test','guardianName','Guardian test','mobile','01712345678','consentToContact',true,'classId','UNVERIFIED_CLASS','offeringId','not-a-real-offering');
 first:=public.receive_public_enquiry(req,payload);
 repeated:=public.receive_public_enquiry(req,payload);
 if first is distinct from repeated or (select count(*) from public.enquiries where request_id=req)<>1 then raise exception 'Retry created duplicate enquiry'; end if;
 if exists(select 1 from public.people where full_name='Public test') then raise exception 'Unverified application created a Person'; end if;
 begin
  perform public.receive_public_enquiry(req,payload||jsonb_build_object('studentName','Changed'));
  raise exception 'Changed retry accepted';
 exception when raise_exception then if sqlerrm='Changed retry accepted' then raise; end if; end;
 if has_table_privilege('anon','public.enquiries','SELECT') or has_table_privilege('authenticated','public.enquiries','INSERT') then raise exception 'Private application table exposed'; end if;
 if has_function_privilege('anon','public.search_enquiries(text,integer)','EXECUTE') then raise exception 'Anonymous private search exposed'; end if;
 if jsonb_typeof(public.public_application_choices()->'classes')<>'array' then raise exception 'Public choices invalid'; end if;
end $$;
rollback;
