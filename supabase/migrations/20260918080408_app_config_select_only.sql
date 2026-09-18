-- New tables inherit default client privileges (including TRUNCATE, which
-- RLS does not govern). Clients may only read app_config.
revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;
