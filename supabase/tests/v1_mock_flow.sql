-- Development-only mock dataset for end-to-end Sohoj Academy verification.
-- Run manually against a development database. Do NOT run on production.

do $$
declare
 y uuid; c uuid; p uuid; b uuid; sub uuid; t uuid; room uuid;
 s1 uuid; s2 uuid; g1 uuid; g2 uuid; e1 uuid; e2 uuid; sess uuid; a uuid;
begin
 insert into public.academic_years(name,starts_on,ends_on,is_active) values('2026','2026-01-01','2026-12-31',true)
 on conflict do nothing;
 select id into y from public.academic_years where name='2026' limit 1;

 insert into public.classes(name,sort_order) values('Class 8',8) on conflict do nothing;
 select id into c from public.classes where name='Class 8' limit 1;

 insert into public.programs(name,code) values('Annual Exam Readiness 2026','AER-26') on conflict do nothing;
 select id into p from public.programs where code='AER-26' limit 1;

 insert into public.subjects(name,code) values('Mathematics','MATH') on conflict do nothing;
 select id into sub from public.subjects where code='MATH' limit 1;

 insert into public.batches(academic_year_id,class_id,program_id,name,capacity) values(y,c,p,'Mock Class 8 - A',12)
 on conflict do nothing;
 select id into b from public.batches where name='Mock Class 8 - A' limit 1;

 insert into public.teachers(name,mobile) values('Mock Teacher','01700000001') returning id into t;
 insert into public.classrooms(name,capacity) values('Mock Room A',12) on conflict do nothing;
 select id into room from public.classrooms where name='Mock Room A' limit 1;

 insert into public.students(name,name_bn,gender,school_name,school_roll) values('Mock Student One','মক শিক্ষার্থী এক','Male','Mock High School','801') returning id into s1;
 insert into public.students(name,name_bn,gender,school_name,school_roll) values('Mock Student Two','মক শিক্ষার্থী দুই','Female','Mock High School','802') returning id into s2;
 insert into public.guardians(name,mobile,address) values('Mock Guardian One','01710000001','Jamalpur') returning id into g1;
 insert into public.guardians(name,mobile,address) values('Mock Guardian Two','01710000002','Jamalpur') returning id into g2;
 insert into public.student_guardians(student_id,guardian_id,relationship,is_primary) values(s1,g1,'Father',true),(s2,g2,'Mother',true);

 insert into public.enrollments(student_id,academic_year_id,class_id,batch_id,program_id,admission_date,monthly_fee,discount)
 values(s1,y,c,b,p,current_date,2500,200) returning id into e1;
 insert into public.enrollments(student_id,academic_year_id,class_id,batch_id,program_id,admission_date,monthly_fee,discount)
 values(s2,y,c,b,p,current_date,2500,0) returning id into e2;

 insert into public.class_sessions(batch_id,subject_id,teacher_id,classroom_id,session_date,starts_at,ends_at)
 values(b,sub,t,room,current_date,'16:00','17:00') returning id into sess;
 insert into public.attendance(session_id,student_id,status) values(sess,s1,'PRESENT'),(sess,s2,'LATE');

 insert into public.assessments(academic_year_id,batch_id,subject_id,title,assessment_type,held_on,total_marks)
 values(y,b,sub,'Mock Weekly Test 01','WEEKLY',current_date,100) returning id into a;
 insert into public.assessment_results(assessment_id,student_id,marks,remarks) values(a,s1,84,'Good'),(a,s2,72,'Needs practice');

 insert into public.payments(receipt_no,student_id,enrollment_id,amount,payment_date,method)
 values('MOCK-RCP-001',s1,e1,2300,current_date,'CASH'),('MOCK-RCP-002',s2,e2,2500,current_date,'CASH');

 insert into public.weekly_monitoring(student_id,week_start,homework_score,participation_score,test_score,remarks)
 values(s1,current_date,90,85,84,'Good progress'),(s2,current_date,70,80,72,'Practice mathematics');
 insert into public.parent_communications(student_id,guardian_id,communication_type,notes,next_follow_up)
 values(s1,g1,'CALL','Mock progress update shared.',current_date+7),(s2,g2,'MEETING','Discussed mathematics practice.',current_date+7);

 raise notice 'Mock dataset created: students %, %',s1,s2;
end $$;

-- Verification: every query below should return zero failing rows / expected counts.
select 'active mock students' check_name,count(*) value from public.students where name like 'Mock Student%';
select 'mock batch capacity' check_name,capacity value from public.batches where name='Mock Class 8 - A';
select 'attendance rows' check_name,count(*) value from public.attendance a join public.students s on s.id=a.student_id where s.name like 'Mock Student%';
select 'assessment results' check_name,count(*) value from public.assessment_results r join public.students s on s.id=r.student_id where s.name like 'Mock Student%';
select 'payments posted' check_name,count(*) value from public.payments where receipt_no like 'MOCK-RCP-%' and status='POSTED';
select 'weekly monitoring' check_name,count(*) value from public.weekly_monitoring w join public.students s on s.id=w.student_id where s.name like 'Mock Student%';
select 'parent communications' check_name,count(*) value from public.parent_communications pc join public.students s on s.id=pc.student_id where s.name like 'Mock Student%';
