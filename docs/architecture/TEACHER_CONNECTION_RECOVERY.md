# Teacher workspace connection recovery

Calendar and preparation reads recover independently from transport failures. A failed read displays an English/Bangla unavailable panel with a refresh action; it never masquerades as an empty class list. Successful sections remain usable. Permission redirects, database errors and invalid response contracts still propagate. Authentication continues to use verified users. Refresh reads current data and never repeats a mutation automatically.

The existing 20-second per-request timeout remains. This change cannot diagnose an intermittent upstream network outage from logs alone. If failure persists, check server connectivity to the configured Supabase project and its service health.
