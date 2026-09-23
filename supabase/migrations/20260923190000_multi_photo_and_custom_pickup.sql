-- Multiple ordered photos per listing (was: image_urls forced to exactly
-- [cover_image_url]), a real "Other" category, and a free-text pickup spot
-- alongside the fixed campus zones.
-- A CHECK constraint's expression can't contain a bare subquery, so the
-- per-element scan lives in a plain function instead (called with only the
-- row's own columns; no table access, so no re-validation gap).
create function app_private.listing_images_own_upload(
  p_image_urls text[], p_university_id uuid, p_seller_id text
) returns boolean language sql immutable set search_path = '' as $$
  select not exists (
    select 1 from unnest(p_image_urls) u(path)
    where u.path !~ ('^' || p_university_id::text || '/' || p_seller_id || '/[0-9a-f]{32}\.(jpg|png)$')
  )
$$;
revoke all on function app_private.listing_images_own_upload(text[], uuid, text) from public, anon;
grant execute on function app_private.listing_images_own_upload(text[], uuid, text) to authenticated, service_role;

alter table public.listings
  drop constraint listings_image_urls_match_cover,
  add constraint listings_image_urls_count check (cardinality(image_urls) <= 6),
  add constraint listings_image_urls_own_upload check (
    app_private.listing_images_own_upload(image_urls, university_id, seller_id)
  ),
  add constraint listings_cover_is_first_image check (
    cardinality(image_urls) = 0 or cover_image_url = image_urls[1]
  ),
  drop constraint listings_category_known,
  add constraint listings_category_known
    check (category in ('Textbooks','Electronics','Furniture','Bikes','Dorm','Apparel','Bags','Other','other'));

-- Whether a listing needs a pickup spot at all is an app concern (existing
-- test fixtures deliberately create pickup-less listings); the database
-- only shapes the free-text value when one is given.
alter table public.listings
  add column pickup_custom text,
  add constraint listings_pickup_custom_length
    check (pickup_custom is null or length(btrim(pickup_custom)) between 3 and 80);

grant update(pickup_custom) on public.listings to authenticated;
-- Re-grant insert with pickup_custom added to the column list.
revoke insert on public.listings from authenticated;
grant insert(seller_id,university_id,campus_id,pickup_zone_id,pickup_custom,title,description,price,category,condition,
 listing_kind,accepts_trades,image_urls,cover_image_url,tags,course_code,professor_name,edition,bundle_notes)
 on public.listings to authenticated;

-- A viewer may see any photo on a listing they can already see, not just
-- the cover.
drop policy listing_images_read on storage.objects;
create policy listing_images_read on storage.objects
for select to authenticated using (
  bucket_id = 'listing-images'
  and (select app_private.current_university()) is not null
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or exists (
      select 1 from public.listings l where objects.name = any(l.image_urls)
    )
  )
);

-- Cleanup must keep every photo a listing references, not only its cover.
create or replace function app_private.orphaned_listing_photos(p_token text, p_limit integer)
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
          where l.deleted_at is null and o.name = any(l.image_urls)
        )
      order by o.created_at
      limit greatest(1, least(coalesce(p_limit, 100), 1000))
    ) orphans
  );
end $$;
notify pgrst, 'reload schema';
