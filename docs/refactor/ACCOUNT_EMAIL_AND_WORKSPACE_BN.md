# Account setup email ও কর্মক্ষেত্রে প্রবেশ

## Account setup email

১. `/dashboard/people/access` খুলে পরিচয় ও email ownership যাচাই করুন। Existing Person থাকলে সেটি ব্যবহার করে role অনুমোদন করুন।
২. `/dashboard/settings` → Account configuration → configuration check চালান। এটি কোনো ইমেইল পাঠায় না। Credential গ্রহণ হলে পরের ধাপ email delivery; এই check SMTP বা redirect allowlist যাচাই করে না।
৩. Request-এর “Enable account & send instructions” ব্যবহার করুন। নতুন Auth account হলে invitation; আগের account থাকলে password setup/recovery email। নতুন duplicate Person/Auth account তৈরি নয়।
৪. INVITED/ACTIVE request-এ “Resend setup instructions” দিয়ে নতুন recovery email চাইতে পারবেন। Success মানে email provider অনুরোধ গ্রহণ করেছে, recipient-এর inbox-এ পৌঁছানো নিশ্চিত নয়।
৫. Error হলে row-এর diagnostic code ও নির্দেশনা দেখুন। Spam এবং Supabase Auth logs/SMTP provider logs যাচাই করুন।

| ফলাফল | করণীয় |
| --- | --- |
| configuration_missing / configuration_invalid | `.env.local`-এ একই project-এর URL, server-only key ও site origin দিন; dev server বন্ধ করে আবার চালান |
| email_address_not_authorized | Supabase Authentication-এ custom SMTP দিন; default SMTP শুধু project organization-এর team address-এ পাঠায় |
| over_email_send_rate_limit / HTTP 429 | অপেক্ষা করুন; project Auth rate limits ও SMTP limit যাচাই করুন |
| not_admin / bad_jwt / HTTP 401 বা 403 | একই project-এর server-only service role/secret key যাচাই করুন; anon/publishable key নয় |
| HTTP 5xx | Auth ও SMTP logs-এ sender verification, SMTP host/port/credential-এর নির্দিষ্ট ব্যর্থতা দেখুন |
| request_timeout | পাঠানো অনিশ্চিত; পুনরায় পাঠানোর আগে delivery logs দেখুন |
| access_link_failed | Request/person/account একই academy-তে link হয়েছে কি না যাচাই করুন; নতুন identity তৈরি করবেন না |

Supabase Auth URL Configuration-এ local/deployed origin-এর `/auth/update-password` ও `/auth/confirm` অনুমোদন করুন। Invite এবং Recovery email template-এর link-ও যাচাই করুন। Default template-এ ConfirmationURL redirectTo গ্রহণ করে। Custom template-এ token-hash flow ব্যবহার করলে app-এর `/auth/confirm?token_hash=...&type=invite` অথবা `type=recovery` ব্যবহার করুন। Redirect URL-এ browser port সঠিক থাকতে হবে।

Reference: https://supabase.com/docs/guides/auth/auth-smtp এবং https://supabase.com/docs/guides/auth/debugging/error-codes । Default SMTP-এর restriction বদলাতে পারে; বর্তমান docs ও provider limits দেখুন।

## কর্মক্ষেত্র

নতুন sign-in-এর পর পূর্ণ পর্দায় “Where would you like to work?” আসবে। School, Coaching অথবা Job preparation & training নির্বাচন করলে চাওয়া ERP পেজে কাজ শুরু হবে। নতুন login-এ আবার এই পছন্দ আসবে। একই tab refresh-এ নির্বাচন থাকবে।

Sidebar-এর উপরের workspace card থেকে switch করুন। অসম্পূর্ণ input থাকলে discard confirmation এবং চলমান mutation থাকলে ফলাফল নিশ্চিত করার নির্দেশনা থাকবে। Sidebar collapse control উপরে, নাম/Staff ID/role নিচে। Header-এ repeated workspace selector, Current workspace banner বা generic Back to dashboard link নেই। Mobile navigation-এও workspace switch আছে।

কর্মক্ষেত্র এখন interface context ও scoped offering filter; এটি access permission নয়, এবং সব academy-wide shared record-কে আলাদা tenant করে না। DB/RLS/permission checks অপরিবর্তিত। Teacher/referrer-এর সীমিত ব্যক্তিগত workspace-এ admin chooser চাপানো হবে না।

## যাচাইয়ের সীমা

Auth transport mocked regression দিয়ে new invite, existing recovery, race recovery, provider failures এবং unsafe identity link rejection যাচাই পাস করেছে (`node scripts/check-account-setup.mjs`)। Typecheck ও production build-ও পাস করেছে। Live SMTP credentials বা বাস্তব recipient delivery repository থেকে নিশ্চিত করা যায় না; ব্যবহারকারীর environment-এ configuration check এবং row feedback দিয়ে নির্দিষ্ট কারণ ধরা যাবে।
