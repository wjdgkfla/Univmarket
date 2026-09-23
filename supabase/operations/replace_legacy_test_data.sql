-- RETIRED 2026-09-23: the preview listings this script seeded were removed
-- for launch by migrations/*_remove_sample_listings.sql. Do not re-run it.
-- Owner-authorized one-time data cleanup and preview seed, not a migration.
-- No sample seller has an auth.users row or a login credential.
begin;
do $$
declare
  legacy text[] := array['3fa26031-7cbb-4a30-9dee-005a332a115f','fa4230bd-e067-4406-b6a1-130f68dabecb',
    '56100738-9ee4-4af5-bd97-99df7b4f9495','2c645df2-30b5-429a-a02f-e8414c3a7aab',
    '2a95c489-fa1f-48d6-993d-79ad59787036','c021f4dc-8226-4e7b-9cfc-4cbce6f51d54',
    'cc060f7b-a091-4f6f-8b8e-5c7dc8300727','e1d08cec-f072-45b7-94d4-e4ffe66afad1'];
  old_listings text[];
  old_threads text[];
  school record;
  item record;
  campus uuid;
  spot uuid;
  seller text;
begin
  if exists(select 1 from public.profiles p join public.universities u on u.id=p.university_id
    where p.id=any(legacy) and u.slug <> 'fenwick') then
    raise exception 'An expected test identity has changed university; refusing cleanup';
  end if;
  if exists(select 1 from auth.users where id::text=any(legacy) and not coalesce(is_anonymous,false)
    and email not in ('maya@fenwick.edu','devon@fenwick.edu')) then
    raise exception 'Unexpected account identity; refusing cleanup';
  end if;
  if exists(select 1 from public.transactions where buyer_id=any(legacy) or seller_id=any(legacy)) then
    raise exception 'Test accounts now have transactions; refusing cleanup';
  end if;
  select coalesce(array_agg(id),'{}') into old_listings from public.listings where seller_id=any(legacy);
  select coalesce(array_agg(id),'{}') into old_threads from public.conversations where buyer_id=any(legacy) or seller_id=any(legacy);
  delete from auth.sessions where user_id::text=any(legacy);
  delete from auth.refresh_tokens where user_id=any(legacy);
  delete from auth.flow_state where user_id::text=any(legacy);
  delete from public.notifications where user_id=any(legacy);
  delete from public.notification_preferences where user_id=any(legacy);
  delete from public.device_push_tokens where user_id=any(legacy);
  delete from public.saved_searches where user_id=any(legacy);
  delete from public.price_watches where user_id=any(legacy) or listing_id=any(old_listings);
  delete from public.favorites where user_id=any(legacy) or listing_id=any(old_listings);
  delete from public.reports where reporter_id=any(legacy) or reported_user_id=any(legacy) or listing_id=any(old_listings);
  delete from public.ratings where reviewer_id=any(legacy) or reviewee_id=any(legacy);
  delete from public.blocks where blocker_id=any(legacy) or blocked_id=any(legacy);
  delete from public.admin_activity where actor_user_id=any(legacy);
  delete from public.analytics_events where user_id::text=any(legacy);
  delete from public.outbox_events e where exists(select 1 from unnest(legacy || old_listings || old_threads) target(id)
    where position(target.id in e.payload::text)>0);
  delete from public.messages where conversation_id=any(old_threads) or from_user_id=any(legacy) or to_user_id=any(legacy);
  delete from public.offer_items where offered_listing_id=any(old_listings);
  delete from public.offers where conversation_id=any(old_threads) or from_user_id=any(legacy) or to_user_id=any(legacy);
  delete from public.conversations where id=any(old_threads);
  delete from public.listings where id=any(old_listings);
  delete from public.profiles where id=any(legacy);
  delete from auth.users where id::text=any(legacy);

  for school in select id,slug,short_name from public.universities
    where active and slug in ('george-mason','george-washington') loop
    select id into strict campus from public.campuses where university_id=school.id and active and slug='main';
    seller := 'sample-seller-' || school.slug;
    insert into public.profiles(id,university_id,home_campus_id,display_name,bio)
      values(seller,school.id,campus,school.short_name || ' Sample Seller',
      'Sample seller for preview listings. This profile has no sign-in account and does not conduct transactions.')
      on conflict(id) do nothing;
    for item in select * from (values
      (1,'Calculus textbook',25,'Textbooks','good','A sample calculus textbook listing with room for condition and edition details.'),
      (2,'Wireless headphones',60,'Electronics','like_new','A sample pair of wireless headphones with a carrying case.'),
      (3,'Adjustable desk lamp',15,'Dorm','good','A sample study lamp with adjustable brightness for a desk or dorm room.'),
      (4,'Everyday backpack',30,'Bags','like_new','A sample backpack with a padded laptop compartment and space for books.')
    ) x(seq,title,price,category,condition,description) loop
      select id into strict spot from public.pickup_zones where campus_id=campus and active
        and slug=case when school.slug='george-washington' then 'gelman-library'
          when item.seq%2=0 then 'johnson-center' else 'fenwick-library' end;
      insert into public.listings(id,seller_id,university_id,campus_id,pickup_zone_id,title,description,price,category,condition,tags)
        values('sample-' || school.slug || '-' || item.seq,seller,school.id,campus,spot,item.title,
          item.description || ' Sample listing for app testing; not available for purchase.',
          item.price,item.category,item.condition,array['sample']) on conflict(id) do nothing;
    end loop;
  end loop;
end $$;
select jsonb_build_object(
 'auth_users',(select count(*) from auth.users),
 'legacy_profiles',(select count(*) from public.profiles p join public.universities u on u.id=p.university_id where u.slug='fenwick'),
 'sample_profiles',(select count(*) from public.profiles where id like 'sample-seller-%'),
 'sample_listings',(select count(*) from public.listings where seller_id like 'sample-seller-%'),
 'messages',(select count(*) from public.messages),
 'conversations',(select count(*) from public.conversations)
) as result;
commit;
