# Operational usability rollout checklist

Branch: `feature/sohoj_final`. Each implementation/fix is committed separately. Public CRM appearance and server/database permissions remain authoritative.

| Item | Status |
| --- | --- |
| Explicit guide coverage for every registered work area | Implemented |
| Semantic field help for standard ERP fields | Implemented; application-specific fields are audited below |
| Active editor pending/dirty navigation and browser-close protection | Implemented for active mutation forms; native browser back history still depends on browser/router behavior |
| Shared safe return path and localized return feedback | Implemented; allowlist regression passes |
| Inline missing-school/relationship creation and setup recovery links | Existing inline creation strengthened: reuse existing, localized feedback, pending lock, retain failed input; contextual returns unified |
| Active form loading, button and localization audit | Active-form inventory committed; shared submit indicators and common field labels covered. Bespoke legacy hints/messages still need translation where not in the explicit catalog |
| Admission payment/receipt print continuity and mobile preview | Existing inline collection and receipt links retained; print consequence help and narrow-screen admission preview added. Actual acceptance remains to verify |
| Role/assigned-scope and request regression checks | Navigation and safe-return checks pass; existing isolated DB fixture suite passes. Live assigned-user/workspace checks remain |
| Authenticated live-browser/database acceptance | Requires the actual local/deployed environment; not represented by isolated checks |

Retired advanced finance routes are excluded from the operator rollout; they are not silently reintroduced. No new financial model or schema reset is part of this task.
