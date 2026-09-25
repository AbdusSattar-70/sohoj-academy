# V1 Mock Verification

Use a development Supabase project only.

## Run

1. Apply migrations: `pnpm exec supabase db push`
2. Open Supabase SQL Editor and run `supabase/tests/v1_mock_flow.sql`.
3. Confirm the final verification queries return:
   - active mock students = 2
   - mock batch capacity = 12
   - attendance rows = 2
   - assessment results = 2
   - payments posted = 2
   - weekly monitoring = 2
   - parent communications = 2
4. Start app: `pnpm dev`
5. Verify UI:
   - Students lists both mock students.
   - Open each student profile; enrollment, guardian, attendance, result and payment data are visible.
   - Attendance can update an existing row without duplication.
   - Assessment Results can update marks without duplication and rejects marks above total marks.
   - Progress can update the same student/week.
   - Parent Communication can add a new record.
   - Payments displays both mock receipts.
6. Run `pnpm build` after verification.

## Important

The SQL intentionally creates mock records and is not a migration. Never execute it on the production database.
