-- Disposable CI database only; every fixture and write is rolled back.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon, service_role;
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

insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true);
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A');
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller');

-- Paths: <university>/<seller>/<32 hex>.jpg, as the app uploads them.
create temp table photo(tag text, name text);
insert into photo select tag, '10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000001/' || repeat(hex, 32) || '.jpg'
from (values ('live','a'),('deleted','b'),('replaced','c'),('fresh','d'),('sold','e')) v(tag, hex);
grant select on photo to service_role;
insert into listings(id,seller_id,university_id,campus_id,title,description,cover_image_url,image_urls,status,deleted_at)
select tag, '20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
 'Test item','A test listing photo.', name, array[name],
 case when tag='sold' then 'sold' else 'available' end,
 case when tag='deleted' then now() end
from photo where tag in ('live','deleted','sold');
insert into storage.objects(bucket_id,name,created_at)
select 'listing-images', name, case when tag='fresh' then now() - interval '1 hour' else now() - interval '2 days' end
from photo;
-- Same age and unreferenced, but in another bucket: never touched.
insert into storage.buckets(id,name,public) values('other-bucket','other-bucket',false);
insert into storage.objects(bucket_id,name,created_at) values('other-bucket','x.jpg',now() - interval '2 days');

create temp table token as
select decrypted_secret as value from vault.decrypted_secrets where name='photo_cleanup_token';
grant select on token to service_role;
select pg_temp.check('a random cleanup token was generated',
 (select length(value) from token) = 72);

set local role anon;
select pg_temp.probe('anonymous cannot list orphans',
$q$select orphaned_listing_photos((select value from token),10)$q$,'42501');
set local role authenticated;
select pg_temp.probe('students cannot list orphans',
$q$select orphaned_listing_photos((select value from token),10)$q$,'42501');

set local role service_role;
select pg_temp.probe('service key without the token is refused',
$q$select orphaned_listing_photos('wrong-token',10)$q$,'42501');
select pg_temp.probe('missing token is refused',
$q$select orphaned_listing_photos(null,10)$q$,'42501');
create temp table found as
select unnest(orphaned_listing_photos((select value from token), 100)) as name;
select pg_temp.check('deleted listing photo is an orphan',
 exists(select 1 from found join photo using(name) where tag='deleted'));
select pg_temp.check('replaced or never-posted photo is an orphan',
 exists(select 1 from found join photo using(name) where tag='replaced'));
select pg_temp.check('photos on live and sold listings are kept',
 not exists(select 1 from found join photo using(name) where tag in ('live','sold')));
select pg_temp.check('uploads under 24 hours old are kept',
 not exists(select 1 from found join photo using(name) where tag='fresh'));
select pg_temp.check('other buckets are never listed',
 not exists(select 1 from found where name='x.jpg'));
select pg_temp.check('limit is respected',
 cardinality(orphaned_listing_photos((select value from token), 1)) = 1);

reset role;
select pg_temp.check('nightly cleanup is scheduled',
 exists(select 1 from cron.job where jobname='cleanup-listing-photos' and schedule='17 8 * * *'));
select pg_temp.check('job sends nothing without a configured project URL',
 not exists(select 1 from vault.decrypted_secrets where name='project_url'));

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Photo cleanup regressions:\n%',failures; end if;
end $$;
select count(*)||' photo cleanup checks passed' as result from checks;
rollback;
