-- Single-row minimum app build. Apps below min_build show "Update required".
-- Readable before sign-in so outdated installs are stopped at the door.
create table public.app_config (
  id boolean primary key default true check (id),
  min_build integer not null default 1 check (min_build >= 1),
  update_url text check (update_url is null or update_url ~ '^https://')
);
insert into public.app_config default values;
alter table public.app_config enable row level security;
create policy app_config_read on public.app_config for select using (true);
grant select on public.app_config to anon, authenticated;
notify pgrst, 'reload schema';
