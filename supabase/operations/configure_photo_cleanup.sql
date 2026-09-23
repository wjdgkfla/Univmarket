-- Hosted project only (run once; applied 2026-09-23). Points the nightly
-- cleanup-listing-photos cron job at this project's API. The URL is public;
-- it lives in Vault so migrations stay project-agnostic and local/CI
-- rebuilds never call production.
select vault.create_secret(
  'https://amzvnsphtaxkjzmsjsie.supabase.co',
  'project_url',
  'API URL used by scheduled Edge Function calls'
)
where not exists (select 1 from vault.secrets where name = 'project_url');
