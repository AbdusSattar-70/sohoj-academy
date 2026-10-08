# Active mutation form audit

Public CRM styling and retired advanced finance are outside this editor rollout. Each active mutation form is marked for pending/dirty navigation protection and disables its controls while its request runs. Search/filter GET forms are excluded. Domain-specific validation, RPC permissions and idempotency remain unchanged.

| Form | Safety coverage |
| --- | --- |
| `modules/admissions/components/command-form.tsx` | Registered mutation editor |
| `modules/admissions/components/extra-charge-form.tsx` | Registered mutation editor |
| `modules/admissions/components/identity-editor.tsx` | Registered mutation editor |
| `modules/admissions/components/physical-consent-form.tsx` | Registered mutation editor |
| `modules/admissions/components/placement-editor.tsx` | Registered mutation editor |
| `modules/admissions/components/referral-form.tsx` | Registered mutation editor |
| `modules/admissions/components/staff-intake-form.tsx` | Registered mutation editor |
| `modules/academics/assessments/workspace.tsx` | Registered mutation editor |
| `modules/academics/assessments/workspace.tsx` | Registered mutation editor |
| `modules/academics/documents/form.tsx` | Registered mutation editor |
| `modules/academics/homework/workspace.tsx` | Registered mutation editor |
| `modules/academics/operations/class-log-form.tsx` | Registered mutation editor |
| `modules/academics/operations/class-log-review.tsx` | Registered mutation editor |
| `modules/academics/operations/command-form.tsx` | Registered mutation editor |
| `modules/academics/planning/form.tsx` | Registered mutation editor |
| `modules/offerings/components/fee-plan-form.tsx` | Registered mutation editor |
| `modules/offerings/components/offering-form.tsx` | Registered mutation editor |
| `modules/offerings/components/public-controls-form.tsx` | Registered mutation editor |
| `modules/crm/components/prospect-assignment-form.tsx` | Registered mutation editor |
| `modules/crm/components/prospect-followup-form.tsx` | Registered mutation editor |
| `modules/crm/manage/components/master-data-workspace.tsx` | Registered mutation editor |
| `modules/staff/components/staff-register.tsx` | Registered mutation editor |
| `modules/students/lifecycle/close-enrollment-form.tsx` | Registered mutation editor |
| `modules/students/lifecycle/command-form.tsx` | Registered mutation editor |
| `modules/referrals/register.tsx` | Registered mutation editor |
| `modules/referrals/register.tsx` | Registered mutation editor |
| `modules/workforce/task-register.tsx` | Registered mutation editor |
| `modules/workforce/workspace.tsx` | Registered mutation editor |
| `modules/platform/setup/identity-form.tsx` | Registered mutation editor |
| `modules/platform/access/request-form.tsx` | Registered mutation editor |
| `modules/finance/simple/teaching-workspace.tsx` | Registered mutation editor |
| `modules/finance/simple/workspace.tsx` | Registered mutation editor |
| `modules/finance/operations/collection-form.tsx` | Registered mutation editor |
| `modules/finance/operations/command-form.tsx` | Registered mutation editor |
| `modules/finance/payroll/recovery-panel.tsx` | Registered mutation editor |
| `modules/finance/payroll/register.tsx` | Registered mutation editor |
| `modules/finance/payroll/register.tsx` | Registered mutation editor |
| `modules/finance/payroll/register.tsx` | Registered mutation editor |
| `modules/finance/reimbursements/register.tsx` | Registered mutation editor |

The shared listener protects in-app links, reload/close and native filter submissions. Browser back/forward behavior must be checked in the target browser. A successful status clears the submitting form only; unrelated drafts remain guarded.
