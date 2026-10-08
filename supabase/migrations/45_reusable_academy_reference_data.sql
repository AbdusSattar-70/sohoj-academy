-- Reusable Sohoj Academy reference data, suitable for production.
-- Insert missing choices only: preserve IDs, edits, inactive choices and history.
-- Programme catalogue entries are not published offerings or fee commitments.
begin;
do $reference$
declare
  org uuid;
  operating_expense uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('sohoj-reference-data-v1', 0));
  select id into org from public.organizations where code = 'SOHOJ';
  if org is null then
    raise exception 'Install the essential system seed before reference data.';
  end if;

  insert into public.classes (organization_id, code, name, sort_order) values
    (org, 'CLASS_1', 'Class 1', 1),
    (org, 'CLASS_2', 'Class 2', 2),
    (org, 'CLASS_3', 'Class 3', 3),
    (org, 'CLASS_4', 'Class 4', 4),
    (org, 'CLASS_5', 'Class 5', 5),
    (org, 'CLASS_6', 'Class 6', 6),
    (org, 'CLASS_7', 'Class 7', 7),
    (org, 'CLASS_8', 'Class 8', 8),
    (org, 'CLASS_9', 'Class 9', 9),
    (org, 'CLASS_10', 'Class 10', 10),
    (org, 'CLASS_11', 'Class 11', 11),
    (org, 'CLASS_12', 'Class 12', 12),
    (org, 'TRAINING', 'Training', 20),
    (org, 'JOB_PREPARATION', 'Job Preparation', 30)
  on conflict (organization_id, code) do nothing;

  insert into public.academic_groups (organization_id, code, name) values
    (org, 'GENERAL', 'General'),
    (org, 'SCIENCE', 'Science'),
    (org, 'HUMANITIES', 'Humanities'),
    (org, 'BUSINESS_STUDIES', 'Business Studies'),
    (org, 'VOCATIONAL', 'Vocational')
  on conflict (organization_id, code) do nothing;

  insert into public.subjects (organization_id, code, name) values
    (org, 'BANGLA', 'Bangla'),
    (org, 'ENGLISH', 'English'),
    (org, 'MATHEMATICS', 'Mathematics'),
    (org, 'GENERAL_SCIENCE', 'General Science'),
    (org, 'ICT', 'ICT'),
    (org, 'PHYSICS', 'Physics'),
    (org, 'CHEMISTRY', 'Chemistry'),
    (org, 'BIOLOGY', 'Biology'),
    (org, 'HIGHER_MATHEMATICS', 'Higher Mathematics'),
    (org, 'BANGLADESH_GLOBAL_STUDIES', 'Bangladesh and Global Studies'),
    (org, 'HISTORY', 'History'),
    (org, 'GEOGRAPHY', 'Geography and Environment'),
    (org, 'ECONOMICS', 'Economics'),
    (org, 'CIVICS', 'Civics and Citizenship'),
    (org, 'ACCOUNTING', 'Accounting'),
    (org, 'FINANCE_BANKING', 'Finance and Banking'),
    (org, 'BUSINESS_ENTREPRENEURSHIP', 'Business Entrepreneurship'),
    (org, 'ISLAM_RELIGION', 'Islam and Moral Education'),
    (org, 'HINDU_RELIGION', 'Hindu Religion and Moral Education'),
    (org, 'BUDDHIST_RELIGION', 'Buddhist Religion and Moral Education'),
    (org, 'CHRISTIAN_RELIGION', 'Christian Religion and Moral Education'),
    (org, 'AGRICULTURE', 'Agriculture Studies'),
    (org, 'HOME_SCIENCE', 'Home Science'),
    (org, 'GENERAL_KNOWLEDGE', 'General Knowledge'),
    (org, 'MENTAL_ABILITY', 'Mental Ability'),
    (org, 'SPOKEN_ENGLISH', 'Spoken English')
  on conflict (organization_id, code) do nothing;

  insert into public.programs (organization_id, code, name, description) values
    (org, 'SCHOOL_ACADEMIC', 'School Academic Programme', 'Regular academic support for school students.'),
    (org, 'ANNUAL_EXAM_READINESS', 'Annual Exam Readiness', 'Assessment, model tests and correction classes for annual examinations.'),
    (org, 'JUNIOR_SCHOLARSHIP', 'Junior Scholarship Preparation', 'Preparation for junior scholarship examinations.'),
    (org, 'SSC_PREPARATION', 'SSC A+ Preparation', 'Subject-based preparation for the Secondary School Certificate examination.'),
    (org, 'HSC_PREPARATION', 'HSC Preparation', 'Subject-based preparation for the Higher Secondary Certificate examination.'),
    (org, 'SPOKEN_ENGLISH', 'Spoken English', 'Speaking, listening and practical communication practice.'),
    (org, 'BOYS_EVENING_CARE', 'Boys Evening Care', 'Supervised study, homework and academic support.'),
    (org, 'JOB_PREPARATION', 'Job Preparation Programme', 'Preparation for recruitment examinations.'),
    (org, 'PRIMARY_TEACHER_JOB', 'Primary Teacher Job Preparation', 'Preparation for primary teacher recruitment examinations.')
  on conflict (organization_id, code) do nothing;

  insert into public.lead_sources (organization_id, code, name) values
    (org, 'ORGANIC', 'Organic'),
    (org, 'WEBSITE', 'Website'),
    (org, 'PHONE', 'Phone Enquiry'),
    (org, 'WHATSAPP', 'WhatsApp'),
    (org, 'FACEBOOK', 'Facebook'),
    (org, 'GUARDIAN_SURVEY', 'Guardian Survey'),
    (org, 'LEAFLET', 'Leaflet'),
    (org, 'MIKING', 'Miking / Public Announcement')
  on conflict (organization_id, code) do nothing;

  insert into public.guardian_relationships (organization_id, code, name) values
    (org, 'LEGAL_GUARDIAN', 'Legal Guardian')
  on conflict (organization_id, code) do nothing;

  -- Explicit planning years; never switch off an existing academic year.
  insert into public.academic_years (organization_id, name, starts_on, ends_on, is_active)
  values (org, '2026', date '2026-01-01', date '2026-12-31', true),
         (org, '2027', date '2027-01-01', date '2027-12-31', false)
  on conflict (organization_id, name) do nothing;

  -- Real service areas; no invented school identities or verification claims.
  insert into public.areas (organization_id, name)
  select org, choice.name
  from (values ('Gopalpur Bazar'), ('Narundi')) as choice(name)
  where not exists (
    select 1 from public.areas existing
    where existing.organization_id = org
      and lower(btrim(existing.name)) = lower(choice.name)
  );

  select id into operating_expense from public.finance_accounts
  where organization_id = org and code = '5100' and account_type = 'EXPENSE';
  if operating_expense is null then
    raise exception 'Essential general operating expense account 5100 is missing.';
  end if;
  insert into public.finance_expense_categories
    (organization_id, code, name, expense_account_id)
  select org, choice.code, choice.name, operating_expense
  from (values
    ('RENT', 'Rent'), ('UTILITIES', 'Electricity and Utilities'),
    ('INTERNET', 'Internet and Telephone'), ('PRINTING', 'Printing and Photocopying'),
    ('STATIONERY', 'Stationery'), ('MARKETING', 'Marketing and Advertising'),
    ('CLEANING', 'Cleaning Supplies and Services'), ('REPAIRS', 'Repairs and Maintenance'),
    ('TRANSPORT', 'Transport and Travel'), ('SOFTWARE', 'Software and Subscriptions')
  ) as choice(code, name)
  on conflict (organization_id, code) do nothing;
end $reference$;
commit;
