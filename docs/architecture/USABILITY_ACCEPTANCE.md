# Operational usability acceptance

## Local verification

Use the same feature/sohoj_final branch. These checks do not write to the live database:

```sh
pnpm check:source
pnpm exec tsc --noEmit
node scripts/check-workspace-navigation.cjs
node scripts/check-workflow-return.cjs
node scripts/check-button-slot.cjs
pnpm build
```

The build used placeholder public Supabase configuration in the implementation environment. It proves compilation, not an authenticated workflow. No database reset or new migration is required for this UI rollout.

## Verify in the actual running academy

| Role / workflow | Action | Expected result |
| --- | --- | --- |
| Admin / admission | Open a draft, change details, attempt another route | Confirm unsaved input; rejecting leaves the editor and values intact |
| Admin / pending save | Save and immediately try sidebar/filter navigation | Pending controls and navigation block duplicate/disruptive actions; feedback appears |
| Admin / missing school | Choose Add missing, enter an existing name with different case | Reuse the existing choice; do not manufacture another identity |
| Admin / failed inline create | Interrupt the connection | Name remains; check the directory before retrying |
| Admin / final admission | Complete verification, referral and physical consent, confirm review | Student/invoice are created through existing controlled command; printing alone records nothing |
| Admin / payment | Open inline collection, record actual received amount, inspect receipt and due | Receipt records money; fee reduction is not represented as money received |
| Admin / contextual task | Follow billing/setup shortcut with returnTo, save | Return only to an allowed original page; manually returning also remains available |
| Admin / parallel drafts | Open two action panels, edit both, save one | The unrelated dirty draft remains open and its input remains |
| Teacher | Open My classes / My work tabs, submit assigned class/document | Only authorized/assigned records; submission is distinct from admin acceptance |
| Restricted account | Paste another person's class/admission/referral URL | Server/RPC permissions reject unauthorized access regardless of hidden navigation |
| Workspace | Switch academy workspace and inspect classes/fees/people | Check actual backend scope; sidebar visibility alone is not isolation |
| Mobile / print | Open admission and invoice at narrow width, then A4 preview | Readable preview, all required pages, black/white paper output, letterhead space, correct receipt/amount words |
| Language | Switch EN/BN, open guidance and fields | Selected-language catalog text; record names remain as stored |
| Recovery | Retry an uncertain admission finalization | Same request identity for unchanged action; check existing case before retrying |

## Explicit remaining boundary

Native browser back/forward, live email delivery, real role/workspace enforcement, receipt totals against real transactions, and physical printer output require authenticated target-environment acceptance. Bespoke legacy English hints/errors outside the explicit label/help catalog still need individual translation. This document does not mark those checks or translations as complete.

## Slotted navigation regression

The shared Button now sends exactly the caller child to Radix Slot when asChild is enabled. Previously a conditional spinner expression plus the child produced an array, including a false item, causing a runtime crash despite successful TypeScript/build checks. The render regression exercises actual React/Radix modules, linked text with an icon, loading/non-loading slotted links, and an ordinary pending button. Default save feedback also recognizes the language provider’s bn-BD HTML language.
