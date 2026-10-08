# Sohoj final: routines and actual class operation

Extend existing programme_offerings, batches, academic_rooms, academic_routines, class_sessions, attendance_submissions and class_logs. No parallel academic system; keep public CRM styling and existing admission/billing history.

Setup: review master lists → programme operating dates/default weekdays → fees → batch days/day-specific windows → classroom capacity → teacher qualifications and weekly availability → weekly subject routine → dated sessions → admission intake. Website, fees/intake and timetable readiness remain independent.

Availability is a Bangladesh-local weekly window with effective dates; adjacent windows may jointly cover a class. Free time also checks existing teacher, room and batch bookings. Holidays/closures skip recurring generation. Sessions validate programme dates, subject eligibility, qualified teaching role, resource availability, room capacity and conflicts under one scheduling lock.

Daily: today's class → attendance → actual summary/start/end/homework → teacher submit → independent admin review. Planned session time, staff academy presence and verified teaching hours are separate. Teaching-share workload uses approved actual duration; fixed salary stays separate. Rejected reports allow corrections; prior approved evidence stays official until a newer approval. Cancelled sessions earn no hours.

Substitution, room changes and rescheduling preserve the original by cancellation plus an atomic linked replacement. Makeup links a cancelled class. Recheck all resources; submitted or approved evidence blocks schedule rewriting. Routine changes affect future planning, never completed history. Repeated generation does not duplicate cancelled occurrences.

Admission choices show days, times and available seats; enrollment dates decide attendance roster. Existing batch transfer history remains intact. Training supports optional school class/year and explicit duration; do not fabricate school identity for a short course.

Separate planning/settings, routine and daily calendar views; on-demand forms, dropdowns/checklists, preserved invalid input, loading/result feedback and stable request identities. Authorized RPC writes and verified server identity are the boundary. Uncertain results retry unchanged payload. Lists use bounded dates/pages. No live database reset or email sending; notification delivery requires provider configuration and must not be claimed delivered from a database record alone.

Delivery: planning/availability/calendar; routines/session changes/admission summaries; actual-time review/workload; isolated checks and Bengali operator help. Each completed feature is committed on feature/sohoj_final.


Implemented pages: `/dashboard/academics/planning` (one section per request), `/dashboard/academics/curriculum`, `/dashboard/academics/routine`, `/dashboard/academics/operations`, existing session detail and teacher dashboard. Planning can create classroom/availability/closure inline while preserving the routine form. Teacher identity/access use the controlled Staff workspace; teaching subject qualifications are configured on-demand in Academic planning or inline on Routine. Fixed/hourly compensation exclusions and the unified referral accrual remain intact; creating a room never grants staff access. Curriculum remains an immutable evidence plan, rather than a second programme model.

Forward migrations 47–53 preserve the existing baseline and posted records. SQL fixtures 35 and 36 cover availability coverage, resource conflict rejection, holidays, generation retry, failed replacement rollback, linked makeup, routine retirement, teacher/admin review, approved actual hours, and a class/year-free training admission through invoice and enrollment. The browser and hosted Supabase still require local acceptance. Notification email delivery is not added or asserted by this delivery.

[বাংলা ব্যবহার নির্দেশিকা](ACADEMIC_OPERATION_GUIDE_BN.md) is also available inside ERP at `/dashboard/help/academics`.
