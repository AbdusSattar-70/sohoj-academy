-- Generated from supabase/schema/admissions/29_admission_confirmation_and_invoices.sql; edit the source, then run pnpm db:baseline.
create table public.student_invoices(
 id uuid primary key default gen_random_uuid(),invoice_no bigint generated always as identity unique,
 academy_id uuid not null references public.academies,admission_id uuid not null references public.student_admissions,
 period_start date not null,kind text not null check(kind in('INITIAL','TUITION')),
 lines jsonb not null,subtotal numeric(14,2) not null check(subtotal>=0),discount numeric(14,2) not null check(discount>=0 and discount<=subtotal),
 total numeric(14,2) not null check(total=subtotal-discount),due_on date not null,
 created_by uuid not null references public.account_profiles,created_at timestamptz not null default now(),unique(admission_id,period_start)
);
create unique index one_initial_invoice on public.student_invoices(admission_id) where kind='INITIAL';
alter table public.student_invoices enable row level security;
revoke all on public.student_invoices from public,anon,authenticated;
create trigger preserve_invoice before update or delete on public.student_invoices for each row execute function public.reject_record_delete();
create function public.finalize_admission(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.manage');a public.student_admissions;r public.programme_runs;b public.teaching_batches;d jsonb;prior jsonb;sid uuid;gid uuid;ref uuid;eid uuid;invoice uuid;day_value date;dob date;guardian_required boolean;rel text;subtotal numeric:=0;reduction numeric:=0;lines jsonb;roll_value int;name_value text;mobile_value text;
begin
 perform public.check_change_reason(p_input->>'reason');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 select * into a from public.student_admissions where id=(p_input->>'id')::uuid and academy_id=aid and division_id=public.current_workspace_id() for update;
 if not found then raise exception 'Admission not found in this workspace.';end if;
 prior:=public.lookup_operation(p_request_id,'FINALIZE_ADMISSION',p_input);if prior is not null then return prior;end if;
 if a.status<>'DRAFT' or a.revision is distinct from(p_input->>'revision')::int then raise exception 'Application changed. Refresh before confirmation.';end if;
 if coalesce((p_input->>'reviewed')::boolean,false)=false or coalesce((p_input->>'paperReceived')::boolean,false)=false then raise exception 'Review the application and confirm the signed paper form was received.';end if;
 d:=a.details;day_value:=nullif(d->>'enrollmentDate','')::date;dob:=nullif(d->>'dateOfBirth','')::date;
 select * into r from public.programme_runs where id=a.run_id and academy_id=aid and is_active;
 select * into b from public.teaching_batches where id=a.batch_id and run_id=a.run_id and academy_id=aid and is_active for update;
 if r.id is null or b.id is null or day_value is null or day_value not between r.starts_on and r.ends_on then raise exception 'Choose an active programme, batch and enrollment date inside programme dates.';end if;
 if (select count(*) from public.batch_seats where batch_id=b.id and is_active)>=b.capacity then raise exception 'Batch is full. Edit the draft and choose another batch.';end if;
 if a.fee_snapshot is null or a.fee_snapshot is distinct from public.admission_fee_snapshot(a.run_id) then raise exception 'Fees changed or are missing. Edit and save the draft to review current charges.';end if;
 if a.discount_percent>0 and(not(a.fee_snapshot->'allowedDiscounts' @> to_jsonb(array[a.discount_percent])) or length(coalesce(a.discount_reason,''))<2) then raise exception 'Choose a permitted discount and its reason.';end if;
 if dob is not null and dob>(now() at time zone 'Asia/Dhaka')::date then raise exception 'Birth date cannot be in the future.';end if;
 guardian_required:=r.guardian_rule<>'OPTIONAL' or(dob is not null and dob>day_value-interval '18 years');
 name_value:=btrim(d->>'studentName');if name_value is null or length(name_value) not between 2 and 160 then raise exception 'Enter the verified student full name.';end if;
 if coalesce((d->>'sourceVerified')::boolean,false)=false then raise exception 'Confirm Organic or the verified referrer in the draft.';end if;
 sid:=nullif(d->>'studentId','')::uuid;gid:=nullif(d->>'guardianId','')::uuid;ref:=nullif(d->>'referrerId','')::uuid;
 if ref is not null and not exists(select 1 from public.people p join public.person_responsibilities x on x.person_id=p.id and x.responsibility='REFERRER' and x.is_active where p.id=ref and p.academy_id=aid and p.is_active) then raise exception 'Choose an active academy referrer.';end if;
 if sid is null then
  if coalesce((d->>'newStudentConfirmed')::boolean,false)=false then raise exception 'Search existing people, then confirm this is a new student.';end if;
  if exists(select 1 from public.people where academy_id=aid and lower(full_name)=lower(name_value) and((dob is not null and date_of_birth=dob) or(nullif(d->>'studentMobile','') is not null and mobile=d->>'studentMobile') or(nullif(d->>'studentEmail','') is not null and lower(email)=lower(d->>'studentEmail')))) then raise exception 'Matching student found. Select the existing identity before confirming.';end if;
  insert into public.people(academy_id,full_name,full_name_bn,mobile,email,date_of_birth,present_address,permanent_address) values(aid,name_value,nullif(d->>'studentNameBn',''),nullif(d->>'studentMobile',''),nullif(lower(d->>'studentEmail'),''),dob,jsonb_build_object('line',d->>'presentAddress','locality',d->>'landmark'),jsonb_build_object('line',case when coalesce((d->>'sameAddress')::boolean,false) then d->>'presentAddress' else d->>'permanentAddress' end)) returning id into sid;
 else
  if not exists(select 1 from public.people where id=sid and academy_id=aid and is_active and full_name=name_value and mobile is not distinct from nullif(d->>'studentMobile','') and email is not distinct from nullif(lower(d->>'studentEmail'),'') and date_of_birth is not distinct from dob) then raise exception 'Existing identity differs. Select it again; correct the person record separately before admission.';end if;
 end if;
 if exists(select 1 from public.academic_batch_enrollments where person_id=sid and run_id=a.run_id and ends_before is null) then raise exception 'This student is already enrolled in the programme.';end if;
 insert into public.person_responsibilities values(sid,aid,'STUDENT',true) on conflict(person_id,responsibility) do update set is_active=true;
 if guardian_required or nullif(btrim(d->>'guardianName'),'') is not null then
  name_value:=btrim(d->>'guardianName');mobile_value:=nullif(d->>'guardianMobile','');
  select name into rel from public.directory_entries where id=nullif(d->>'relationshipId','')::uuid and academy_id=aid and kind='RELATIONSHIP' and is_active;
  if name_value is null or length(name_value)<2 or mobile_value is null or rel is null then raise exception 'Select guardian name, valid mobile and relationship.';end if;
  if gid is null then
   if coalesce((d->>'newGuardianConfirmed')::boolean,false)=false then raise exception 'Search guardians and confirm this is a new guardian.';end if;
   if exists(select 1 from public.people where academy_id=aid and lower(full_name)=lower(name_value) and mobile=mobile_value) then raise exception 'Matching guardian found. Reuse the existing guardian.';end if;
   insert into public.people(academy_id,full_name,mobile) values(aid,name_value,mobile_value) returning id into gid;
  elsif not exists(select 1 from public.people where id=gid and academy_id=aid and is_active and full_name=name_value and mobile=mobile_value) then raise exception 'Select the verified guardian identity again.';end if;
  if sid=gid then raise exception 'Student and guardian must be different people.';end if;
  insert into public.person_responsibilities values(gid,aid,'GUARDIAN',true) on conflict(person_id,responsibility) do update set is_active=true;
  update public.person_relationships set is_primary_contact=false where person_id=sid and is_primary_contact;
  insert into public.person_relationships values(sid,gid,aid,rel,true,true) on conflict(person_id,related_person_id,relationship) do update set is_active=true,is_primary_contact=true;
 elsif nullif(d->>'studentMobile','') is null and nullif(d->>'studentEmail','') is null then raise exception 'Provide the adult student’s own mobile or email.';end if;
 select coalesce(sum((x->>'amount')::numeric),0),coalesce(sum(case when x->>'type'='TUITION' then round((x->>'amount')::numeric*a.discount_percent/100,2) else 0 end),0),jsonb_agg(x||jsonb_build_object('discount',case when x->>'type'='TUITION' then round((x->>'amount')::numeric*a.discount_percent/100,2) else 0 end)) into subtotal,reduction,lines from jsonb_array_elements(a.fee_snapshot->'components') x;
 if lines is null then raise exception 'Add standard fee components before admission.';end if;
 insert into public.academic_batch_enrollments(academy_id,person_id,run_id,batch_id,starts_on) values(aid,sid,a.run_id,a.batch_id,day_value) returning id into eid;
 insert into public.batch_seats(batch_id,person_id,academy_id) values(a.batch_id,sid,aid) on conflict(batch_id,person_id) do update set is_active=true;
 select coalesce(max(roll_no),0)+1 into roll_value from public.student_admissions where batch_id=a.batch_id;
 update public.student_admissions set student_id=sid,guardian_id=gid,referrer_id=ref,enrollment_id=eid,roll_no=roll_value,status='ADMITTED',admitted_at=now(),revision=revision+1,details=details||jsonb_build_object('paperReceived',true,'paperReference',p_input->>'paperReference','paperReceivedBy',auth.uid(),'paperReceivedAt',now()) where id=a.id;
 insert into public.student_invoices(academy_id,admission_id,period_start,kind,lines,subtotal,discount,total,due_on,created_by) values(aid,a.id,day_value,'INITIAL',lines,subtotal,reduction,subtotal-reduction,day_value,auth.uid()) returning id into invoice;
 if a.enquiry_id is not null then update public.enquiries set status='CLOSED' where id=a.enquiry_id;end if;
 return public.finish_operation(p_request_id,'FINALIZE_ADMISSION',p_input,jsonb_build_object('id',a.id,'invoiceId',invoice),'ADMISSION',a.id,to_jsonb(a));
end $$;
revoke all on function public.finalize_admission(uuid,jsonb) from public,anon;
grant execute on function public.finalize_admission(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
