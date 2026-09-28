# Programme Offering register workflow

The Academics → Programme Offerings page opens on a table showing code/name, academic year, branch, class/group, programme, operational status, website visibility and application intake. **Create offering** opens a focused form. Row actions open **Edit offering** or **Public settings**; long forms and review tools stay out of the default screen.

New offerings begin as drafts and require a published Fee Plan to become active. Editing records a required reason, actor, correlation ID, before/after snapshot and idempotency key.

A draft can change its academic context while its master data is active and no batch references it. Active offerings keep branch, year, class, group and programme fixed so existing batches, applications and admissions retain their context; staff may correct the offering code or name. Retired offerings are read-only. For a different active academic context, create a new offering and publish its Fee Plan.

Website visibility, intake dates, showcase copy, subject selection and reviewed content versions remain under **Public settings**, separate from operational status and Fee Plan publication.