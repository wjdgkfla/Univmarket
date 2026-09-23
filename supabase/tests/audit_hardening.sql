-- Disposable CI database only; every fixture and write is rolled back.
-- Covers listing field limits, listing photo storage, finishing a
-- reservation, and offer expiry.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon;
create function pg_temp.probe(label text, statement text, expected text default 'allowed')
returns void language plpgsql as $$
declare result text;
begin
 begin execute statement;
 raise exception using errcode='ZX001', message='rollback successful probe';
 exception when others then result:=sqlstate; end;
 insert into checks values(label,case when expected='allowed' then result='ZX001' else result=expected end,result);
end $$;
create function pg_temp.check(label text, passed boolean) returns void
language sql as $$ insert into checks values(label, passed, passed::text) $$;

-- Fixtures: university A (seller 1, buyer 2) and university B (student 3).
insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true),
('10000000-0000-0000-0000-000000000002','test-b','Test B','B',true);
insert into university_domains values
('a.test','10000000-0000-0000-0000-000000000001'),('b.test','10000000-0000-0000-0000-000000000002');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A'),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','main','Main B');
insert into pickup_zones(id,campus_id,slug,name) values
('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','library','Library A');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','seller@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','buyer@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','other@b.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Other');
insert into listings(id,seller_id,university_id,campus_id,pickup_zone_id,title,description,category,cover_image_url,image_urls) values
('sell','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Desk lamp','A working desk lamp.','Dorm',
 '10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/0123456789abcdef0123456789abcdef.jpg',
 array['10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/0123456789abcdef0123456789abcdef.jpg']),
('cancel','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Bike lock','A sturdy bike lock.','Bikes',null,'{}');
insert into storage.objects(bucket_id,name) values
('listing-images','10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/0123456789abcdef0123456789abcdef.jpg'),
('listing-images','10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/ffffffffffffffffffffffffffffffff.jpg');

-- Listing field limits (seller 1, otherwise valid rows).
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('valid listing insert still allowed',
$q$insert into listings(seller_id,university_id,campus_id,pickup_zone_id,title,description,category)
 values(auth.uid()::text,'10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Chair','A comfortable chair.','Furniture')$q$);
select pg_temp.probe('too-short title rejected',
$q$insert into listings(seller_id,university_id,campus_id,title,description,category)
 values(auth.uid()::text,'10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','x','A comfortable chair.','Furniture')$q$,'23514');
select pg_temp.probe('oversized description rejected',
$q$update listings set description=repeat('a',2001) where id='cancel'$q$,'23514');
select pg_temp.probe('negative price rejected',
$q$update listings set price=-1 where id='cancel'$q$,'23514');
select pg_temp.probe('unknown category rejected',
$q$update listings set category='Weapons' where id='cancel'$q$,'23514');
select pg_temp.probe('external photo url rejected',
$q$update listings set cover_image_url='https://evil.example/p.png' where id='cancel'$q$,'23514');
select pg_temp.probe('another student''s upload path rejected',
$q$update listings set cover_image_url='10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000002/0123456789abcdef0123456789abcdef.jpg' where id='cancel'$q$,'23514');
select pg_temp.probe('own upload path accepted',
$q$update listings set cover_image_url='10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/ffffffffffffffffffffffffffffffff.png',
 image_urls=array['10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/ffffffffffffffffffffffffffffffff.png'] where id='cancel'$q$);

-- Storage: uploads land only in your own folder at your own university.
select pg_temp.probe('upload into own folder allowed',
$q$insert into storage.objects(bucket_id,name) values('listing-images','10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg')$q$);
select pg_temp.probe('upload into another student''s folder denied',
$q$insert into storage.objects(bucket_id,name) values('listing-images','10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000002/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg')$q$,'42501');
select pg_temp.probe('upload under another university denied',
$q$insert into storage.objects(bucket_id,name) values('listing-images','10000000-0000-0000-0000-000000000002/20000000-0000-0000-0000-000000000001/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg')$q$,'42501');
select pg_temp.probe('nested upload path denied',
$q$insert into storage.objects(bucket_id,name) values('listing-images','10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/x/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg')$q$,'42501');
select pg_temp.check('owner reads own unattached upload',
 (select count(*) from storage.objects where name like '%/ffffffffffffffffffffffffffffffff.jpg')=1);

-- Storage reads: listing photos for classmates only.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.check('classmate reads a visible listing photo',
 (select count(*) from storage.objects where name like '%/0123456789abcdef0123456789abcdef.jpg')=1);
select pg_temp.check('classmate cannot read an unattached upload',
 (select count(*) from storage.objects where name like '%/ffffffffffffffffffffffffffffffff.jpg')=0);
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000003';
select pg_temp.check('other university cannot read listing photos',
 (select count(*) from storage.objects where bucket_id='listing-images')=0);
set local role anon;
select pg_temp.check('anonymous cannot read listing photos',
 (select count(*) from storage.objects where bucket_id='listing-images')=0);

-- Reserve both listings: buyer offers, seller accepts.
reset role;
create temp table flow(listing_id text, conversation_id text, offer_id text);
grant all on flow to authenticated;
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
insert into flow(listing_id,conversation_id) select id, start_conversation(id) from (values('sell'),('cancel')) v(id);
update flow set offer_id=send_offer(conversation_id,'cash',10,'{}');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select respond_to_offer(offer_id,'accept') from flow;
select pg_temp.check('accepted offers reserve both listings',
 (select count(*) from listings where id in ('sell','cancel') and status='reserved')=2);
