# UnivMarket database history

The August 2026 migrations were recovered from the hosted project's
supabase_migrations.schema_migrations statement history. Their version numbers
match the existing ledger; do not rerun them manually against production.

The historical 08_seed_demo_data version intentionally contains only a comment.
Its original SQL created demo accounts with a shared password and sample records.
Rebuilds omit those records. Existing production data is unaffected.
No live user records or password hashes were exported.

The September profile privilege migration remains pending on production.
The subsequent explicit_client_grants migration restores required Data API
access when config.toml disables automatic grants. Neither migration is deployed
by this workflow.

The verified-marketplace migration is also pending on production. It requires
a confirmed, non-anonymous, non-banned Auth user whose exact email domain maps
to an active university. Existing profiles must match that university and an
active campus; they are not silently reassigned. User-editable metadata is never
used to grant access. Inactive accounts and mismatched memberships are denied.
New profiles use the configured main campus, or the sole active campus.

The launch configuration adds George Mason University (gmu.edu, Fairfax) and
George Washington University (gwu.edu, Foggy Bottom). Subdomains and lookalike
domains are not implicitly approved. No user accounts, passwords, or sample
listings are included. Pickup migrations configure Fenwick Library and Johnson
Center on GMU's Fairfax campus, and Gelman Library on GWU's Foggy Bottom campus.
The legacy Fenwick seed university is deactivated (not deleted); only GMU and GWU are active.

Fenwick Library is a real location within GMU, not a separate university:
https://library.gmu.edu/locations/fenwick
Its pickup entry is attached to George Mason's campus and does not convert
legacy Fenwick profiles or the fenwick.edu domain into verified GMU memberships.
No university endorsement, fixed meeting room, or opening hours are assumed.

Additional location references:
- Johnson Center: https://studentcenters.gmu.edu/the-johnson-center/
- Gelman Library: https://calendar.gwu.edu/gelman_library

Chat and offer RPCs check participants, current membership, university boundaries,
blocking and listing visibility. Acceptance rechecks expiry and availability,
locks target/trade listings and preserves the conversation's buyer/seller roles.
Clients cannot directly change listing ownership, university, moderation or
counters. Public RPC signatures are preserved, with checked privileged operations
in the unexposed app_private schema. Do not add app_private to exposed API schemas.

GitHub Actions rebuilds an isolated PostgreSQL database and runs SQL assertions
with ON_ERROR_STOP. Tests use transaction-scoped fixtures and rollback.
The workflow also lints database functions and runs security advisors.
This verifies reconstruction and focused authorization controls, not complete release
security or the absence of unrecorded live schema changes.

Local verification requires Docker or Podman:
  npx --yes supabase@2.117.0 db start
  npx --yes supabase@2.117.0 db reset --local
Then run each tests/*.sql file with psql against localhost:54322.

Production: amzvnsphtaxkjzmsjsie.
GitHub integration: wjdgkfla/Univmarket, directory ".".
Automatic production deployment and preview branching stay disabled.
Do not change the hosted migration ledger to force a push to succeed.
Review pending migrations and CI results before deployment.

Before live rollout:
- Review existing memberships: the preflight found 8 profiles, only 2 of which
  matched a confirmed approved-domain email. This is a point-in-time count,
  not an instruction to modify or delete accounts.
- Preserve legacy accounts and data; resolve verified enrollment separately before
  rollout. The user has not authorized retiring the legacy Fenwick entry.
- The initial pickup choices are Fenwick Library and Johnson Center for GMU,
  and Gelman Library for GWU. Further locations can be added later.
- Review hosted schema drift, Storage policies, SMTP/email-confirmation settings,
  leaked-password protection and outstanding advisor findings separately.
- Take a recoverable backup and apply only reviewed pending migrations in order.
  Never replay historical migrations or run a reset against the hosted project.
- Deploy the `send-push` Edge Function *before* applying
  `..._push_notifications.sql`. That migration adds a trigger that calls
  `send-push` on every new message; if the function isn't live yet, every
  message send queues a call that just fails (harmless — messaging itself
  still works — but noisy in the function logs until it's deployed).
  `send-push` also needs the `FIREBASE_SERVICE_ACCOUNT` Edge Function secret
  set before it can actually deliver anything.
