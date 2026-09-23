-- Launch cleanup: remove the preview listings and their "Sample Seller"
-- profiles (seeded by operations/replace_legacy_test_data.sql). Samples
-- have no sign-in, and nothing references them on the hosted project; if
-- anything ever did, the foreign keys make this fail instead of cascading.
delete from public.favorites
  where listing_id in (select id from public.listings where seller_id like 'sample-seller-%');
delete from public.listings where seller_id like 'sample-seller-%';
delete from public.profiles p
  where p.id like 'sample-seller-%'
    and not exists (select 1 from auth.users u where u.id::text = p.id);
