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
by this workflow. Helper RPCs and other authorization gaps still need review.

GitHub Actions rebuilds an isolated PostgreSQL database and runs SQL assertions
with ON_ERROR_STOP. Tests use transaction-scoped fixtures and rollback.
This verifies reconstruction and focused profile controls, not complete release
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
