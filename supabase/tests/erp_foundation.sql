-- Development-only verification for 0009_erp_foundation.sql.
-- Run in a development Supabase project. Everything is rolled back.

begin;

do $$
declare
  v_year uuid;
  v_class uuid;
  v_batch uuid;
  v_student uuid;
  v_i integer;
  v_failed boolean;
begin
  -- Versioned business rules are seeded.
  if not exists (
    select 1 from public.business_rule_versions
    where rule_key='academics.batch_capacity_policy'
      and status='ACTIVE'
      and (value->>'max_students')::integer=12
  ) then
    raise exception 'FAIL: active batch-capacity business rule missing';
  end if;

  if not exists (
    select 1 from public.business_rule_versions
    where rule_key='teacher_compensation.default_policy'
      and status='ACTIVE'
      and (value->>'teaching_pool_percent')::numeric=30
      and (value->>'student_acquisition_percent')::numeric=50
  ) then
    raise exception 'FAIL: active teacher compensation policy missing';
  end if;

  -- Active policy values cannot be silently edited.
  v_failed := false;
  begin
    update public.business_rule_versions
       set value='{"max_students":99}'::jsonb
     where rule_key='academics.batch_capacity_policy'
       and status='ACTIVE';
  exception when others then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: active business-rule value was editable in place';
  end if;

  -- School names are canonicalised case-insensitively.
  insert into public.schools(name) values ('ERP Foundation Test School');
  v_failed := false;
  begin
    insert into public.schools(name) values ('  erp foundation test school  ');
  exception when unique_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: duplicate normalised school name was accepted';
  end if;

  insert into public.academic_years(name,starts_on,ends_on,is_active)
  values ('ERP-FOUNDATION-2099','2099-01-01','2099-12-31',false)
  returning id into v_year;

  insert into public.classes(name,sort_order)
  values ('ERP Foundation Test Class',999)
  returning id into v_class;

  insert into public.batches(academic_year_id,class_id,name,capacity,is_active)
  values (v_year,v_class,'ERP Foundation Batch A',12,true)
  returning id into v_batch;

  -- Active max=12 policy rejects a larger batch.
  v_failed := false;
  begin
    insert into public.batches(academic_year_id,class_id,name,capacity,is_active)
    values (v_year,v_class,'ERP Foundation Batch Too Large',13,true);
  exception when others then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: batch capacity above active policy was accepted';
  end if;

  -- Fill exactly 12 seats.
  for v_i in 1..12 loop
    insert into public.students(student_no,name)
    values ('ERP-TEST-'||lpad(v_i::text,3,'0'),'ERP Test Student '||v_i)
    returning id into v_student;

    insert into public.enrollments(
      student_id,academic_year_id,class_id,batch_id,admission_date,monthly_fee,discount,is_active
    ) values (
      v_student,v_year,v_class,v_batch,current_date,2500,0,true
    );
  end loop;

  -- Seat 13 must fail.
  insert into public.students(student_no,name)
  values ('ERP-TEST-013','ERP Test Student 13')
  returning id into v_student;

  v_failed := false;
  begin
    insert into public.enrollments(
      student_id,academic_year_id,class_id,batch_id,admission_date,monthly_fee,discount,is_active
    ) values (
      v_student,v_year,v_class,v_batch,current_date,2500,0,true
    );
  exception when others then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: 13th active enrollment was accepted into a 12-seat batch';
  end if;

  -- Discount cannot exceed tuition.
  insert into public.students(student_no,name)
  values ('ERP-TEST-DISC','ERP Discount Test Student')
  returning id into v_student;

  v_failed := false;
  begin
    insert into public.enrollments(
      student_id,academic_year_id,class_id,admission_date,monthly_fee,discount,is_active
    ) values (
      v_student,v_year,v_class,current_date,2000,2500,true
    );
  exception when check_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: discount above monthly tuition was accepted';
  end if;

  if not exists (select 1 from public.approval_requests limit 1) then
    -- Empty is valid: the table only needs to exist at this foundation stage.
    perform 1 from public.approval_requests limit 0;
  end if;

  raise notice 'PASS: ERP foundation rules, school canonicalisation, capacity and discount integrity verified.';
end $$;

rollback;
