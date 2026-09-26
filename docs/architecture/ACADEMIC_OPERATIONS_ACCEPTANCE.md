# Academic operations acceptance

## Update locally

```bash
git switch feature/student-lifecycle
git pull --ff-only origin feature/student-lifecycle
pnpm install
pnpm exec supabase migration list
pnpm exec supabase db push
pnpm dev
```

Apply all pending migrations through 0021 to the development project used by `.env.local`. If the dev server is running, use it instead of starting another. No reset is needed.

## Prerequisites and people

- An active Offering, Fee Plan and batch with an activated student enrollment.
- Active Staff with a teaching role, matching subject qualification and appropriate branch. Assignment effective dates must cover the intended routine/session dates.
- A teacher's Auth/Profile must be linked to the assigned Staff identity. An operational TEACHER role alone does not identify which staff member is teaching.
- Independent reviewer: ADMIN or an operational account with attendance approval permission. The attendance author cannot approve their own submission, including ADMIN.

| Activity | Required permissions |
| --- | --- |
| Open academic screens | `academics.view` |
| Publish curriculum | `academics.curriculum.manage` |
| Rooms, routines, sessions and cancellation | `academics.sessions.manage` |
| Record/submit attendance | `academics.attendance.record` and assigned session scope, or managerial/reviewer session scope |
| Approve/reject attendance | `academics.attendance.approve`, different from author/requester |

## Start with setup

1. Open **Academics → Academic Operations → Rooms**. Create a room in the batch branch. Capacity must accommodate the configured batch capacity.
2. Open **Curriculum**. Select batch/subject, name the plan, add chapters/topics/page ranges and target dates, then publish. Targets must stay inside the academic year. A later publication creates a new version.
3. Open **Routine Templates**. Choose batch, subject, qualified teacher, room, weekday, local start/end time and date range. Overlapping teacher, room or batch assignments are rejected.
4. On the saved routine, choose generation dates, optionally pin a curriculum version, describe the planned scope and generate dated sessions. Generate at most 94 days per request. A repeated date is skipped, not duplicated. A conflict rolls back the whole generation request.
5. Use the session date filter to view the generated classes. You can also schedule a single class with the same integrity checks. Times use the organization's timezone (Asia/Dhaka for Sohoj).

## Attendance and review

1. Sign in as the assigned teacher and open a session after its start time. The teacher should not see another teacher's unrelated sessions/rosters.
2. Choose PRESENT, ABSENT, LATE or EXCUSED for every roster member; nobody is automatically marked present. Add notes and a reason, then save the draft.
3. Review saved revision history, then **Submit Saved Attendance**. Save any edits before submitting: submission uses the saved revision, not unsaved inputs.
4. Under the independent reviewer account, follow the Action Center → Approval Register → Review class attendance link, or open the session directly.
5. Inspect the entries, approve/reject with a reason. Approved counts now appear as official attendance.
6. Test a correction: save a fresh revision, submit, then reject it. The original approved revision must remain official. Approving a later correction makes that approved revision current while retaining earlier evidence.
7. A stale form cannot overwrite a newer revision. An awaiting-review submission cannot be edited; the reviewer must decide it first.

## Cancellations and history

- Cancel a scheduled occurrence with reason before attendance has been submitted/approved. The original date, teacher, room and plan remain in history.
- Retiring a weekly template prevents further generation but does not cancel existing dates.
- For rescheduling, cancel the old occurrence and create a new dated class. This release does not automate substitution or recovery assignments.
- Re-generating a routine will not recreate a cancelled occurrence under the same routine/date.
- First attendance save snapshots student/enrollment IDs and labels. Later corrections keep that roster. The current enrollment model uses date-only membership: admission date is inclusive, ended_on is exclusive. A same-day transfer uses destination membership for a roster first captured that day; already-saved evidence stays intact.

## Scope and verification

Curriculum targets are plans. Neither the passage of session time nor attendance approval marks teaching coverage complete. Actual class logs, homework, coverage recovery, assessments/results and teacher question creation are separate next modules.

`supabase/tests/0020_v2_academic_operations.sql` contains rollback-only test fixtures for scheduling, scope, attendance and revision integrity. All SQL tests passed locally in isolated PGlite/Postgres. Live browser, linked Supabase and concurrent-connection testing remain required before operational rollout.