select pg_temp.probe('reserved listing still not directly editable',
$q$do $b$ begin update listings set status='sold' where id='sell'; if found then raise exception 'edited'; end if; end $b$;$q$);

-- Finishing a reservation.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('buyer cannot finish the seller''s reservation',
$q$select finish_reservation('sell','sold')$q$,'42501');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('unknown outcome rejected',$q$select finish_reservation('sell','given away')$q$,'22023');
select pg_temp.probe('available listing has no reservation to finish',
$q$select finish_reservation('nope','sold')$q$,'42501');
select finish_reservation('sell','sold');
select finish_reservation('cancel','cancelled');
select pg_temp.check('seller marks a reserved listing sold',
 (select status from listings where id='sell')='sold');
select pg_temp.check('seller cancels a reservation and relists',
 (select status from listings where id='cancel')='available');
select pg_temp.check('finished transactions are closed',
 not exists(select 1 from transaction_listings where listing_id in ('sell','cancel') and is_active));
select pg_temp.check('buyer is told in the conversation',
 (select count(*) from messages m join flow f on f.conversation_id=m.conversation_id
  where m.type='system' and m.body in ('Marked as sold','Reservation cancelled'))=2);
select pg_temp.probe('a finished reservation cannot be finished twice',
$q$select finish_reservation('sell','cancelled')$q$,'42501');
select pg_temp.probe('relisted item is editable again',
$q$do $b$ begin update listings set title='Bike lock again' where id='cancel'; if not found then raise exception 'not editable'; end if; end $b$;$q$);

-- Offer expiry.
select pg_temp.probe('clients cannot run offer expiry',$q$select app_private.expire_offers()$q$,'42501');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
update flow set offer_id=send_offer(conversation_id,'cash',5,'{}') where listing_id='cancel';
reset role;
update offers set expires_at=now()-interval '1 minute' where id=(select offer_id from flow where listing_id='cancel');
-- Separate statements: a query's snapshot predates updates made by a
-- function it calls, so the status must be read afterwards.
select pg_temp.check('expiry job expires exactly the stale offer', app_private.expire_offers()=1);
select pg_temp.check('stale pending offer is now expired',
 (select status from offers where id=(select offer_id from flow where listing_id='cancel'))='expired');
select pg_temp.check('expiry job is scheduled',
 exists(select 1 from cron.job where jobname='expire-offers'));

-- Performance rewrite kept every public policy free of per-row auth.uid().
select pg_temp.check('no public policy evaluates auth.uid() per row',
 not exists(select 1 from pg_policies where schemaname='public'
  and (qual ~ '(?<!SELECT )auth\.uid\(\)' or with_check ~ '(?<!SELECT )auth\.uid\(\)')));

-- Multiple photos, a real "Other" category, and a free-text pickup spot.
-- 'sell' is 'sold' by this point in the script (see above), so the owner
-- update policy would make any UPDATE on it a silent 0-row no-op; 'cancel'
-- is back to 'available' and stays editable for the rest of the file.
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
-- Not a probe: this must actually persist for the later read-access check.
update listings set
  image_urls=array['10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/0123456789abcdef0123456789abcdef.jpg',
    '10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/ffffffffffffffffffffffffffffffff.jpg'],
  cover_image_url='10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/0123456789abcdef0123456789abcdef.jpg'
 where id='cancel';
select pg_temp.check('a second own photo on the same listing is accepted',
 (select cardinality(image_urls) from listings where id='cancel')=2);
select pg_temp.probe('more than 6 photos rejected',
$q$update listings set image_urls=(select array_agg('10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/'||
  lpad(to_hex(n),32,'0')||'.jpg') from generate_series(1,7) n) where id='cancel'$q$,'23514');
select pg_temp.probe('a second photo from someone else''s folder is rejected',
$q$update listings set image_urls=image_urls || array['10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000002/0123456789abcdef0123456789abcdef.jpg'] where id='cancel'$q$,'23514');
select pg_temp.probe('cover must be the first photo',
$q$update listings set cover_image_url='10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/ffffffffffffffffffffffffffffffff.jpg' where id='cancel'$q$,'23514');
select pg_temp.probe('"Other" is a real, selectable category',
$q$update listings set category='Other' where id='cancel'$q$);
select pg_temp.probe('an unrecognized category is still rejected',
$q$update listings set category='Weapons' where id='cancel'$q$,'23514');
select pg_temp.probe('a custom pickup spot can stand in for a fixed zone',
$q$update listings set pickup_zone_id=null, pickup_custom='Room 204, North dorm' where id='cancel'$q$);
select pg_temp.probe('a too-short custom pickup spot is rejected',
$q$update listings set pickup_zone_id=null, pickup_custom='NW' where id='cancel'$q$,'23514');

-- A classmate can read every photo on a listing, not only its cover.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.check('classmate reads the listing''s second photo too',
 (select count(*) from storage.objects where name like '%/ffffffffffffffffffffffffffffffff.jpg')=1);
reset role;

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Audit hardening regressions:\n%',failures; end if;
end $$;
select count(*)||' audit hardening checks passed' as result from checks;
rollback;
