-- Generated from supabase/schema/academics/04_foundation_seed.sql; edit the source, then run pnpm db:baseline.
-- Essential reference data only. No demo students, payments, Auth accounts or passwords.
insert into public.academies(name) values('Sohoj Academy') on conflict(singleton) do nothing;
insert into public.operating_divisions(academy_id,code,name,name_bn)
select a.id,v.code,v.name,v.bn from public.academies a cross join (values
 ('SCHOOL','School','স্কুল'),('COACHING','Coaching','কোচিং'),('TRAINING','Preparation & Training','প্রস্তুতি ও প্রশিক্ষণ')) v(code,name,bn)
on conflict(academy_id,code) do nothing;
insert into public.campuses(academy_id,code,name) select id,'MAIN','Main Campus' from public.academies on conflict(academy_id,code) do nothing;
insert into public.access_roles values
 ('ADMIN',array['people.view','people.manage','directory.view','directory.manage','access.manage','activity.view']),
 ('OPERATOR',array['people.view','people.manage','directory.view','directory.manage']),
 ('TEACHER',array['directory.view']),('ACCOUNTANT',array['directory.view']),('REFERRER','{}')
on conflict(code) do nothing;
insert into public.education_levels values
 ('EARLY_YEARS','Early years','প্রাক-প্রাথমিক',1,true),('SCHOOL','School','বিদ্যালয়',2,true),
 ('GRADUATION','Graduation','স্নাতক',3,true),('POSTGRADUATE','Postgraduate','স্নাতকোত্তর',4,true)
on conflict(code) do nothing;
insert into public.class_levels values
 ('PLAY','EARLY_YEARS','Play','প্লে',1,true),('NURSERY','EARLY_YEARS','Nursery','নার্সারি',2,true),('KG','EARLY_YEARS','KG','কেজি',3,true)
on conflict(code) do nothing;
insert into public.class_levels(code,level_code,name,name_bn,sort_order)
select 'CLASS_'||n,'SCHOOL','Class '||n,'শ্রেণি '||translate(n::text,'0123456789','০১২৩৪৫৬৭৮৯'),n+3 from generate_series(1,12)n
on conflict(code) do nothing;
insert into public.education_tracks values
 ('DEGREE_3','GRADUATION','Three-year degree','তিন বছরের স্নাতক',3,1,true),
 ('DEGREE_4','GRADUATION','Four-year degree','চার বছরের স্নাতক',4,2,true),
 ('POSTGRADUATE','POSTGRADUATE','Postgraduate','স্নাতকোত্তর',null,3,true)
on conflict(code) do nothing;
insert into public.directory_entries(academy_id,kind,code,name,name_bn,sort_order)
select a.id,v.kind,v.code,v.name,v.bn,v.ord from public.academies a cross join(values
 ('SUBJECT','BANGLA','Bangla','বাংলা',1),('SUBJECT','ENGLISH','English','ইংরেজি',2),
 ('SUBJECT','MATHEMATICS','Mathematics','গণিত',3),('SUBJECT','GENERAL_SCIENCE','General Science','সাধারণ বিজ্ঞান',4),
 ('SUBJECT','PHYSICS','Physics','পদার্থবিজ্ঞান',5),('SUBJECT','CHEMISTRY','Chemistry','রসায়ন',6),
 ('SUBJECT','BIOLOGY','Biology','জীববিজ্ঞান',7),('SUBJECT','ICT','ICT','তথ্য ও যোগাযোগ প্রযুক্তি',8),
 ('SUBJECT','HIGHER_MATHEMATICS','Higher Mathematics','উচ্চতর গণিত',9),
 ('GROUP','SCIENCE','Science','বিজ্ঞান',1),('GROUP','HUMANITIES','Humanities','মানবিক',2),('GROUP','BUSINESS','Business Studies','ব্যবসায় শিক্ষা',3),
 ('RELATIONSHIP','FATHER','Father','পিতা',1),('RELATIONSHIP','MOTHER','Mother','মাতা',2),('RELATIONSHIP','GUARDIAN','Guardian','অভিভাবক',3),
 ('LEAD_SOURCE','ORGANIC','Organic','নিজ উদ্যোগে',1),('LEAD_SOURCE','REFERRAL','Referral','রেফারাল',2),
 ('DISCOUNT_REASON','MERIT','Merit','মেধা',1),('DISCOUNT_REASON','HARDSHIP','Financial hardship','আর্থিক অসচ্ছলতা',2),
 ('DISCOUNT_REASON','SIBLING','Sibling','সহোদর',3),('DISCOUNT_REASON','STAFF_FAMILY','Staff family','স্টাফের পরিবার',4),
 ('EXPENSE_CATEGORY','RENT','Rent','ভাড়া',1),('EXPENSE_CATEGORY','UTILITIES','Utilities','বিদ্যুৎ ও অন্যান্য সেবা',2),
 ('EXPENSE_CATEGORY','TEACHING_MATERIALS','Teaching materials','শিক্ষা উপকরণ',3),('EXPENSE_CATEGORY','MAINTENANCE','Maintenance','রক্ষণাবেক্ষণ',4),
 ('EXPENSE_CATEGORY','TRAVEL','Travel','যাতায়াত',5),('EXPENSE_CATEGORY','OTHER','Other expense','অন্যান্য খরচ',6),
 ('MAJOR','SCIENCE','Science','বিজ্ঞান',1),('MAJOR','ARTS','Arts','কলা',2),('MAJOR','BUSINESS','Business','ব্যবসায়',3),
 ('PROGRAMME_TYPE','SCHOOL','School programme','স্কুল প্রোগ্রাম',1),('PROGRAMME_TYPE','COACHING','Academic coaching','একাডেমিক কোচিং',2),
 ('PROGRAMME_TYPE','JOB_PREPARATION','Job preparation','চাকরির প্রস্তুতি',3),('PROGRAMME_TYPE','TRAINING','Training','প্রশিক্ষণ',4)
)v(kind,code,name,bn,ord) on conflict(academy_id,kind,code) do nothing;
-- No guessed local institution names, no automatic offerings/intake, no fabricated year.
