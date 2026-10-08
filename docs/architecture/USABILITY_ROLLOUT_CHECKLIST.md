# Operational usability rollout checklist

Branch: `feature/sohoj_final`. Each implementation/fix is committed separately. Public CRM appearance and server/database permissions remain authoritative.

| Item | Status |
| --- | --- |
| Explicit guide coverage for every registered work area | Implemented |
| Semantic field help for standard ERP fields | Implemented; application-specific fields are audited below |
| Active editor pending/dirty navigation and browser-close protection | Implemented for active mutation forms; native browser back history still depends on browser/router behavior |
| Shared safe return path and localized return feedback | Pending |
| Inline missing-school/relationship creation and setup recovery links | Pending |
| Active form loading, button and localization audit | Pending |
| Admission payment/receipt print continuity and mobile preview | Pending |
| Role/assigned-scope and request regression checks | Pending |
| Authenticated live-browser/database acceptance | Requires the actual local/deployed environment; not represented by isolated checks |

Retired advanced finance routes are excluded from the operator rollout; they are not silently reintroduced. No new financial model or schema reset is part of this task.
