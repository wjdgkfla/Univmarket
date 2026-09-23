-- Provision the private photo bucket described in STORAGE_SETUP.md.
-- Paths: <university-id>/<user-id>/<random>.<jpg|png>; no overwrites.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-images', 'listing-images', false, 1500000, array['image/jpeg','image/png'])
on conflict (id) do nothing;

-- Upload only into your own folder, under your verified university.
create policy listing_images_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'listing-images'
  and array_length(storage.foldername(name), 1) = 2
  and (storage.foldername(name))[1] = (select app_private.current_university())::text
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

-- Read (and so sign) a photo you uploaded, or one attached to a listing you
-- are allowed to see. The listings subquery runs under listings RLS, which
-- limits it to visible listings at your university plus your own.
create policy listing_images_read on storage.objects
for select to authenticated using (
  bucket_id = 'listing-images'
  and (select app_private.current_university()) is not null
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or exists (select 1 from public.listings l where l.cover_image_url = objects.name)
  )
);

-- No update or delete policies: uploads are immutable from the client.

create index if not exists listings_cover_image_idx
  on public.listings (cover_image_url) where cover_image_url is not null;
