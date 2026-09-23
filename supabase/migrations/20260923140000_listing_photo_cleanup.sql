-- Nightly cleanup of listing photos that no live listing uses: photos of
-- deleted listings and accounts, replaced photos, and uploads whose post
-- never saved. Supabase blocks SQL deletes on storage.objects, so the
-- cleanup-listing-photos Edge Function removes the files through the
-- Storage API; the database decides which files are orphaned and schedules
-- the run. The 24-hour grace period covers a listing write still in flight.
create extension if not exists pg_net with schema extensions;

-- Random per environment; only this database and the cron job know it.
select vault.create_secret(
  gen_random_uuid()::text || gen_random_uuid()::text,
  'photo_cleanup_token',
  'Authorizes the scheduled cleanup-listing-photos run'
);

-- Up to p_limit orphaned photo paths, oldest first. listings_image_urls_match_cover
-- guarantees image_urls never names anything but cover_image_url.
create function app_private.orphaned_listing_photos(p_token text, p_limit integer)
returns text[]
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_token is null or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'photo_cleanup_token' and decrypted_secret = p_token
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  return (
    select coalesce(array_agg(name), '{}') from (
      select o.name from storage.objects o
      where o.bucket_id = 'listing-images'
        and o.created_at < now() - interval '24 hours'
        and not exists (
          select 1 from public.listings l
          where l.deleted_at is null and l.cover_image_url = o.name
        )
      order by o.created_at
      limit greatest(1, least(coalesce(p_limit, 100), 1000))
    ) orphans
  );
end $$;

create function public.orphaned_listing_photos(p_token text, p_limit integer)
returns text[]
language sql stable security invoker set search_path = '' as $$
  select app_private.orphaned_listing_photos(p_token, p_limit)
$$;

revoke all on function app_private.orphaned_listing_photos(text, integer) from public, anon, authenticated;
grant execute on function app_private.orphaned_listing_photos(text, integer) to service_role;
revoke all on function public.orphaned_listing_photos(text, integer) from public, anon, authenticated;
grant execute on function public.orphaned_listing_photos(text, integer) to service_role;

-- 08:17 UTC (early morning on the US east coast). Needs the project's API
-- URL in Vault as 'project_url' (see supabase/operations); without it the
-- job is a no-op, which keeps local and CI rebuilds from calling anything.
select cron.schedule('cleanup-listing-photos', '17 8 * * *', $job$
  select net.http_post(
    url := url.decrypted_secret || '/functions/v1/cleanup-listing-photos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cleanup-token', token.decrypted_secret),
    body := '{}'::jsonb)
  from vault.decrypted_secrets url, vault.decrypted_secrets token
  where url.name = 'project_url' and token.name = 'photo_cleanup_token'
$job$);
notify pgrst, 'reload schema';
